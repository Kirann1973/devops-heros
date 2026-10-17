#!/bin/bash
# Session 13 - Storage (volumes, PV/PVC, StorageClass), HPA, probes and the mini project (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 13-storage-hpa-probes" folder, after "minikube start".
# Each part is saved to its own file in outputs/.
#   bash session13_lab.sh        -> all parts (about 25 minutes, the HPA parts wait for scaling)
#   bash session13_lab.sh 4 6    -> only parts 4 and 6

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }

cleanup() {
  kubectl delete pod emptydir-demo emptydir-shared hostpath-demo storage-demo static-pv-demo \
    liveness-demo readiness-demo startup-demo startup-slow-demo load-generator --ignore-not-found --grace-period=1 >/dev/null 2>&1
  kubectl delete svc readiness-demo --ignore-not-found >/dev/null 2>&1
  kubectl delete -f hpa/hpa-backend.yaml -f hpa/backend-service.yaml -f hpa/backend-deployment.yaml --ignore-not-found >/dev/null 2>&1
  kubectl delete pvc student-pvc student-static-pvc dynamic-pvc --ignore-not-found >/dev/null 2>&1
  kubectl delete pv student-pv --ignore-not-found >/dev/null 2>&1
  kubectl delete namespace production-webapp --ignore-not-found >/dev/null 2>&1
  minikube ssh -- sudo rm -rf /tmp/hostpath-data /tmp/student-data >/dev/null 2>&1
}

# wait until the metrics API answers (kubectl top needs it)
wait_metrics() {
  for i in $(seq 1 40); do kubectl top nodes >/dev/null 2>&1 && return; sleep 5; done
}

