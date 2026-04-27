\# Security \& Compliance



\## Overview



This design prioritizes security by isolating the LLM inference system within a private network, using managed identities for authentication, and minimizing data exposure.



\---



\## Top Security Risks



\### 1. Unauthorized Access to LLM Service



Risk:

\- External users or attackers gaining direct access to the LLM endpoint



Mitigation:



\- LLM workers are deployed in a \*\*private subnet\*\*

\- No public IP is assigned to the VM

\- Network Security Group (NSG) blocks inbound internet traffic

\- Access is only allowed through internal services



\---



\### 2. Prompt Injection Attacks



Risk:

\- Malicious user input manipulating the LLM behavior



Example:

\- Prompt tries to override instructions or extract sensitive data



Mitigation:



\- Validate and sanitize input before sending to LLM

\- Implement application-layer filtering

\- Avoid exposing system-level instructions

\- Use structured prompts where possible



\---



\### 3. Data Leakage



Risk:

\- Sensitive customer data being stored in logs or reused unintentionally



Mitigation:



\- Do not log full prompts or responses

\- Mask or redact sensitive fields

\- Limit log retention (30–60 days)

\- Disable unnecessary telemetry



\---



\## Identity \& Access Management



\- Use \*\*Azure Managed Identity\*\* instead of credentials

\- Apply \*\*least privilege principle\*\*

&#x20; - LLM VM has read-only access to model storage

\- No secrets are stored in code or Terraform state



\---



\## Network Security



\- All compute resources run inside a \*\*private VNet\*\*

\- LLM service is not exposed publicly

\- NSG rules restrict inbound traffic

\- Future improvement:

&#x20; - Use Azure Firewall or Private Endpoints



\---



\## Secrets Management



\- Secrets (if needed) should be stored in Azure Key Vault

\- Access controlled via Managed Identity

\- No plaintext secrets in code



\---



\## Data Protection



\- Model input/output is not stored permanently

\- No training or fine-tuning is performed on customer data

\- Data is processed in-memory only during inference



\---



\## IaC Security Scanning



Infrastructure as Code should be scanned using tools such as:



\- Checkov

\- Trivy





```bash

trivy config terraform/





Example finding: Storage account network rules should explicitly deny all traffic by default. In a production setup, this would be enforced using private endpoints and network access rules.


## Security Scan Results

IaC security scans were performed using Trivy and Checkov.

The scans identified several recommendations related to:

- Storage logging and monitoring
- Customer-managed encryption keys
- Private endpoints
- Service Bus advanced security configurations

These findings are expected in a simplified, non-production design.

In a production environment, the following improvements would be implemented:

- Enable diagnostic logging for storage services
- Use Azure Key Vault with customer-managed keys
- Configure private endpoints for Storage and Service Bus
- Disable public access for messaging services
- Enable soft delete and backup policies

The current implementation focuses on core security principles while keeping the design simple and aligned with the task scope.