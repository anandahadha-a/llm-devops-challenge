\## Scaling Strategy



\### Overview



The system is designed to scale based on \*\*inference request volume\*\*, using the message queue (Azure Service Bus) as the primary signal.



Incoming requests are placed in a queue and processed asynchronously by LLM worker nodes (GPU VMs).



\---



\### Scaling Trigger



Scaling decisions are based on:



\- Queue length (number of pending messages)

\- Request rate (messages per second)



\#### Example Policy:



\- Queue length < 50 → 1 VM (baseline)

\- Queue length 50–200 → scale to 2 VMs

\- Queue length > 200 → scale to 4 VMs



Scaling can be implemented using:

\- Azure Monitor metrics

\- Autoscaling scripts or VM Scale Sets (future improvement)



\---



\### Cold Start Problem



GPU-based instances have high startup time and model loading latency.



To mitigate this:



\- Maintain \*\*1 always-on (warm) VM\*\*

\- Preload model into memory at startup

\- Avoid scaling down to zero



This balances availability and cost: one warm GPU VM handles baseline traffic with low latency, while additional GPU workers are only started when request volume increases.

\---



\### Handling Bursty Workloads



For sudden spikes (e.g., 500+ jobs):



\- The message queue buffers incoming requests

\- Worker nodes process jobs at a controlled rate

\- Prevents system overload and avoids over-provisioning





This design ensures stability under high load conditions.



\---



\### Model Versioning and Deployment



Model artifacts are stored in object storage using versioned paths:

models/v1/

models/v2/







Deployment strategy:



\- Launch new VM instances with updated model version

\- Gradually shift traffic to new instances

\- Drain old instances after in-flight requests complete



This ensures \*\*zero downtime during model updates\*\*.



