# Sessions 9 and 10: Kubernetes Core Objects, Deployment Strategies and Pod Lifecycle

| | |
|---|---|
| **Name** | Kiran N |
| **Roll No.** | 10446 |
| **Sessions** | 9 and 10 (taught together) |
| **Environment** | Multipass Ubuntu VM (arm64) on Mac, Minikube v1.39.0, Kubernetes v1.37.0 |

This folder holds both sessions. Each session has its own folder and its own readme with my commands, real outputs and screenshots.

---

## [Session 9: Kubernetes Introduction, Architecture and Core Objects](session%209/readme.md)

| Task | Result |
|------|--------|
| Install Minikube and start a cluster | Node `minikube` Ready, control plane at `https://192.168.49.2:8443` |
| Kubernetes architecture | apiserver, etcd, scheduler, controller-manager, kubelet, kube-proxy, containerd, CoreDNS explained with my `kube-system` pods |
| Kubernetes Basics tutorial | Deployment `hello-kiran`: exposed (HTTP 200), scaled to 4, updated to nginx 1.25 and rolled back to 1.24 |
| Core objects | Pod (2/2), ReplicaSet (self-healing tested), Deployment, DaemonSet, StatefulSet (`mysql-0`, `mysql-1` with Bound PVCs) |

Files: [`session9_lab.sh`](session%209/session9_lab.sh), [`k8s-core-objects/`](session%209/k8s-core-objects/), [`class-practice/`](session%209/class-practice/), [`screenshots/`](session%209/screenshots/)

---

## [Session 10: Deployment Strategies and Pod Lifecycle](session%2010/readme.md)

| Task | Result |
|------|--------|
| Rolling Update | 4 × v1 replaced by 4 × v2 one at a time, never fewer than 4 ready pods |
| Blue-Green | 10/10 requests BLUE, switched the Service selector, then 10/10 GREEN |
| Canary | 100 requests: 13 to canary v2, 87 to stable v1 |
| Recreate | Old ReplicaSet 3 → 0 first, then new ReplicaSet 0 → 3 |
| Pod lifecycle (12 cases) | Running, Pending, Succeeded, Failed, CrashLoopBackOff, ImagePullBackOff, readiness, liveness, startup, init container, sidecar, graceful termination |

Files: [`strategies_lab.sh`](session%2010/strategies_lab.sh), [`pod_lifecycle_lab.sh`](session%2010/pod_lifecycle_lab.sh), [`01-rolling-update/`](session%2010/01-rolling-update/), [`02-blue-green/`](session%2010/02-blue-green/), [`03-canary/`](session%2010/03-canary/), [`04-recreate/`](session%2010/04-recreate/), [`pod-lifecycle/`](session%2010/pod-lifecycle/), [`screenshots/`](session%2010/screenshots/)

---

## Folder structure

```
session 9-10-k8s-core-objects/
├── readme.md            # this index
├── session 9/
│   ├── readme.md
│   ├── session9_lab.sh
│   ├── k8s-core-objects/
│   ├── class-practice/
│   └── screenshots/
└── session 10/
    ├── readme.md
    ├── strategies_lab.sh
    ├── pod_lifecycle_lab.sh
    ├── 01-rolling-update/  02-blue-green/  03-canary/  04-recreate/
    ├── pod-lifecycle/
    └── screenshots/
```

## How to run

```bash
minikube start --driver=docker --cpus=2 --memory=3500

cd "session 9"  && bash session9_lab.sh
cd "../session 10" && bash strategies_lab.sh && bash pod_lifecycle_lab.sh
```

Each script saves every section to `outputs/<section>.txt`.

---

**Kiran N | Roll No. 10446**
