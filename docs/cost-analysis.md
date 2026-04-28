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

## Build vs. Buy Analysis

### The Question

At what monthly inference volume does self-hosting (~$655/month fixed) become cheaper than paying per-token to a third-party API?

### Assumptions

- **Model:** Mistral-7B-Instruct (self-hosted) vs GPT-4o-mini (third-party, comparable quality for SMB automation tasks)
- **Job profile:** 500 input tokens + 200 output tokens per inference job (typical for document summarisation or workflow classification)
- **Third-party pricing (GPT-4o-mini):** $0.15 / 1M input tokens, $0.60 / 1M output tokens

### Cost Per Job

**Third-party API:**
```
Input:  500 tokens × ($0.15 / 1,000,000) = $0.000075
Output: 200 tokens × ($0.60 / 1,000,000) = $0.000120
Total per job:                             = $0.000195
```

**Self-hosted (Mistral-7B on T4):**
```
Fixed monthly cost: ~$655
Variable cost per job: ~$0 (GPU already running)
Cost per job at N jobs/month: $655 / N
```

### Breakeven Calculation

| Monthly jobs | Third-party cost | Self-hosted cost | Cheaper option |
|---|---|---|---|
| 100,000 | ~$20 | ~$655 | Third-party |
| 500,000 | ~$98 | ~$655 | Third-party |
| 1,000,000 | ~$195 | ~$655 | Third-party |
| 2,000,000 | ~$390 | ~$655 | Third-party |
| 3,360,000 | ~$655 | ~$655 | **Breakeven** |
| 5,000,000 | ~$975 | ~$655 | **Self-hosted** |
| 10,000,000 | ~$1,950 | ~$655 | **Self-hosted** |

**Breakeven point: ~3.36M jobs/month (~112,000 jobs/day)**

### Interpretation for This Platform

At startup scale (<1M jobs/month), third-party API is significantly cheaper when accounting for:
- No infrastructure operational overhead
- No GPU VM management or on-call burden
- Instant model updates without redeployment

**Self-hosting becomes justified when:**
1. Volume exceeds ~3M jobs/month **and/or**
2. Customer data residency requirements make third-party APIs legally restricted **and/or**
3. Model customisation (fine-tuning) is required that third-party APIs cannot support

**Current recommendation:** Use third-party API for <3M jobs/month. Provision self-hosted infrastructure in parallel to validate operational model and meet data privacy requirements, with the option to shift volume once breakeven is reached.

### If the Bill Comes in 40% Over Budget

First lever to pull: **switch burst workers to spot VMs.**

The baseline warm VM stays on-demand (eviction would create cold starts). All scale-out VMs triggered by queue depth > 50 use spot pricing (~$0.27/hr vs $0.90/hr). Failed spot jobs are automatically retried via the DLQ — no data loss. This alone reduces burst compute cost by ~70%, which for a typical spike workload translates to 25–35% overall monthly saving.

---

## Cost Budget & Alerts

### Budget Thresholds

| Alert level | Threshold | Action |
|---|---|---|
| Warning | $800 / month (80% of $1,000 soft cap) | Notify DevOps lead via email + Slack `#infra-alerts` |
| Critical | $1,000 / month | Notify DevOps lead + CTO via email. Review active VM count and spot vs on-demand split. |
| Emergency | $1,200 / month | Auto-notify engineering leadership. Initiate cost review within 24 hours. |

### Who Gets Notified and How

- **DevOps lead** — Azure Cost Management budget alert via email + Slack webhook to `#infra-alerts`
- **CTO** — email only at critical threshold; real-time visibility via Azure Cost Management dashboard
- **On-call engineer** — PagerDuty integration at emergency threshold if bill trajectory suggests runaway spend (e.g. spot eviction loop spinning up repeated VMs)

### Implementation

In production this would be provisioned via `azurerm_consumption_budget_resource_group` scoped to the resource group, with action groups for email and webhook delivery. Omitted from this design scope as it requires an active Azure subscription and billing account.

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
