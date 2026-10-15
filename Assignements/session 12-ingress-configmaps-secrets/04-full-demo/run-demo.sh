#!/bin/bash
set -e

echo "[INFO] Enabling NGINX Ingress Controller..."
minikube addons enable ingress
echo "[INFO] Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo ""
echo "[INFO] Applying ConfigMap..."
kubectl apply -f configmap.yaml

echo "[INFO] Applying Secret..."
kubectl apply -f secret.yaml

echo "[INFO] Deploying Backend..."
kubectl apply -f backend.yaml
kubectl rollout status deployment/yatri-backend --timeout=90s

echo "[INFO] Deploying Frontend..."
kubectl apply -f frontend.yaml
kubectl rollout status deployment/yatri-frontend --timeout=90s

echo "[INFO] Applying Ingress..."
kubectl apply -f ingress.yaml

echo ""
echo "[INFO] Adding yatri.local to /etc/hosts..."
MINIKUBE_IP=$(minikube ip)
if ! grep -q "yatri.local" /etc/hosts; then
  echo "${MINIKUBE_IP}  yatri.local" | sudo tee -a /etc/hosts
  echo "[INFO] Added ${MINIKUBE_IP}  yatri.local to /etc/hosts"
else
  echo "[INFO] yatri.local already exists in /etc/hosts"
fi

echo ""
echo "=========================================="
echo " Demo is ready!"
echo " Frontend: http://yatri.local"
echo " Backend:  http://yatri.local/api/"
echo "=========================================="
