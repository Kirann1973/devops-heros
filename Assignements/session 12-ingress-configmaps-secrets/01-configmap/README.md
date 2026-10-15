# ConfigMap

## What is a ConfigMap?

A ConfigMap stores **non-sensitive configuration data** as key-value pairs, separate from the container image.

## Files

| File | Purpose |
|------|---------|
| `app-config.yaml` | ConfigMap with application settings |

## Commands

```bash
kubectl apply -f app-config.yaml
kubectl get configmap yatri-app-config
kubectl describe configmap yatri-app-config
kubectl get configmap yatri-app-config -o jsonpath='{.data.LOG_LEVEL}'
```

## Cleanup

```bash
kubectl delete configmap yatri-app-config
```