# print one line every $3 seconds: time | CPU now/target | replicas, until replicas reach $4 or $5 checks pass
# usage: hpa_timeline <namespace> <hpa name> <seconds> <stop at replicas> <max checks> <up|down>
hpa_timeline() {
  local ns=$1 hpa=$2 every=$3 stop=$4 max=$5 dir=$6 start cur tgt rep des first="" last="" same=0
  start=$(date +%s)
  for i in $(seq 1 "$max"); do
    cur=$(kubectl get hpa "$hpa" -n "$ns" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')
    tgt=$(kubectl get hpa "$hpa" -n "$ns" -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}')
    rep=$(kubectl get hpa "$hpa" -n "$ns" -o jsonpath='{.status.currentReplicas}')
    des=$(kubectl get hpa "$hpa" -n "$ns" -o jsonpath='{.status.desiredReplicas}')
    say "$(printf '+%4ss  cpu %5s / %s%%  replicas %2s  (desired %s)' "$(( $(date +%s) - start ))" "${cur:-?}%" "$tgt" "$rep" "$des")"
    if [ "$dir" = up ] && [ "${rep:-0}" -ge "$stop" ]; then break; fi
    if [ "$dir" = down ] && [ "${rep:-99}" -le "$stop" ]; then break; fi
    # stop early once the replica count has scaled and then stayed the same for 8 checks
    first=${first:-$rep}; if [ "$rep" = "$last" ]; then same=$((same+1)); else same=0; fi; last=$rep
    if [ "$dir" = up ] && [ "$rep" != "$first" ] && [ "$same" -ge 8 ]; then break; fi
    sleep "$every"
  done
  echo | tee -a "$OUT"
}

# ---------------------------------------------------------------- 1. emptyDir and hostPath
part1() {
section s13-01-volumes "Task 1: Volumes - emptyDir (lives with the Pod) and hostPath (lives on the node)"
note 'emptyDir: write a file, delete the Pod, create it again'
run 'kubectl apply -f 01-volumes/emptydir-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=120s'
run "kubectl exec emptydir-demo -- sh -c 'echo \"Kiran N - Roll No 10446\" > /data/kiran.txt; ls -l /data; cat /data/kiran.txt'"
note 'restarting the container keeps emptyDir data, deleting the Pod does not'
run 'kubectl delete pod emptydir-demo --grace-period=1'
run 'kubectl apply -f 01-volumes/emptydir-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=120s'
run "kubectl exec emptydir-demo -- sh -c 'ls -l /data; cat /data/kiran.txt'"
note 'emptyDir shared by two containers in the same Pod'
run 'kubectl apply -f 01-volumes/emptydir-shared.yaml'
run 'kubectl wait --for=condition=Ready pod/emptydir-shared --timeout=120s'
sleep 11
run 'kubectl get pod emptydir-shared'
run 'kubectl exec emptydir-shared -c web -- curl -s localhost'
note 'hostPath: same test, the file is on the minikube node in /tmp/hostpath-data'
run 'kubectl apply -f 01-volumes/hostpath-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=120s'
run "kubectl exec hostpath-demo -- sh -c 'echo \"Kiran N - Roll No 10446 (hostPath)\" > /data/kiran.txt; cat /data/kiran.txt'"
run 'kubectl delete pod hostpath-demo --grace-period=1'
run 'kubectl apply -f 01-volumes/hostpath-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=120s'
run 'kubectl exec hostpath-demo -- cat /data/kiran.txt'
run 'kubectl get pod hostpath-demo -o wide'
run 'minikube ssh -- ls -l /tmp/hostpath-data'
run 'kubectl delete pod emptydir-demo emptydir-shared hostpath-demo --grace-period=1'
}

# ---------------------------------------------------------------- 2. PV and PVC
part2() {
section s13-02-pv-pvc "Task 1: PersistentVolume and PersistentVolumeClaim"
run 'kubectl apply -f 02-persistent-storage/pv.yaml -f 02-persistent-storage/pvc.yaml'
sleep 5
run 'kubectl get pv,pvc'
run 'kubectl get pvc student-pvc -o jsonpath="storageClassName={.spec.storageClassName}  volumeName={.spec.volumeName}"; echo'
note 'data written through the PVC survives deleting the Pod'
run 'kubectl apply -f 02-persistent-storage/pod.yaml'
run 'kubectl wait --for=condition=Ready pod/storage-demo --timeout=120s'
run "kubectl exec storage-demo -- sh -c 'echo \"Kiran N - Roll No 10446 (PVC)\" > /data/kiran.txt; cat /data/kiran.txt'"
run 'kubectl delete pod storage-demo --grace-period=1'
run 'kubectl apply -f 02-persistent-storage/pod.yaml'
run 'kubectl wait --for=condition=Ready pod/storage-demo --timeout=120s'
run 'kubectl exec storage-demo -- cat /data/kiran.txt'
note 'static binding: a claim with storageClassName "" binds to the hand-made PV student-pv'
run 'kubectl apply -f 02-persistent-storage/static-pvc.yaml'
sleep 5
run 'kubectl get pv student-pv'
run 'kubectl get pvc student-static-pvc'
run 'kubectl apply -f 02-persistent-storage/static-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/static-pv-demo --timeout=120s'
run "kubectl exec static-pv-demo -- sh -c 'echo \"Kiran N - Roll No 10446 (static PV)\" > /data/kiran.txt'"
run 'minikube ssh -- cat /tmp/student-data/kiran.txt'
note 'reclaim policy Retain: deleting the claim keeps the PV and its data (status Released)'
run 'kubectl delete pod static-pv-demo storage-demo --grace-period=1'
run 'kubectl delete pvc student-static-pvc'
sleep 3
run 'kubectl get pv student-pv'
run 'minikube ssh -- cat /tmp/student-data/kiran.txt'
run 'kubectl delete pvc student-pvc'
run 'kubectl delete pv student-pv'
}

# ---------------------------------------------------------------- 3. StorageClass
part3() {
section s13-03-storageclass "Task 1: StorageClass and dynamic provisioning"
run 'kubectl get storageclass'
run 'kubectl describe storageclass standard | grep -E "^Name|IsDefaultClass|Provisioner|ReclaimPolicy|VolumeBindingMode"'
note 'before: no PV exists'
run 'kubectl get pv'
run 'kubectl apply -f 03-storageclass/pvc.yaml'
run 'kubectl wait --for=jsonpath="{.status.phase}"=Bound pvc/dynamic-pvc --timeout=60s'
run 'kubectl get pvc dynamic-pvc'
note 'after: the provisioner created a PV by itself'
run 'kubectl get pv'
run 'kubectl get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.name,CLASS:.spec.storageClassName,RECLAIM:.spec.persistentVolumeReclaimPolicy,PATH-ON-NODE:.spec.hostPath.path'
note 'reclaim policy Delete: deleting the claim deletes the PV too'
run 'kubectl delete pvc dynamic-pvc'
sleep 5
run 'kubectl get pv'
}

# ---------------------------------------------------------------- 4. HPA
part4() {
section s13-04-hpa "Task 2: HPA - deploy, configure, load, watch it scale up and down"
run 'minikube addons enable metrics-server'
wait_metrics
run 'kubectl top nodes'
run 'kubectl apply -f hpa/backend-deployment.yaml -f hpa/backend-service.yaml'
run 'kubectl rollout status deployment/yatri-backend --timeout=180s'
run 'kubectl apply -f hpa/hpa-backend.yaml'
for i in $(seq 1 30); do
  [ -n "$(kubectl get hpa yatri-backend-hpa -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')" ] && break; sleep 5
done
run 'kubectl get hpa'
run 'kubectl get pods -l app=yatri-backend'
run 'kubectl top pods -l app=yatri-backend'
run 'kubectl exec deploy/yatri-backend -- wget -qO- http://yatri-backend-service/'
note 'start the load generator (10 parallel loops inside the cluster)'
run 'kubectl apply -f hpa/load-generator.yaml'
run 'kubectl wait --for=condition=Ready pod/load-generator --timeout=120s'
run 'kubectl logs load-generator'
note 'scale up, checked every 15 seconds'
hpa_timeline default yatri-backend-hpa 15 10 24 up
sleep 20
run 'kubectl get hpa'
run 'kubectl top pods -l app=yatri-backend'
run 'kubectl get pods -l app=yatri-backend -o wide'
run 'kubectl describe hpa yatri-backend-hpa | grep -A12 "^Metrics"'
note 'stop the load'
run 'kubectl delete -f hpa/load-generator.yaml --grace-period=1'
note 'scale down, checked every 30 seconds (the HPA waits 5 minutes before removing pods)'
hpa_timeline default yatri-backend-hpa 30 2 16 down
run 'kubectl get hpa'
run 'kubectl get pods -l app=yatri-backend'
run 'kubectl describe hpa yatri-backend-hpa | grep -A30 "^Events"'
run 'kubectl delete -f hpa/hpa-backend.yaml -f hpa/backend-service.yaml -f hpa/backend-deployment.yaml'
}

# ---------------------------------------------------------------- 5. Probes
part5() {
section s13-05-probes "Probes - liveness restarts, readiness removes from the Service, startup protects slow apps"
note 'LIVENESS: break the page, the kubelet restarts the container'
run 'kubectl apply -f 05-probes/liveness.yaml'
run 'kubectl wait --for=condition=Ready pod/liveness-demo --timeout=120s'
run 'kubectl describe pod liveness-demo | grep -E "Liveness"'
run 'kubectl exec liveness-demo -- rm /usr/share/nginx/html/index.html'
run 'kubectl exec liveness-demo -- curl -s -o /dev/null -w "GET / -> HTTP %{http_code}\n" localhost'
for i in $(seq 1 30); do
  [ "$(kubectl get pod liveness-demo -o jsonpath='{.status.containerStatuses[0].restartCount}')" -ge 1 ] 2>/dev/null && break; sleep 2
done
kubectl wait --for=condition=Ready pod/liveness-demo --timeout=60s >/dev/null 2>&1
run 'kubectl get pod liveness-demo'
run 'kubectl describe pod liveness-demo | grep -A30 "^Events" | grep -E "Unhealthy|Killing|Pulled|Started" '
note 'the new container starts from the image again, so index.html is back'
run 'kubectl exec liveness-demo -- curl -s -o /dev/null -w "GET / -> HTTP %{http_code}\n" localhost'

note 'READINESS: break the page, the Pod keeps running but leaves the Service'
run 'kubectl apply -f 05-probes/readiness.yaml'
run 'kubectl wait --for=condition=Ready pod/readiness-demo --timeout=120s'
run "kubectl exec readiness-demo -- sh -c 'echo \"Kiran N - Roll No 10446 | readiness-demo\" > /usr/share/nginx/html/index.html'"
run 'kubectl expose pod readiness-demo --port=80'
sleep 3
run 'kubectl get endpoints readiness-demo'
run 'kubectl exec liveness-demo -- curl -s http://readiness-demo'
run 'kubectl exec readiness-demo -- rm /usr/share/nginx/html/index.html'
kubectl wait --for=condition=Ready=false pod/readiness-demo --timeout=60s >/dev/null 2>&1
sleep 2
run 'kubectl get pod readiness-demo'
run 'kubectl get endpoints readiness-demo'
run 'kubectl exec liveness-demo -- curl -s -m 3 http://readiness-demo || echo "curl failed: no ready pod behind the Service"'
run 'kubectl describe pod readiness-demo | grep -A30 "^Events" | grep Unhealthy'
note 'fix the page: the Pod becomes Ready again without any restart'
run "kubectl exec readiness-demo -- sh -c 'echo \"Kiran N - Roll No 10446 | readiness-demo (fixed)\" > /usr/share/nginx/html/index.html'"
kubectl wait --for=condition=Ready pod/readiness-demo --timeout=60s >/dev/null 2>&1
sleep 2
run 'kubectl get pod readiness-demo'
run 'kubectl get endpoints readiness-demo'
run 'kubectl exec liveness-demo -- curl -s http://readiness-demo'

note 'STARTUP: an app that needs 20 seconds to start'
run 'kubectl apply -f 05-probes/startup.yaml'
run 'kubectl wait --for=condition=Ready pod/startup-demo --timeout=120s'
run 'kubectl describe pod startup-demo | grep -E "Startup|Liveness|Readiness"'
run 'kubectl apply -f 05-probes/startup-slow.yaml'
for i in $(seq 1 20); do
  say "$(printf '+%3ss  ' $((i*4-4)))$(kubectl get pod startup-slow-demo --no-headers 2>/dev/null)"
  [ "$(kubectl get pod startup-slow-demo -o jsonpath='{.status.containerStatuses[0].ready}')" = true ] && break
  sleep 4
done
echo | tee -a "$OUT"
run 'kubectl logs startup-slow-demo | head -3'
run 'kubectl describe pod startup-slow-demo | grep -A30 "^Events" | grep -E "Unhealthy|Started"'
run 'kubectl get pod startup-slow-demo'
run 'kubectl delete pod liveness-demo readiness-demo startup-demo startup-slow-demo --grace-period=1'
run 'kubectl delete svc readiness-demo'
}

# ---------------------------------------------------------------- 6. Mini project
part6() {
section s13-06-mini-project "Task 3: Mini project - production web app with PVC, probes and HPA"
NS="-n production-webapp"
run 'minikube addons enable metrics-server'
wait_metrics
run 'kubectl apply -f mini-project/namespace.yaml'
run 'kubectl apply -f mini-project/pvc.yaml -f mini-project/deployment.yaml -f mini-project/service.yaml -f mini-project/hpa.yaml'
run "kubectl rollout status deployment/web-app $NS --timeout=180s"
run "kubectl get pvc,deploy,pods,svc $NS"
run "kubectl get pv | grep -E 'NAME|web-data'"
run "kubectl describe deploy web-app $NS | grep -E 'Liveness|Readiness|Startup|Requests|Limits|cpu|memory|/data'"
note 'storage: write a file, delete ALL pods, read it from a new pod'
POD=$(kubectl get pods $NS -l app=web-app -o jsonpath='{.items[0].metadata.name}')
run "kubectl exec $NS $POD -- sh -c 'echo \"Student: Kiran N - Roll No 10446\" > /data/student.txt; cat /data/student.txt'"
run "kubectl delete pods $NS -l app=web-app --grace-period=1"
sleep 3
run "kubectl rollout status deployment/web-app $NS --timeout=180s"
kubectl wait $NS --for=condition=Ready pod -l app=web-app --timeout=120s >/dev/null 2>&1
run "kubectl get pods $NS -l app=web-app"
NEW=$(kubectl get pods $NS -l app=web-app -o jsonpath='{.items[0].metadata.name}')
run "kubectl exec $NS $NEW -- cat /data/student.txt"
note 'service: reach the app through web-service'
run "kubectl get endpoints web-service $NS"
run "kubectl exec $NS deploy/web-app -- curl -s http://web-service | grep '<title>'"
note 'HPA: generate load and watch it scale (min 2, max 5, target 50% CPU)'
for i in $(seq 1 30); do
  [ -n "$(kubectl get hpa web-app-hpa $NS -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}')" ] && break; sleep 5
done
run "kubectl get hpa $NS"
run "kubectl run load-generator $NS --image=busybox:1.36 --restart=Never -- /bin/sh -c 'for i in \$(seq 1 20); do (while true; do wget -q -O- http://web-service >/dev/null; done) & done; wait'"
hpa_timeline production-webapp web-app-hpa 15 5 20 up
sleep 20
run "kubectl get hpa $NS"
run "kubectl top pods $NS"
run "kubectl get pods $NS -o wide"
run "kubectl describe hpa web-app-hpa $NS | grep -A30 '^Events'"
run "kubectl delete pod load-generator $NS --grace-period=1"
run 'kubectl delete namespace production-webapp'
}

PARTS="${*:-1 2 3 4 5 6}"
[ -z "$*" ] && cleanup
for n in $PARTS; do part$n; done
echo "Done. Outputs saved in $OUTDIR/"
