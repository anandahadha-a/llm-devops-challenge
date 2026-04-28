# Security & Compliance

## Overview

This design prioritises security by isolating the LLM inference system within a private network, using managed identities for authentication, and minimising data exposure. The focus is on infrastructure-layer security — application-layer security (auth, rate limiting) is out of scope for this challenge.

---

## Top Security Risks

### 1. Unauthorised Access to LLM Service

**Risk:** External users or attackers gaining direct access to the LLM inference endpoint.

**Mitigation:**
- LLM VM deployed in a private subnet with no public IP
- NSG explicitly denies all inbound internet traffic
- Service is only reachable via the internal queue worker pattern — no direct HTTP exposure

---

### 2. Prompt Injection Attacks

**Risk:** Malicious user input manipulating LLM behaviour — e.g. overriding system instructions, extracting sensitive context, or causing the model to produce harmful output.

**Mitigation:**
- Validate and sanitise input before placing jobs on the queue
- Implement application-layer input filtering (length limits, character restrictions)
- Use structured prompt templates — avoid concatenating raw user input directly into system prompts
- Avoid exposing system-level instructions in error responses

---

### 3. Data Leakage via Logs

**Risk:** Sensitive customer data (prompts, responses) being stored in logs and accessible beyond their intended scope.

**Mitigation:**
- Do not log full prompt or response payloads — log only metadata (job ID, timestamp, status, duration)
- Mask or redact sensitive fields at the application layer
- Set log retention limits (30–60 days)
- Disable unnecessary telemetry

---

## Identity & Access Management

- **User-assigned Managed Identity** used instead of credentials or connection strings
- **Least privilege:** VM has `Storage Blob Data Reader` role scoped to the model storage account only — no write or delete access
- No secrets stored in Terraform code or state
- SSH key authentication only — password authentication disabled on the VM

---

## Network Security

- All compute runs inside a private VNet
- LLM VM has no public IP
- NSG on private subnet: explicit deny-all inbound from Internet
- Public subnet reserved for future ingress resources (Bastion, Application Gateway) — currently has no attached resources

---

## Secrets Management

- No secrets are currently required in this design (Managed Identity removes the need for storage keys or connection strings)
- If secrets are needed in production, they should be stored in **Azure Key Vault** with access controlled via Managed Identity
- No plaintext secrets in code, tfvars, or state

---

## Data Protection

- Model input/output is not stored permanently
- No training or fine-tuning is performed on customer data
- Data is processed in-memory only during inference and discarded after the response is returned

---

## IaC Security Scanning

Scanning was performed using **Trivy** and **Checkov**:

```bash
trivy config terraform/
checkov -d terraform/
```

### Findings & Response

| Finding | Action taken |
|---|---|
| Storage public network access not disabled | Fixed — `public_network_access_enabled = false` |
| Storage allows nested public items | Fixed — `allow_nested_items_to_be_public = false` |
| No minimum TLS version set | Fixed — `min_tls_version = "TLS1_2"` |
| VM password authentication not disabled | Not applicable — SSH key only, no password set |
| No encryption at host on VM | Accepted — noted in production gaps |
| No blob soft delete | Accepted — noted in production gaps |
| No private endpoints | Accepted — noted in production gaps |
| No customer-managed encryption keys | Accepted — noted in production gaps |
| Service Bus no private endpoint | Accepted — Standard SKU limitation, noted in production gaps |

Full scan outputs are in [`scans/trivy.txt`](../scans/trivy.txt) and [`scans/checkov.txt`](../scans/checkov.txt).

---

## What Is Intentionally Not Implemented

The following security controls are out of scope for this design exercise. Each would be required in production.

| Control | Reason deferred |
|---|---|
| Encryption at host (`encryption_at_host_enabled`) | Requires subscription-level feature registration |
| Private Endpoints (Storage, Service Bus) | Service Bus Standard SKU does not support it; added complexity out of scope |
| Azure Bastion | No operator access path required for a non-running system |
| Azure Key Vault (Terraform resource) | No secrets required in current design |
| NSG flow logs | No Log Analytics workspace provisioned |
| Customer-managed encryption keys | Requires Key Vault + disk encryption set wiring |
| Microsoft Defender for Cloud | Enterprise-level, out of scope |
