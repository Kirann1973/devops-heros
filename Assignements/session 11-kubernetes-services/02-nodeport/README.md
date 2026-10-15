# NodePort Service

## What is NodePort?

**NodePort** exposes the Service on each Node's IP at a static port in the range **30000–32767**. External traffic can reach the Service via `<NodeIP>:<NodePort>`.

## How it works

```text
Browser ---> <NodeIP>:30080 ---> Service ---> Pod
```

## Files

| File | Purpose |
|------|---------|
| `app-deployment.yaml` | 3 nginx replicas as backend |
| `service.yaml` | NodePort Service on port 30080 |

## Commands

```bash
kubectl apply -f app-deployment.yaml
kubectl apply -f service.yaml

# Get the URL
minikube service web-service-nodeport --url

# Test access
curl http://$(minikube ip):30080
```

## Cleanup

```bash
kubectl delete -f .
```
