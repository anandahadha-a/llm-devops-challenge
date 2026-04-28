# Part 6 — Short Reflection

## Customer Question: "Is my data used to train or fine-tune your model?"

This is one of the most important trust questions for any AI platform serving SMB customers, and it deserves a confident, verifiable answer — not just a policy statement.

---

## The Short Answer

No. The infrastructure is designed so that customer data used in inference requests cannot reach any training pipeline, cannot be persisted beyond the inference response, and never leaves the private network boundary to an external model provider.

---

## Infrastructure Guarantees

**1. Self-hosted model — no data leaves to third parties**

The LLM (Mistral-7B-Instruct) runs entirely within the customer's private Azure infrastructure. Inference requests never touch a third-party API. There is no path from the inference worker to OpenAI, Anthropic, or any external model provider. The network security group explicitly denies all outbound internet traffic from the private subnet by default.

**2. In-memory processing only**

The worker process submits the prompt to vLLM, receives the response, and discards both. No prompt or response payload is written to disk, logged to a file, or published to a data store. The only data persisted is job metadata — job ID, timestamp, status, duration — none of which contains customer content.

**3. No training or fine-tuning pipeline exists**

There is no MLflow server, no training job scheduler, no dataset storage bucket, and no GPU training workload in this infrastructure. The absence of these components is itself an architectural guarantee — you cannot accidentally fine-tune on customer data if there is no fine-tuning infrastructure to trigger.

**4. Model artifacts are read-only**

The GPU VM has `Storage Blob Data Reader` access to the model storage container — read-only, scoped to that container only. It cannot write model weights back to storage. A compromised worker process could not modify or replace the model.

---

## Operational Guarantees

**Audit trail without payload logging**

Every inference job is logged with metadata only: job ID, customer ID, workflow type, response duration, success/failure status. This creates an auditable record of what was processed and when, without capturing what the customer's prompt contained. If a customer asks "was my data processed on this date?", we can answer yes or no from logs. If they ask "what did you do with it?", the logs show it was processed and completed — nothing more.

**Log retention policy**

Logs are retained for 30–60 days and then automatically purged. There is no long-term data lake ingesting inference metadata that could be mined for model improvement.

**Separation of inference and model development environments**

Any future fine-tuning or model development work would happen in a fully isolated environment with separately provisioned infrastructure, explicit data consent flows, and no automated pipeline connecting production inference traffic to training datasets.

---

## How to Answer the Customer Confidently

A policy document is not enough. To give a customer a confident, verifiable answer, the following would be in place:

1. **Architecture review** — Share a network diagram showing the private subnet boundary and the absence of any outbound connection to external model APIs or training systems. Let them see there is no path for data to travel out.

2. **Audit log access** — Provide the customer with read access to their own job metadata logs. They can verify their jobs were processed and completed, with no payload content stored.

3. **Data Processing Agreement (DPA)** — A contractual commitment that inference data is processed in-memory only, not retained beyond the response, and not used for any model training or improvement purposes.

4. **Infrastructure-as-Code transparency** — The Terraform code is the authoritative description of what infrastructure exists. Sharing it (or a review of it) demonstrates there is no training pipeline, no dataset bucket, no model update workflow connected to production inference.

The strongest answer to "is my data used to train the model?" is not a promise — it is showing the customer an architecture where training on their data is structurally impossible.
