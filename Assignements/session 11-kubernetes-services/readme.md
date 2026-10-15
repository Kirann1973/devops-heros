# ☸️ Session 11 — Kubernetes Services: Service Discovery & External Access

---

## 📌 Overview

This session covered the major **Kubernetes Service types** and how they provide internal communication, external access, DNS-based discovery, and direct Pod discovery.

> **Name:** Kiran N
> **Roll No.:** 24bcs10446
> **Session:** 11 — Kubernetes Services

---

## 🛠️ Service Types Covered

| # | Service Type   | Purpose                                         |
|---|----------------|--------------------------------------------------|
| 1 | ClusterIP      | Internal microservice communication              |
| 2 | NodePort       | External host-level cluster access               |
| 3 | LoadBalancer   | Production public cloud ingress                  |
| 4 | ExternalName   | External DNS alias                               |
| 5 | Headless       | Direct Pod-to-Pod discovery (`clusterIP: None`)  |

---

## 1️⃣ ClusterIP Service — Internal Microservice Communication

ClusterIP is the **default** Service type. It exposes the Service on an internal cluster IP, making it reachable only from within the cluster.

![ClusterIP 1](<Screenshots/Screenshot 2026-09-17 115358.png>)

![ClusterIP 2](<Screenshots/Screenshot 2026-09-17 115705.png>)

---

## 2️⃣ NodePort Service — External Host-Level Cluster Access

NodePort exposes the Service on each Node's IP at a static port (range 30000–32767). External traffic can reach the Service via `<NodeIP>:<NodePort>`.

![NodePort](<Screenshots/Screenshot 2026-09-17 115751.png>)

---

## 3️⃣ LoadBalancer Service — Production Public Cloud Ingress

LoadBalancer provisions an external load balancer (on cloud providers like AWS, GCP, Azure) that routes traffic to the Service.

![LoadBalancer](<Screenshots/Screenshot (92).png>)

---

## 4️⃣ ExternalName Service — External DNS Alias

ExternalName maps a Service to an external DNS name (CNAME record). No proxying occurs — it's purely a DNS-level redirect.

---

## 5️⃣ Headless Service (`clusterIP: None`) — Direct Pod-to-Pod Discovery

A Headless Service returns individual Pod IPs instead of a single virtual IP. Used with StatefulSets for direct Pod discovery.

![Headless 1](<Screenshots/Screenshot 2026-09-17 120807.png>)

---

![Headless 2](<Screenshots/Screenshot 2026-09-17 120829.png>)

---

## 📊 All Services

![All Services](<Screenshots/Screenshot 2026-09-17 121212.png>)

---

## 🏁 Conclusion

This session demonstrated how Kubernetes Services provide different networking and service-discovery mechanisms.

```text
ClusterIP      → Internal Service Access
NodePort       → Node-Level External Access
LoadBalancer   → External Load Balancer
ExternalName   → External DNS Alias
Headless       → Direct Pod Discovery
```

Together, these Service types form the foundation for communication and exposure of workloads in Kubernetes.

---

## 📝 Additional Questions & Research

### Q1. Difference Between DaemonSet and StatefulSet

| Feature         | DaemonSet                                | StatefulSet                                    |
|-----------------|------------------------------------------|------------------------------------------------|
| Primary purpose | Runs a Pod on every or selected node     | Runs Pods with stable identities               |
| Pod placement   | Node-oriented                            | Scheduler-oriented                             |
| Pod identity    | Not stable                               | Stable and predictable                         |
| Pod names       | Random/generated                         | Ordered, e.g. `app-0`, `app-1`                 |
| Storage         | No special storage identity              | Can provide stable PersistentVolumeClaims      |
| Scaling         | Usually tied to number of matching nodes | Explicit replica count                         |
| Typical use     | Monitoring, logging, node agents         | Databases, Kafka, distributed stateful systems |

A **DaemonSet** is used when a workload needs a copy of a Pod on each matching node, such as log collectors or node-monitoring agents. A **StatefulSet** is used when Pods need stable identities, persistent storage, or ordered deployment/scaling.

```text
DaemonSet  →  "I need one Pod per Node."
StatefulSet →  "I need Pods with identities."
```

---

### Q2. Difference Between Deployment, ReplicaSet and DaemonSet

| Feature         | Deployment                    | ReplicaSet                        | DaemonSet                       |
|-----------------|-------------------------------|-----------------------------------|---------------------------------|
| Main purpose    | Manage stateless applications | Maintain a fixed number of Pods   | Run a Pod on each matching node |
| Replica control | Yes                           | Yes                               | Based on nodes                  |
| Rolling updates | Yes                           | No built-in rollout orchestration | Yes                             |
| Pod identity    | Interchangeable               | Interchangeable                   | Node-associated                 |
| Typical use     | Web/API applications          | Usually managed by Deployment     | Node-level agents               |
| Example         | Frontend with 5 replicas      | Maintain 5 identical Pods         | Log collector on every node     |

#### Relationship

A Deployment normally manages a ReplicaSet, and the ReplicaSet manages the actual Pods:

```text
Deployment
    |
    ↓
ReplicaSet
    |
    +---- Pod
    +---- Pod
    +---- Pod
```

A DaemonSet works differently:

```text
DaemonSet
    |
    +---- Node 1 → Pod
    +---- Node 2 → Pod
    +---- Node 3 → Pod
```

---

### Q3. Research: CoreDNS and Kubernetes DNS

**CoreDNS** is the default DNS implementation used for Kubernetes cluster DNS.

It allows Pods to discover Services and other Kubernetes resources using DNS names instead of hardcoded IP addresses.

```text
web-service-clusterip
        ↓
CoreDNS
        ↓
Service ClusterIP
```

For a Headless Service:

```text
web-service-headless
        ↓
CoreDNS
        ↓
Pod IPs
```

For an `ExternalName` Service:

```text
external-database-service
        ↓
CoreDNS
        ↓
CNAME → api.github.com
```

#### Why CoreDNS matters

* Provides DNS-based Service Discovery.
* Allows applications to use stable Service names instead of IP addresses.
* Resolves Kubernetes Service names such as:

```text
<service>.<namespace>.svc.cluster.local
```

* Supports Headless Service discovery by returning individual Pod addresses.
* Can be configured through its CoreDNS `Corefile`/ConfigMap.

#### NodeLocal DNSCache

Kubernetes also supports **NodeLocal DNSCache**, which runs a DNS caching agent as a DaemonSet on cluster nodes.

```text
Pod
 ↓
NodeLocal DNSCache
 ↓
CoreDNS
 ↓
Kubernetes / External DNS
```

---

## 🔁 Quick Revision

```text
Deployment   → Manages stateless application releases.
ReplicaSet   → Maintains the required number of identical Pods.
DaemonSet    → Runs a Pod on every or selected Node.
StatefulSet  → Runs Pods with stable identities and storage relationships.
CoreDNS      → Provides DNS-based service discovery inside Kubernetes.
```

---

## ✍️ Author

**Kiran N**
**Roll No.:** 24bcs10446
