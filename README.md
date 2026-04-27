# \# Self-Hosted LLM Infrastructure Challenge

# 

# \## Overview

# 

# This repository contains a Terraform-based infrastructure design for deploying and operating a self-hosted LLM inference platform on Azure.

# 

# The goal is to provide a secure, scalable, and cost-aware architecture for asynchronous LLM inference workloads.

# 

# A running system is not required for this challenge. The repository includes Infrastructure as Code, design documentation, cost analysis, observability/runbook guidance, and security scan outputs.

# 

# \---

# 

# \## Architecture

# 

# ```text

# Client / Application

# &#x20;       |

# &#x20;       v

# Azure Service Bus Queue

# &#x20;       |

# &#x20;       v

# GPU VM Worker in Private Subnet

# &#x20;       |

# &#x20;       v

# Self-hosted LLM Inference Service

# &#x20;       |

# &#x20;       v

# Model Artifacts from Azure Blob Storage

# 

# Failed jobs -> Dead Letter Queue

# Logs/Metrics -> Azure Monitor / Log Analytics

# ```

# 

# \---

# 

# \## Main Components

# 

# \### Terraform Infrastructure

# 

# Located in:

# 

# ```text

# terraform/

# ```

# 

# Provisioned components:

# 

# \* Azure Resource Group

# \* Virtual Network

# \* Public and private subnets

# \* Network Security Groups

# \* Azure Blob Storage for model artifacts

# \* Azure Service Bus queue with Dead Letter Queue behavior

# \* User Assigned Managed Identity

# \* GPU-capable Linux VM for LLM inference

# \* Terraform outputs for key resources

# 

# \---

# 

# \## Design Decisions

# 

# \### Azure

# 

# Azure was selected because it provides strong managed services for networking, identity, queueing, storage, and monitoring.

# 

# \### GPU VM

# 

# A GPU-capable VM is used because LLM inference requires high compute performance. The VM runs in a private subnet with no public IP.

# 

# \### Service Bus

# 

# Azure Service Bus is used to buffer asynchronous inference jobs and handle burst traffic. Failed messages are moved to the Dead Letter Queue after multiple retries.

# 

# \### Blob Storage

# 

# Azure Blob Storage stores model artifacts. Active models remain in the Hot tier, while older model versions can be moved to the Cool tier at the blob level.

# 

# \### Managed Identity

# 

# Managed Identity avoids hardcoded credentials. The LLM VM receives read-only access to model storage.

# 

# \---

# 

# \## Repository Structure

# 

# ```text

# .

# ├── terraform/

# │   ├── providers.tf

# │   ├── variables.tf

# │   ├── main.tf

# │   ├── outputs.tf

# │   └── terraform.tfvars.example

# │

# ├── docs/

# │   ├── design.md

# │   ├── cost-analysis.md

# │   ├── runbook.md

# │   └── security.md

# │

# ├── scans/

# │   ├── trivy.txt

# │   └── checkov.txt

# │

# └── README.md

# ```

# 

# \---

# 

# \## How to Run Terraform

# 

# ```bash

# cd terraform

# terraform init

# terraform fmt

# terraform validate

# terraform plan

# ```

# 

# No `terraform apply` is required for this challenge.

# 

# \---

# 

# \## Security Scanning

# 

# IaC security scanning was performed using:

# 

# \* Trivy

# \* Checkov

# 

# Results are stored in:

# 

# ```text

# scans/

# ```

# 

# \---

# 

# \## Documentation

# 

# \* `docs/design.md` — Architecture and scaling strategy

# \* `docs/cost-analysis.md` — Cost estimation and optimization

# \* `docs/runbook.md` — Monitoring and incident handling

# \* `docs/security.md` — Security risks and mitigations

# 

# \---

# 

# \## Assumptions

# 

# \* The system is designed for asynchronous inference

# \* No real model deployment is required

# \* Model artifacts are stored in Azure Blob Storage

# \* GPU VM loads model at startup

# \* Focus is on design, not runtime

# 

# \---

# 

# \## Future Improvements

# 

# \* Use VM Scale Sets for auto-scaling

# \* Add Private Endpoints

# \* Add Azure Firewall / NAT Gateway

# \* Use Customer Managed Keys

# \* Add CI/CD pipeline

# \* Improve observability and logging



