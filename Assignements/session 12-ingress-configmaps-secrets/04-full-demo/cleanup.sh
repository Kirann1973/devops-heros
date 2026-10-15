#!/bin/bash
set -e

echo "[INFO] Deleting Ingress..."
kubectl delete -f ingress.yaml --ignore-not-found

echo "[INFO] Deleting Backend Deployment and Service..."
kubectl delete -f backend.yaml --ignore-not-found

echo "[INFO] Deleting Frontend Deployment and Service..."
kubectl delete -f frontend.yaml --ignore-not-found

echo "[INFO] Deleting Secret..."
kubectl delete -f secret.yaml --ignore-not-found

echo "[INFO] Deleting ConfigMap..."
kubectl delete -f configmap.yaml --ignore-not-found

echo "[INFO] All demo resources removed."
