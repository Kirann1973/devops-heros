# LoadBalancer Service

## What is LoadBalancer?

**LoadBalancer** provisions an external load balancer from the cloud provider (AWS ELB, GCP LB, Azure LB) that routes traffic to the Service.

## How it works

```text
Internet ---> Cloud Load Balancer ---> NodePort ---> Service ---> Pod
```

On Minikube, use `minikube tunnel` to simulate a LoadBalancer.

## Files

| File | Purpose |
|------|---------|
| `app-deployment.yaml` | 3 nginx replicas as backend |
| `service.yaml` | LoadBalancer Service on port 80 |

## Commands

```bash
kubectl apply -f app-deployment.yaml
kubectl apply -f service.yaml

# On Minikube — open a separate terminal:
minikube tunnel

# Check external IP
kubectl get svc web-service-loadbalancer
```

## Cleanup

```bash
kubectl delete -f .
```
