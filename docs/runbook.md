# Runbook & Observability

## Observability Overview

Monitoring covers the full inference pipeline — from queue ingestion through GPU processing to response delivery.

**Key components monitored:**
- Azure Service Bus (queue depth, DLQ count, message age)
- GPU VM (CPU, GPU utilisation, GPU memory, disk I/O)
- Application (inference latency, throughput, error rate)
- Platform (VM availability, OS-level alerts)

Logs and metrics are collected via **Azure Monitor** and stored in **Log Analytics**.

---

## Key Metrics & Alerts

### 1. High Queue Depth

- **Metric:** `ActiveMessages` on the `inference-jobs` queue
- **Threshold:** > 100 messages
- **Impact:** Growing backlog — GPU worker cannot keep up with incoming jobs
- **Action:** Scale up additional GPU worker VMs

---

### 2. High DLQ Count

- **Metric:** `DeadLetteredMessageCount` on the `inference-jobs` queue
- **Threshold:** > 5 messages
- **Impact:** Jobs are failing repeatedly and being dead-lettered
- **Action:** Inspect DLQ messages for error patterns, check application logs, fix root cause before reprocessing

---

### 3. High Inference Failure Rate

- **Metric:** Application-level error counter (e.g. inference exceptions per minute)
- **Threshold:** > 5% of requests failing
- **Impact:** Model or service issue affecting job completion
- **Action:** Check application logs, inspect DLQ, restart LLM service if unresponsive

---

### 4. High Inference Latency

- **Metric:** Average job processing time (queue message lock duration as proxy, or application metric)
- **Threshold:** > 2× baseline average
- **Impact:** GPU overload, model issue, or resource bottleneck
- **Action:** Check GPU utilisation and memory, scale up workers

---

### 5. GPU Memory Pressure (OOM Risk)

- **Metric:** GPU memory utilisation (via Azure Monitor VM extension or DCGM exporter)
- **Threshold:** > 90% GPU memory used
- **Impact:** Risk of CUDA out-of-memory error causing inference worker crash
- **Action:** Investigate prompt length distribution, consider quantised model variant (INT8/INT4)

---

### 6. VM Availability

- **Metric:** `VmAvailabilityMetric`
- **Threshold:** VM unreachable > 1 minute
- **Impact:** No inference capacity
- **Action:** Check boot diagnostics, attempt VM restart, redeploy if necessary

---

## Failure Scenario: Sudden Spike in Requests (Latency Tripled)

### Symptoms
- Queue depth rising rapidly
- Average response time 3× above baseline
- Some requests failing and appearing in DLQ

### Step-by-Step Diagnosis

1. **Check queue depth** — Azure Service Bus → `inference-jobs` → Active Messages
2. **Check GPU utilisation** — Azure Monitor → VM → GPU metrics (utilisation %, memory %)
3. **Check GPU memory** — Look for values > 90%; approaching limit risks OOM crash
4. **Check application logs** — Log Analytics → filter by VM hostname, look for CUDA errors or timeout exceptions
5. **Check DLQ** — Count and sample failed messages for error content
6. **Check VM health** — CPU, memory, disk I/O to rule out non-GPU bottlenecks

### Immediate Actions

- Scale up 1–2 additional GPU worker VMs to reduce queue backlog
- If GPU memory is at limit: restart the inference service to clear memory leaks
- If DLQ is growing: pause reprocessing until root cause is identified — do not reprocess blindly

### Root Cause Analysis

| Symptom | Likely cause |
|---|---|
| High queue, low GPU utilisation | Worker crashed or stopped consuming |
| High queue, high GPU utilisation | Genuine traffic spike — scale up |
| High GPU memory, errors in logs | OOM — long prompts or memory leak |
| DLQ growing, consistent error message | Application bug or malformed job payload |
| VM unavailable | Spot eviction (if using spot), hardware fault |

---

## Rollback Strategy

If degradation is caused by a new model deployment:

1. Identify the previous stable model version path (e.g. `models/v1/`)
2. Update VM startup configuration to point to the previous version
3. Restart worker VMs with the stable model version
4. Monitor queue processing rate and latency until stable
5. Do not reprocess DLQ messages until the root cause is confirmed

---

## GPU-Specific Failure Modes

These failure modes are specific to GPU inference workloads and should be checked before generic infrastructure issues:

| Failure | Symptom | Resolution |
|---|---|---|
| CUDA OOM | Worker crashes, CUDA error in logs | Reduce batch size, use quantised model, scale horizontally |
| GPU driver not loaded | VM boots but inference fails immediately | Check `nvidia-smi` output in boot diagnostics, reinstall driver |
| Model load failure | Worker starts but never processes messages | Check Blob Storage connectivity, verify model file integrity |
| Thermal throttling | Latency high but utilisation looks normal | Check Azure host metrics, VM may need redeployment to different host |

---

## Summary

This runbook ensures:
- Fast detection via specific metric thresholds on queue depth, GPU memory, and failure rate
- Clear escalation path from symptom → diagnosis → action
- GPU-aware failure modes that go beyond generic VM monitoring
- Safe rollback without reprocessing failed jobs blindly
