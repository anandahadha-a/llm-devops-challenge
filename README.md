# Self-Hosted LLM Infrastructure Challenge

## Overview

Terraform-based infrastructure design for deploying a self-hosted LLM inference platform on Azure.

Designed for **asynchronous GPU inference** with a focus on network isolation, least-privilege identity, cost-conscious GPU SKU selection, and IaC security scanning. A running system is not required for this challenge — the repository covers infrastructure as code, architecture design, cost analysis, observability, and security.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Public Internet                  │
└──────────────────────┬──────────────────────────────┘
                       │
               Client / Application
                       │
               Azure Service Bus
                (inference-jobs queue)
                       │
┌──────────────────────▼──────────────────────────────┐
│              Private Subnet (10.20.2.0/24)          │
│                                                     │
│   GPU VM (Standard_NC4as_T4_v3)                     │
│     │  Managed Identity (read-only)                 │
│     └──► Azure Blob Storage (model artifacts)       │
│                                                     │
│   NSG: deny all inbound from Internet               │
└─────────────────────────────────────────────────────┘

Failed jobs  ──► Dead Letter Queue
Logs/Metrics ──► Azure Monitor / Log Analytics
```

---

## Main Components

| Resource | Purpose |
|---|---|
| Azure Resource Group | Logical boundary for all resources |
| Virtual Network + Subnets | Network isolation (public + private) |
| Network Security Groups | Deny internet inbound on private subnet |
| Azure Blob Storage | Model artifact storage (private, TLS 1.2+) |
| Azure Service Bus Queue | Async inference job queue with DLQ |
| User Assigned Managed Identity | Credential-free access to storage |
| GPU Linux VM | LLM inference worker (NVIDIA T4) |

---

## Design Decisions

### GPU VM — `Standard_NC4as_T4_v3`

Selected over the older `Standard_NC6` (K80) because the T4 supports FP16/BF16 inference and offers significantly better throughput for modern LLMs at a lower cost per inference.

- OS disk: `Premium_LRS` (SSD) with 128 GB to avoid I/O bottlenecks during model loading and to accommodate OS, CUDA drivers, and runtime dependencies
- Static private IP (`10.20.2.10`) for stability across VM restarts

### Service Bus

Buffers async inference requests and decouples the client from the GPU worker. Dead-lettering is enabled so failed jobs are preserved for inspection rather than silently dropped. `max_delivery_count = 5` limits retry loops.

### Blob Storage

Stores model artifacts with `public_network_access_enabled = false` and `allow_nested_items_to_be_public = false`. The managed identity grants the VM read-only access — no storage keys are used.

Storage account name uses `substr(..., 0, 24)` to enforce Azure's hard 24-character limit regardless of the `project_name` variable length.

### Managed Identity

User-assigned identity scoped to `Storage Blob Data Reader` on the storage account. No passwords, no connection strings, no secrets in config.

### Network

The LLM VM sits in a private subnet with an NSG that explicitly denies all inbound internet traffic. The public subnet is reserved for future ingress resources (e.g. Azure Bastion, Application Gateway).

---

## Repository Structure

```
.
├── terraform/
│   ├── providers.tf        # Provider and version constraints
│   ├── variables.tf        # Input variables with validation
│   ├── main.tf             # All resource definitions
│   ├── outputs.tf          # Key resource outputs
│   └── terraform.tfvars.example
│
├── docs/
│   ├── design.md           # Architecture and scaling strategy
│   ├── cost-analysis.md    # Cost estimation and optimisation
│   ├── runbook.md          # Monitoring and incident handling
│   └── security.md        # Security risks and mitigations
│
├── scans/
│   ├── trivy.txt           # Trivy IaC scan output
│   └── checkov.txt         # Checkov IaC scan output
│
└── README.md
```

---

## How to Run Terraform

```bash
cd terraform
terraform init
terraform fmt
terraform validate
terraform plan
```

> `terraform apply` is not required for this challenge.

A representative dry-run plan output is available at [`terraform/plan.txt`](terraform/plan.txt). It shows all 16 resources that would be created, including resolved names, tags, and configuration values.

---

## Security Scanning

IaC scanning was performed using **Trivy** and **Checkov**. Key findings and mitigations:

| Finding | Action |
|---|---|
| Storage public access not disabled | Fixed — `public_network_access_enabled = false` |
| No TLS minimum version set | Fixed — `min_tls_version = "TLS1_2"` |
| VM uses password authentication | Not applicable — SSH key only, password disabled |
| No encryption at host | Accepted — noted in Production Gaps |
| No Blob soft delete | Accepted — noted in Production Gaps |

Full scan outputs are in [`scans/`](scans/).

---

## Documentation

- [`docs/design.md`](docs/design.md) — Architecture decisions, serving framework, and scaling strategy
- [`docs/cost-analysis.md`](docs/cost-analysis.md) — Cost breakdown, build vs. buy analysis, and budget alerts
- [`docs/runbook.md`](docs/runbook.md) — Monitoring, GPU-specific alerts, and incident handling
- [`docs/security.md`](docs/security.md) — Security risks, IaC scan findings, and data handling
- [`docs/reflection.md`](docs/reflection.md) — Customer data privacy guarantees and trust model

---

## Assumptions

- Inference workload is asynchronous — no real-time latency SLA
- No live model deployment required for this challenge
- GPU VM loads the model from Blob Storage at startup
- Single VM worker — horizontal scaling is a production concern
- Focus is on architecture and design, not runtime

---

## Production Gaps

This is a design exercise. The following are intentionally out of scope and would be required before any production deployment.

### Critical

- **Remote state backend** — No `backend` block in `providers.tf`. Production requires Azure Blob Storage backend with lease-based state locking for team workflows and CI/CD.
- **Service Bus Premium SKU** — `Standard` SKU does not support Private Endpoints or VNet integration. The namespace is publicly reachable. `Premium` is required for full network isolation.
- **Private Endpoints** — Storage has `public_network_access_enabled = false` but no `azurerm_private_endpoint`. Without it the VM cannot reach the storage account. Both Storage and Service Bus (Premium) need private endpoints.
- **VM access path** — No public IP, no Azure Bastion. Operators cannot reach the VM. An `azurerm_bastion_host` in the public subnet is required.
- **Encryption at host** — OS disk has no `encryption_at_host_enabled = true` and no Customer Managed Key. Required for compliance and data residency.

### Important

- **VM image pinning** — `version = "latest"` is non-deterministic. Production should pin to a specific image version for reproducible deployments.
- **Hardcoded private IP** — `10.20.2.10` is hardcoded in the NIC while `private_subnet_prefix` is a variable. Overriding the subnet causes a deployment failure.
- **Observability** — No `azurerm_monitor_diagnostic_setting` on any resource. No NSG flow logs. No Log Analytics workspace.
- **Resource lock** — No `azurerm_management_lock` on the resource group to prevent accidental deletion.
- **Boot diagnostics** — No `boot_diagnostics` block on the VM, making GPU driver or OOM failures invisible.
- **Location validation** — The `location` variable has no validation rule. A typo fails at apply time rather than plan time.
