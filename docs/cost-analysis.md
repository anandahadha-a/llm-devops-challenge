\# Cost Management



\## Cost Assumptions



This design uses Azure services with a startup-appropriate approach. The largest cost driver is the GPU VM used for LLM inference. Supporting services such as Service Bus, Blob Storage, Key Vault, and monitoring are relatively small compared to GPU compute.



Prices are estimated and should be validated using the Azure Pricing Calculator before production deployment.



\---



\## Main Cost Drivers



\### 1. GPU Compute



The GPU VM is expected to be the most expensive component.



For this design, a GPU-capable VM such as `Standard\_NC6` / `NC6s\_v3` is used for inference workloads. GPU instances are required because LLM inference involves heavy matrix operations and benefits significantly from GPU acceleration.



Cost control approach:



\- Maintain 1 warm VM for baseline traffic (to reduce latency)

\- Scale additional GPU workers only when queue depth increases

\- Scale down gradually after traffic decreases

\- Use reserved instances or savings plans for predictable workloads

\- Use spot VMs for non-critical or batch inference workloads



\---



\### 2. Azure Service Bus



Azure Service Bus is used to buffer asynchronous inference jobs and prevent direct overload on GPU workers.



Benefits:



\- Handles burst traffic efficiently

\- Provides built-in retry and dead-letter queue (DLQ)

\- Reduces need for over-provisioning compute resources



Cost impact is relatively low compared to compute and scales with usage.



\---



\### 3. Azure Blob Storage



Blob Storage is used to store LLM model artifacts.



\- Active models are stored in the \*\*Hot tier\*\* to ensure fast access during VM startup

\- Older or infrequently used models can be moved to the \*\*Cool tier\*\* to reduce storage cost



Important considerations:



\- Models are downloaded once at VM startup and loaded into memory

\- They are not downloaded per request

\- New scaled VMs will download the model again during initialization



This approach balances performance and cost.



\---



\### 4. Monitoring and Logs



Azure Monitor and Log Analytics are used for observability.



Cost considerations:



\- Log ingestion and storage generate costs

\- Logs should not be stored indefinitely



Recommendation:



\- Configure retention limits (e.g., 30–60 days)

\- Automatically delete older logs to prevent cost growth



This ensures visibility while controlling long-term storage costs.



\---



\## Tagging Strategy



All resources are tagged with:



\- `Project`

\- `Environment`

\- `Owner`

\- `ManagedBy`

\- `Workload`



Additional production tags:



\- `CustomerId`

\- `WorkflowType`

\- `CostCenter`

\- `ModelName`



Example:



```text

CustomerId = customer-a

WorkflowType = document-summary

ModelName = mistral-7b

