# Architecture & Design

## Overview

This document covers the key architecture decisions, trade-offs, and scaling strategy for the self-hosted LLM inference platform.

---

## Architecture Decisions

### Why Asynchronous Inference?

Synchronous inference (request → wait → response) is impractical for GPU-based LLMs because:

- Inference latency ranges from 2–30 seconds depending on prompt length and model size
- A single GPU VM can only process one request at a time
- Synchronous connections held open at that scale are expensive and fragile

**Decision:** Clients submit jobs to a queue and poll or receive a callback. This decouples client load from GPU availability and allows the system to absorb bursts without dropping requests.

**Trade-off:** Adds complexity (async client pattern, polling/callback logic) but enables far better resource utilisation and cost control.

---

### Why Azure Service Bus over Event Hub or Storage Queue?

| Option | Why rejected / chosen |
|---|---|
| **Storage Queue** | No dead-letter queue, no message lock, limited visibility timeout |
| **Event Hub** | Designed for streaming/telemetry, not job dispatch. No per-message acknowledgement |
| **Service Bus** | Per-message locking, built-in DLQ, configurable retry count, TTL — fits a job queue pattern |

**Decision:** Service Bus with `max_delivery_count = 5`, `lock_duration = PT5M`, and dead-lettering on expiry. Failed jobs are preserved in the DLQ for inspection rather than silently dropped.

---

### Why a Single GPU VM over AKS or Containers?

| Option | Trade-off |
|---|---|
| **AKS + GPU node pool** | Better for multi-tenant or multi-model setups. Significant operational overhead for a single model. |
| **Container Instances** | No persistent GPU driver state. Cold start with model reload on every invocation. |
| **Single VM (chosen)** | Simple to operate, model loaded once into GPU memory at startup, low latency after warm-up. Suitable for a single-model inference workload. |

**Trade-off:** A single VM is not horizontally scalable without a VM Scale Set. Accepted for this design scope — Scale Sets are listed as a production improvement.

---

### Why `Standard_NC4as_T4_v3` over Older GPU SKUs?

`Standard_NC6` (K80 GPU) was considered and rejected:

- K80 has no FP16/BF16 support — modern LLMs run significantly slower in FP32-only mode
- K80 is an older generation with lower memory bandwidth
- T4 offers better performance per dollar for inference workloads

**Decision:** `Standard_NC4as_T4_v3` with NVIDIA T4 GPU, `Premium_LRS` OS disk (SSD, 128 GB) to avoid I/O bottlenecks during model loading.

---

### Why Private Subnet with No Public IP?

The LLM VM processes potentially sensitive inference requests. Exposing it directly to the internet would:

- Increase attack surface significantly
- Require application-level auth to protect the inference endpoint

**Decision:** VM placed in a private subnet, NSG denies all inbound internet traffic. All access is via the internal queue worker pattern — no direct HTTP exposure.

---

## Scaling Strategy

### Scaling Signal

Queue depth (number of pending messages in Service Bus) is the primary scaling signal — it directly reflects unprocessed inference backlog.

| Queue Depth | Action |
|---|---|
| < 50 messages | 1 VM (baseline, always-on) |
| 50–200 messages | Scale to 2 VMs |
| > 200 messages | Scale to 4 VMs |

### Cold Start Problem

GPU VMs have high startup time (2–5 minutes) plus model loading time (1–3 minutes depending on model size). Scaling from zero would create unacceptable latency spikes.

**Mitigation:**
- Always maintain 1 warm VM — model preloaded in GPU memory
- Never scale down to zero
- New VMs download model from Blob Storage at startup and begin processing only after the model is loaded

**Trade-off:** 1 always-on GPU VM incurs cost even during idle periods. This is a deliberate choice to prioritise availability over cost minimisation.

### Bursty Workloads

The Service Bus queue acts as a buffer — sudden spikes (e.g. 500 jobs arriving at once) are absorbed by the queue and processed at a controlled rate. This prevents the VM from being overloaded and avoids over-provisioning for peak traffic that may last only minutes.

---

## Model Versioning & Deployment

Model artifacts are stored in Blob Storage with versioned paths:

```
models/v1/model.bin
models/v2/model.bin
```

**Deployment strategy:**
1. Upload new model version to `models/v2/`
2. Launch new VM instances pointing to the new version
3. Gradually shift traffic to new instances (queue routing or DNS)
4. Drain old instances after in-flight requests complete
5. Terminate old VMs

This ensures zero downtime during model updates and allows fast rollback by redirecting to the previous version path.
