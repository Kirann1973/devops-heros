#!/bin/bash
# Session 10 - Task 1: the 4 deployment strategies (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 10" folder, after "minikube start".
# Each strategy is saved to its own file in outputs/ so it fits in one screenshot.

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
# show the pods every 2 seconds while a rollout is happening
watch_pods() { for i in $(seq 1 "$2"); do echo "--- t=$((i*2))s" | tee -a "$OUT"; kubectl get pods -l "$1" -L version --no-headers 2>&1 | tee -a "$OUT"; sleep 2; done; echo | tee -a "$OUT"; }
# send N requests and count which version answered
traffic() { for i in $(seq 1 "$2"); do curl -s "$1" | grep -oE "VERSION: v[0-9]|BLUE ENVIRONMENT|GREEN ENVIRONMENT|STABLE v1|CANARY v2"; done | sort | uniq -c; }

IP=$(minikube ip)
kubectl delete deployment,service -l 'app in (app-rolling,myapp,myapp-canary,app-recreate)' --ignore-not-found >/dev/null 2>&1
kubectl wait --for=delete pod -l 'app in (app-rolling,myapp,myapp-canary,app-recreate)' --timeout=120s >/dev/null 2>&1

# ---------------------------------------------------------------- 1. Rolling update
section s10-01-rolling-update "Strategy 1: Rolling Update (maxSurge 1, maxUnavailable 0)"
run 'kubectl apply -f 01-rolling-update/deployment-v1.yaml -f 01-rolling-update/service.yaml'
run 'kubectl rollout status deployment/app-rolling --timeout=180s'
run 'kubectl get pods -l app=app-rolling -L version'
run "curl -s http://$IP:30010 | grep -oE 'VERSION: v[0-9]|Kiran N - Roll No 10446'"
run 'kubectl apply -f 01-rolling-update/deployment-v2.yaml'
echo "\$ (pods during the update: old and new running side by side)" | tee -a "$OUT"
watch_pods app=app-rolling 8
run 'kubectl rollout status deployment/app-rolling --timeout=180s'
run 'kubectl get pods -l app=app-rolling -L version'
run "curl -s http://$IP:30010 | grep -oE 'VERSION: v[0-9]'"
run 'kubectl rollout history deployment/app-rolling'
run 'kubectl get rs -l app=app-rolling'
run 'kubectl delete -f 01-rolling-update/deployment-v2.yaml -f 01-rolling-update/service.yaml'

# ---------------------------------------------------------------- 2. Blue-green
section s10-02-blue-green "Strategy 2: Blue-Green (switch the Service selector)"
run 'kubectl apply -f 02-blue-green/deployment-blue.yaml -f 02-blue-green/deployment-green.yaml -f 02-blue-green/service-blue.yaml'
run 'kubectl rollout status deployment/app-blue --timeout=180s'
run 'kubectl rollout status deployment/app-green --timeout=180s'
run 'kubectl get pods -l app=myapp -L slot,version'
run 'kubectl get service myapp-service -o jsonpath="{.spec.selector}"; echo'
echo "\$ (10 requests while the Service points to BLUE)" | tee -a "$OUT"
traffic "http://$IP:30020" 10 | tee -a "$OUT"; echo | tee -a "$OUT"
run 'kubectl apply -f 02-blue-green/service-green.yaml'
run 'sleep 5'
run 'kubectl get service myapp-service -o jsonpath="{.spec.selector}"; echo'
echo "\$ (10 requests after switching the Service to GREEN)" | tee -a "$OUT"
traffic "http://$IP:30020" 10 | tee -a "$OUT"; echo | tee -a "$OUT"
run 'kubectl get endpoints myapp-service'
run 'kubectl delete -f 02-blue-green/deployment-blue.yaml -f 02-blue-green/deployment-green.yaml -f 02-blue-green/service-green.yaml'

# ---------------------------------------------------------------- 3. Canary
section s10-03-canary "Strategy 3: Canary (9 stable + 1 canary = about 10% traffic)"
run 'kubectl apply -f 03-canary/'
run 'kubectl rollout status deployment/app-stable --timeout=180s'
run 'kubectl rollout status deployment/app-canary --timeout=180s'
run 'kubectl get deployments -l app=myapp-canary -L track'
run 'kubectl get pods -l app=myapp-canary -L track,version'
echo "\$ (100 requests to the canary Service)" | tee -a "$OUT"
traffic "http://$IP:30030" 100 | tee -a "$OUT"; echo | tee -a "$OUT"
run 'kubectl delete -f 03-canary/'

# ---------------------------------------------------------------- 4. Recreate
section s10-04-recreate "Strategy 4: Recreate (all old pods stop before new pods start)"
run 'kubectl apply -f 04-recreate/deployment-v1.yaml -f 04-recreate/service.yaml'
run 'kubectl rollout status deployment/app-recreate --timeout=180s'
run 'sleep 5'
run 'kubectl get pods -l app=app-recreate -L version'
run "curl -s http://$IP:30040 | grep -oE 'VERSION: v[0-9]'"
run 'kubectl apply -f 04-recreate/deployment-v2.yaml'
echo "\$ (pods during the update: v1 terminates first, then v2 is created)" | tee -a "$OUT"
watch_pods app=app-recreate 8
run 'kubectl rollout status deployment/app-recreate --timeout=180s'
run 'kubectl get pods -l app=app-recreate -L version'
run 'sleep 3'
run "curl -s http://$IP:30040 | grep -oE 'VERSION: v[0-9]'"
run 'kubectl describe deployment app-recreate | grep -E "StrategyType|Scaled"'
run 'kubectl delete -f 04-recreate/deployment-v2.yaml -f 04-recreate/service.yaml'

echo "Saved each strategy to $OUTDIR/"
