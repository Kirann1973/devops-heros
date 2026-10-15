# Ingress

## What is Ingress?

Ingress provides rules for routing **external HTTP/HTTPS traffic** to Kubernetes Services.

## Files

| File | Purpose |
|------|---------|
| `ingress-routes.yaml` | Basic Ingress with path-based routing |
| `ingress-tls.yaml` | Ingress with TLS termination |
| `path-based.yml` | Simple path-based routing example |

## Enable Ingress Controller on Minikube

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

## Commands

```bash
kubectl apply -f ingress-routes.yaml
kubectl get ingress
kubectl describe ingress yatri-ingress
```

## Cleanup

```bash
kubectl delete -f .
```
