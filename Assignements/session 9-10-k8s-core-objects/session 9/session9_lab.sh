#!/bin/bash
# Session 9 - Kubernetes Fundamentals lab (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 9" folder, after "minikube start".
# Each part is saved to its own file in outputs/ so it fits in one screenshot.

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }

kubectl delete deployment,service hello-kiran --ignore-not-found >/dev/null 2>&1
IP=$(minikube ip)

section s9-01-cluster "Session 9: Minikube cluster status"
run 'minikube version'
run 'minikube status'
run 'kubectl version'
run 'kubectl cluster-info'
run 'kubectl get nodes -o wide'

section s9-02-architecture "Session 9: Kubernetes architecture - control plane and node components"
run 'kubectl get pods -n kube-system -o wide'
run 'kubectl describe node minikube | grep -E "Roles|Kubelet Version|Kube-Proxy Version|Container Runtime|OS Image|Architecture"'
run 'kubectl get namespaces'

section s9-03-deploy-explore "Session 9: Basics tutorial - create a Deployment and explore its Pods"
run 'kubectl create deployment hello-kiran --image=nginx:1.24-alpine'
run 'kubectl rollout status deployment/hello-kiran --timeout=120s'
run 'kubectl get deployments'
run 'kubectl get pods -l app=hello-kiran -o wide'
POD=$(kubectl get pods -l app=hello-kiran -o jsonpath='{.items[0].metadata.name}')
run "kubectl exec $POD -- nginx -v"
run "kubectl exec $POD -- cat /etc/os-release | head -2"
run "kubectl logs $POD --tail=3"

section s9-04-expose-scale-update "Session 9: Basics tutorial - expose, scale, update and roll back"
run 'kubectl expose deployment hello-kiran --type=NodePort --port=80'
run 'kubectl get service hello-kiran'
PORT=$(kubectl get service hello-kiran -o jsonpath='{.spec.ports[0].nodePort}')
run "curl -sI http://$IP:$PORT | head -2"
run 'kubectl scale deployment hello-kiran --replicas=4'
run 'kubectl rollout status deployment/hello-kiran --timeout=120s'
run 'kubectl get pods -l app=hello-kiran'
run 'kubectl set image deployment/hello-kiran nginx=nginx:1.25-alpine'
run 'kubectl rollout status deployment/hello-kiran --timeout=180s'
run 'kubectl get deployment hello-kiran -o wide'
run 'kubectl rollout history deployment/hello-kiran'
run 'kubectl rollout undo deployment/hello-kiran'
run 'kubectl rollout status deployment/hello-kiran --timeout=180s'
run 'kubectl get deployment hello-kiran -o wide'
run 'kubectl delete deployment,service hello-kiran'

section s9-05-core-objects "Session 9: Basic objects - Pod, ReplicaSet, Deployment, DaemonSet, StatefulSet"
run 'kubectl apply -f k8s-core-objects/'
run 'kubectl wait --for=condition=Ready pod/mypod --timeout=180s'
run 'kubectl rollout status deployment/myapp --timeout=180s'
run 'kubectl rollout status daemonset/node-exporter --timeout=180s'
run 'kubectl rollout status statefulset/mysql --timeout=420s'
run 'kubectl get pods -o wide'
run 'kubectl get rs,deploy,ds,sts,svc,pvc'
run 'kubectl delete pod $(kubectl get pods -l app=web -o jsonpath="{.items[0].metadata.name}") --wait=false'
run 'sleep 5'
run 'kubectl get pods -l app=web'
run 'kubectl delete -f k8s-core-objects/'
run 'kubectl delete pvc -l app=mysql'

echo "Saved each part to $OUTDIR/"
