# Kubernetes Services — Complete Reference

---

## What is a Service?

A **Service** is a Kubernetes abstraction that provides a stable network endpoint to access a group of Pods.

Pods are ephemeral — they get created and destroyed frequently. Their IP addresses change every time. A Service provides a **stable IP and DNS name** that automatically routes traffic to the current set of healthy Pods.

```text
Client
  ↓
Service (stable IP + DNS)
  ↓
kube-proxy (iptables / IPVS rules)
  ↓
Pod endpoints (dynamically updated)
```

---

## Why Do We Need Services?

| Problem                          | Service Solution                              |
|----------------------------------|-----------------------------------------------|
| Pod IPs change on restart        | Service provides a stable ClusterIP           |
| No DNS for bare Pods             | Service gets automatic DNS via CoreDNS        |
| No load balancing for Pods       | Service distributes traffic across Pod replicas |
| No external access to Pods       | NodePort / LoadBalancer expose externally      |

---

## Service Types

### 1. ClusterIP (Default)

Exposes the Service on an **internal cluster IP**. Only reachable from within the cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-clusterip
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

**Use case:** Microservice-to-microservice communication inside the cluster.

```text
[Pod A] ---> web-service-clusterip:80 ---> [Pod B (web)]
```

---

### 2. NodePort

Exposes the Service on each **Node's IP** at a static port (30000–32767).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30080
```

**Use case:** Development/testing — access from outside the cluster via `<NodeIP>:30080`.

```text
Browser ---> <NodeIP>:30080 ---> Service ---> Pod
```

---

### 3. LoadBalancer

Provisions an **external load balancer** from the cloud provider (AWS ELB, GCP LB, Azure LB).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-lb
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

**Use case:** Production — expose applications to the internet with a public IP.

```text
Internet ---> Cloud Load Balancer ---> NodePort ---> Service ---> Pod
```

> On Minikube, use `minikube tunnel` to simulate a LoadBalancer.

---

### 4. ExternalName

Maps a Service to an **external DNS name** (CNAME record). No proxying occurs.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  type: ExternalName
  externalName: db.example.com
```

**Use case:** Point internal Service names to external resources without hardcoding URLs in application code.

```text
Pod ---> external-database ---> CNAME ---> db.example.com
```

---

### 5. Headless Service (`clusterIP: None`)

Returns **individual Pod IPs** instead of a single virtual IP. Used with StatefulSets.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-headless
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

**Use case:** StatefulSets, databases — when clients need to connect to specific Pods.

```text
nslookup web-service-headless
  → 10.244.0.5
  → 10.244.0.6
  → 10.244.0.7  (individual Pod IPs)
```

---

## Service Type Comparison

| Feature          | ClusterIP     | NodePort         | LoadBalancer       | ExternalName    | Headless           |
|------------------|---------------|------------------|--------------------|-----------------|--------------------|
| Accessible from  | Inside cluster | Node IP + Port   | Public internet    | DNS alias       | Inside cluster     |
| Gets ClusterIP   | ✅ Yes         | ✅ Yes            | ✅ Yes              | ❌ No            | ❌ No               |
| Port range       | Any           | 30000–32767      | Any                | N/A             | Any                |
| Load balancing   | ✅ Round-robin | ✅ Round-robin    | ✅ Cloud LB         | ❌ None          | ❌ Client-side      |
| DNS returns      | ClusterIP     | ClusterIP        | External IP        | CNAME           | Pod IPs            |
| Best for         | Internal APIs | Dev/test access  | Production traffic | External DBs    | StatefulSets       |

---

## How Services Select Pods

Services use **label selectors** to find matching Pods:

```yaml
# Service selector
spec:
  selector:
    app: web

# Pod labels (must match)
metadata:
  labels:
    app: web
```

Kubernetes maintains an **Endpoints** object that tracks all matching Pod IPs:

```bash
kubectl get endpoints web-service-clusterip
```

```text
NAME                    ENDPOINTS                                 AGE
web-service-clusterip   10.244.0.5:80,10.244.0.6:80,10.244.0.7:80   5m
```

---

## Useful Commands

| Action                        | Command                                        |
|-------------------------------|-------------------------------------------------|
| List all Services             | `kubectl get svc`                               |
| Describe a Service            | `kubectl describe svc <name>`                   |
| View endpoints                | `kubectl get endpoints <name>`                  |
| Test from inside cluster      | `kubectl run test --image=busybox --rm -it -- wget -qO- <service>` |
| Get Service URL (Minikube)    | `minikube service <name> --url`                 |

---

## Port Terminology

```yaml
ports:
  - port: 80        # Service port (what clients connect to)
    targetPort: 8080 # Container port (where the app listens)
    nodePort: 30080  # Node port (external access, NodePort type only)
```

```text
Client → port (80) → Service → targetPort (8080) → Container
                         ↑
              nodePort (30080) — external access via Node IP
```
