# Secret

## What is a Secret?

A Kubernetes Secret stores **sensitive information** such as passwords, API tokens, and certificates.

## Important: Base64 encoding

```bash
# CORRECT — no trailing newline
echo -n "mypassword" | base64

# WRONG — includes hidden \n character
echo "mypassword" | base64
```

## Files

| File | Purpose |
|------|---------|
| `db-secret.yaml` | Secret with database credentials |

## Commands

```bash
kubectl apply -f db-secret.yaml
kubectl get secret yatri-db-secret
kubectl describe secret yatri-db-secret
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

## Cleanup

```bash
kubectl delete secret yatri-db-secret
```
