# Headless Service

## What is a Headless Service?

A **Headless Service** (`clusterIP: None`) returns individual Pod IPs instead of a single virtual IP. DNS lookups return all Pod endpoints directly.

## How it works

```text
nslookup web-service-headless
  → 10.244.0.5  (Pod 0)
  → 10.244.0.6  (Pod 1)
  → 10.244.0.7  (Pod 2)
```

Used with StatefulSets for direct Pod-to-Pod discovery.

## Files

| File | Purpose |
|------|---------|
| `app-statefulset.yaml` | StatefulSet with 3 nginx replicas |
| `service.yaml` | Headless Service (`clusterIP: None`) |
| `client-pod.yaml` | Test Pod to verify individual Pod DNS |

## Commands

```bash
kubectl apply -f service.yaml
kubectl apply -f app-statefulset.yaml
kubectl apply -f client-pod.yaml

# Verify
kubectl get pods -l app=web-headless
kubectl get endpoints web-service-headless
kubectl logs headless-client
```

## Cleanup

```bash
kubectl delete -f .
```
