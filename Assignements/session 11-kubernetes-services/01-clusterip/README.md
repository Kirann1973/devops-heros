# ClusterIP Service

## What is ClusterIP?

**ClusterIP** is the default Kubernetes Service type. It exposes the Service on an **internal cluster IP**, making it reachable only from within the cluster.

## How it works

```text
[Pod A] ---> web-service-clusterip:80 ---> [Pod B]
                  (ClusterIP)
```

Only Pods inside the cluster can reach a ClusterIP Service.

## Files

| File | Purpose |
|------|---------|
| `app-deployment.yaml` | 3 nginx replicas as backend |
| `service.yaml` | ClusterIP Service on port 80 |
| `client-pod.yaml` | Test Pod to verify internal access |

## Commands

```bash
kubectl apply -f app-deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f client-pod.yaml

# Verify Service
kubectl get svc web-service-clusterip
kubectl get endpoints web-service-clusterip

# Test from client Pod
kubectl logs clusterip-client
```

## Cleanup

```bash
kubectl delete -f .
```
