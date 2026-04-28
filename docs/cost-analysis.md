# Cost Analysis

## Summary

The dominant cost is GPU compute. All other services (Service Bus, Blob Storage, Monitor) are negligible by comparison. Cost strategy focuses on right-sizing the GPU VM, avoiding idle compute, and using spot pricing for non-critical workloads.

> Prices below are approximate UAE North region estimates. Validate using the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before production deployment.

---

## Cost Breakdown

### 1. GPU Compute — Primary Cost Driver

**VM:** `Standard_NC4as_T4_v3` (NVIDIA T4, 4 vCPUs, 28 GB RAM)

| Pricing model | Estimated cost |
|---|---|
| On-demand (pay-as-you-go) | ~$0.90 / hour |
| Spot instance | ~$0.27 / hour (~70% saving) |
| 1-year reserved | ~$0.55 / hour |

**Baseline (1 always-on VM, on-demand):** ~$648 / month

**Cost control approach:**
- Maintain 1 on-demand VM for the baseline (warm, low latency)
- Scale additional workers using **spot VMs** for burst traffic — acceptable because failed spot jobs are retried via the DLQ
- Use **reserved instances** if baseline traffic is predictable
- Scale down extra VMs during off-peak hours

**Why not Standard_NC6 (K80)?**
The K80 does not support FP16/BF16, resulting in significantly slower inference. The T4 delivers better throughput at a lower cost per inference token — making `Standard_NC4as_T4_v3` the more cost-efficient choice for modern LLMs.

---

### 2. Azure Service Bus — Low Cost

| SKU | Cost |
|---|---|
| Standard | ~$0.10 per million operations |
| Premium (production) | ~$670 / month per messaging unit |

**Current design uses Standard** (~negligible cost). Premium would be required for private networking in production — this is a noted production gap and represents a significant cost increase.

---

### 3. Azure Blob Storage — Low Cost

| Item | Estimate |
|---|---|
| Hot tier (active model, e.g. 7B model ~14 GB) | ~$0.30 / month |
| Cool tier (archived model versions) | ~$0.10 / month |
| Egress to VM (same region) | Free |

- Models are downloaded **once at VM startup** and loaded into GPU memory — not per request
- Older model versions moved to Cool tier automatically to reduce cost

---

### 4. Azure Monitor & Log Analytics — Controlled Cost

| Item | Estimate |
|---|---|
| Log ingestion | ~$2.76 / GB |
| Retention (default 31 days) | Included |
| Retention beyond 31 days | ~$0.12 / GB / month |

**Recommendation:** Set retention to 30–60 days. Do not log full prompt/response payloads — log only metadata (job ID, duration, status) to control ingestion volume.

---

## Cost vs Performance Trade-offs

| Decision | Cost impact | Performance impact | Choice |
|---|---|---|---|
| Always-on warm VM | +~$648/month baseline | Low latency, no cold start | Accepted |
| Spot VMs for burst | -70% on extra workers | Risk of eviction (mitigated by DLQ retry) | Accepted |
| Standard_NC4as_T4_v3 vs NC6 | Similar price | T4 significantly faster for FP16 inference | T4 chosen |
| Service Bus Standard vs Premium | Standard much cheaper | Premium adds private networking | Standard for now, Premium in prod |
| SSD OS disk (Premium_LRS) | Small increase | Faster model load from disk to GPU | Accepted |

---

## Tagging for Cost Allocation

All resources are tagged to enable cost attribution in Azure Cost Management:

**Current tags (implemented):**
```
Project     = llm-devops
Environment = dev
Owner       = devops
ManagedBy   = Terraform
Workload    = SelfHostedLLM
```

**Additional production tags:**
```
CostCenter    = <team or department>
CustomerId    = <customer identifier>
WorkflowType  = <e.g. document-summary, qa, translation>
ModelName     = <e.g. mistral-7b, llama-3-8b>
```

Granular tagging allows cost breakdowns per customer, workflow type, or model — critical for a multi-tenant or chargeback model.

---

## Monthly Cost Estimate (Dev Environment)

| Component | Estimated cost |
|---|---|
| 1x GPU VM on-demand (730 hrs) | ~$648 |
| Blob Storage (model artifacts) | ~$1 |
| Service Bus Standard | < $1 |
| Azure Monitor / Log Analytics | ~$5–10 |
| **Total** | **~$655–660 / month** |

Spot pricing for the baseline VM would reduce this to ~$200–210/month with eviction risk factored in.
