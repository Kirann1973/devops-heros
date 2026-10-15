# ExternalName Service

## What is ExternalName?

**ExternalName** maps a Service to an external DNS name using a CNAME record. No proxying occurs — it's purely a DNS-level redirect.

## How it works

```text
Pod ---> external-database-service ---> CNAME ---> api.github.com
```

No selector or endpoints are needed.

## Files

| File | Purpose |
|------|---------|
| `service.yaml` | ExternalName Service pointing to `api.github.com` |
| `client-pod.yaml` | Test Pod to verify DNS resolution |

## Commands

```bash
kubectl apply -f service.yaml
kubectl apply -f client-pod.yaml

# Verify
kubectl get svc external-database-service
kubectl logs externalname-client
```

## Cleanup

```bash
kubectl delete -f .
```
