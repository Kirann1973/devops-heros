# FQDN — Fully Qualified Domain Name in Kubernetes

---

## What is FQDN?

A **Fully Qualified Domain Name (FQDN)** is the complete, unambiguous DNS name that uniquely identifies a resource within a Kubernetes cluster.

Every Kubernetes Service gets a DNS entry automatically via **CoreDNS**.

---

## FQDN Format

```text
<service-name>.<namespace>.svc.cluster.local
```

| Part            | Meaning                                      |
|-----------------|----------------------------------------------|
| `service-name`  | Name of the Kubernetes Service               |
| `namespace`     | Namespace the Service lives in               |
| `svc`           | Indicates it is a Service resource            |
| `cluster.local` | Default cluster domain (configurable)         |

---

## Examples

### Service in `default` namespace

```text
web-service-clusterip.default.svc.cluster.local
```

### Service in `production` namespace

```text
api-gateway.production.svc.cluster.local
```

### Headless Service Pod DNS

For StatefulSets with Headless Services, each Pod gets its own FQDN:

```text
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

Example:

```text
mysql-0.mysql-headless.default.svc.cluster.local
mysql-1.mysql-headless.default.svc.cluster.local
mysql-2.mysql-headless.default.svc.cluster.local
```

---

## Short Names vs FQDN

Within the **same namespace**, you can use short names:

```bash
# Same namespace — all three work:
curl http://web-service
curl http://web-service.default
curl http://web-service.default.svc.cluster.local
```

Across **different namespaces**, you need at least `<service>.<namespace>`:

```bash
# From namespace "frontend" calling service in namespace "backend":
curl http://api-service.backend
curl http://api-service.backend.svc.cluster.local
```

---

## DNS Resolution Flow

```text
Pod makes DNS query
        ↓
/etc/resolv.conf points to CoreDNS
        ↓
CoreDNS resolves the FQDN
        ↓
Returns ClusterIP (or Pod IPs for Headless)
        ↓
Pod connects to the resolved IP
```

---

## How to Test FQDN Resolution

### From inside a Pod

```bash
# Start a debug Pod
kubectl run dns-test --image=busybox:1.36 --rm -it -- sh

# Inside the Pod:
nslookup web-service-clusterip
nslookup web-service-clusterip.default.svc.cluster.local
```

### Check /etc/resolv.conf

```bash
kubectl exec dns-test -- cat /etc/resolv.conf
```

Expected output:

```text
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
ndots:5
```

The `search` line is what allows short names to work — Kubernetes appends these suffixes automatically.

---

## Key Points

* Every Service automatically gets a DNS entry via CoreDNS
* FQDN format: `<service>.<namespace>.svc.cluster.local`
* Short names work within the same namespace
* Cross-namespace calls require at least `<service>.<namespace>`
* Headless Services give each Pod its own unique FQDN
* The `ndots:5` setting in resolv.conf means names with fewer than 5 dots get the search suffixes appended
