# Full Demo — ConfigMap + Secret + Frontend + Backend + Ingress

This demo combines all Session 12 concepts into a complete working application.

## Architecture

```text
Client → Ingress Controller → Ingress Rules
                                    |
                         +----------+----------+
                         |                     |
                      /api/                    /
                         |                     |
                   Backend Svc          Frontend Svc
                         |                     |
                   Backend Pods          Frontend Pods
                         |
                  ConfigMap + Secret
```

## Files

| File | Purpose |
|------|---------|
| `configmap.yaml` | Application configuration |
| `secret.yaml` | Database credentials (Base64) |
| `backend.yaml` | Backend Deployment + ClusterIP Service |
| `frontend.yaml` | Frontend Deployment + ClusterIP Service |
| `ingress.yaml` | Path-based routing rules |
| `run-demo.sh` | Automated setup script |
| `cleanup.sh` | Automated teardown script |

## Quick Start

```bash
bash run-demo.sh
```

## Manual Steps

```bash
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml
kubectl apply -f ingress.yaml
echo "$(minikube ip)  yatri.local" | sudo tee -a /etc/hosts
curl http://yatri.local
curl http://yatri.local/api/
```

## Cleanup

```bash
bash cleanup.sh
```
