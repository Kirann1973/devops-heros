#!/bin/bash
# Session 14 - Kubernetes troubleshooting: commands, common failures, triage gauntlet, mini project (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 14-kubernetes-troubleshooting" folder, after "minikube start".
# Each part is saved to its own file in outputs/.
#   bash session14_lab.sh        -> all parts (about 10 minutes)
#   bash session14_lab.sh 2 8    -> only parts 2 and 8

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }

# print the pod's line from "kubectl get pod" every 3 s whenever it changes,
# until STATUS matches $3 or $2 seconds pass.   usage: watch_pod <pod> <seconds> <regex> [namespace]
watch_pod() {
  local pod=$1 max=$2 re=$3 ns=${4:-default} last="" line start
  start=$(date +%s)
  note "watching pod $pod (status every 3 s)"
  while [ $(( $(date +%s) - start )) -le "$max" ]; do
    line=$(kubectl get pod "$pod" -n "$ns" --no-headers 2>&1 | awk '{print $2, $3, $4}')
    [ "$line" != "$last" ] && say "$(printf '+%3ss  %s  %s' $(( $(date +%s) - start )) "$pod" "$line")" && last=$line
    echo "$line" | awk '{print $2}' | grep -Eq "$re" && break
    sleep 3
  done
  echo | tee -a "$OUT"
}

cleanup() {
  kubectl delete pod get-demo describe-demo logs-demo exec-demo events-demo crash-demo image-demo pending-demo \
    mount-demo config-demo dns-test project-broken-pod --ignore-not-found --grace-period=1 >/dev/null 2>&1
  kubectl delete pod -l tier=triage-gauntlet --ignore-not-found --grace-period=1 >/dev/null 2>&1
  kubectl delete configmap app-settings --ignore-not-found >/dev/null 2>&1
  kubectl delete secret db-credentials --ignore-not-found >/dev/null 2>&1
  kubectl delete -f 09-service-dns-troubleshooting/deployment.yaml -f 09-service-dns-troubleshooting/service.yaml \
    -f 09-service-dns-troubleshooting/broken-service.yaml --ignore-not-found >/dev/null 2>&1
  kubectl delete -f mini-project/deployment.yaml -f mini-project/service.yaml --ignore-not-found >/dev/null 2>&1
  kubectl delete namespace production --ignore-not-found >/dev/null 2>&1
}

# ---------------------------------------------------------------- 1. Commands
part1() {
section s14-01-commands "Task 1: the main troubleshooting commands"
run 'kubectl apply -f 01-kubectl-get/pod.yaml -f 03-kubectl-logs/pod.yaml -f 04-kubectl-exec/pod.yaml'
run 'kubectl wait --for=condition=Ready pod/get-demo pod/logs-demo pod/exec-demo --timeout=120s'
note 'kubectl get: what exists and its state'
run 'kubectl get pods'
run 'kubectl get pods -o wide'
run 'kubectl get pods --show-labels'
run 'kubectl get pod get-demo -o jsonpath="{.status.phase} {.status.podIP} {.spec.nodeName}{\"\n\"}"'
run 'kubectl get nodes -o wide'
note 'kubectl describe: details + Events'
run 'kubectl describe pod get-demo | grep -E "^Name:|^Node:|^Status:|^IP:|Image:|State:|Ready:|Restart Count|^Events|Scheduled|Pulled|Created|Started"'
note 'kubectl logs: what the app printed'
run 'kubectl logs logs-demo'
run 'kubectl logs logs-demo --tail=2 --timestamps'
note 'kubectl exec: run commands inside the container'
run 'kubectl exec exec-demo -- hostname'
run 'kubectl exec exec-demo -- curl -s -o /dev/null -w "nginx on localhost -> HTTP %{http_code}\n" localhost'
run 'kubectl exec exec-demo -- cat /etc/resolv.conf'
run "kubectl exec exec-demo -- sh -c 'echo \"exec test by Kiran N - Roll No 10446\" > /tmp/kiran.txt; cat /tmp/kiran.txt'"
note 'kubectl events: what happened in the cluster, oldest first'
run 'kubectl events --for pod/exec-demo'
run 'kubectl get events --sort-by=.lastTimestamp | tail -6'
note 'kubectl explain: built-in documentation of every field'
run 'kubectl explain pod.spec.restartPolicy'
run 'kubectl explain deployment.spec.strategy | head -14'
note 'kubectl top: CPU and memory (needs metrics-server)'
run 'minikube addons enable metrics-server | tail -1'
for i in $(seq 1 40); do kubectl top pod exec-demo >/dev/null 2>&1 && break; sleep 5; done
run 'kubectl top nodes'
run 'kubectl top pods'
run 'kubectl delete pod get-demo logs-demo exec-demo --grace-period=1'
}

# ---------------------------------------------------------------- 2. CrashLoopBackOff
part2() {
section s14-02-crashloopbackoff "Task 2: CrashLoopBackOff"
note 'IDENTIFY'
run 'kubectl apply -f 06-crashloopbackoff/broken-pod.yaml'
watch_pod crash-demo 90 'CrashLoopBackOff'
run 'kubectl get pod crash-demo'
note 'INVESTIGATE: logs of the current and of the previous (crashed) container'
run 'kubectl logs crash-demo'
run 'kubectl logs crash-demo --previous'
run 'kubectl describe pod crash-demo | grep -E -A4 "State:|Last State:" | grep -E "State|Reason|Exit Code"'
run 'kubectl describe pod crash-demo | grep -E "Restart Count|BackOff"'
note 'ROOT CAUSE: the command ends with "exit 1", the container exits with an error, kubelet restarts it with a growing delay'
note 'FIX: the command cannot be changed on a running Pod, so delete and apply the fixed Pod'
run 'kubectl delete pod crash-demo --grace-period=1'
run 'kubectl apply -f 06-crashloopbackoff/fixed-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/crash-demo --timeout=60s'
note 'VERIFY'
run 'kubectl get pod crash-demo'
run 'kubectl logs crash-demo'
run 'kubectl delete pod crash-demo --grace-period=1'
}

# ---------------------------------------------------------------- 3. ErrImagePull / ImagePullBackOff
part3() {
section s14-03-imagepullbackoff "Task 2: ErrImagePull and ImagePullBackOff"
note 'IDENTIFY: ErrImagePull is the failed pull, ImagePullBackOff is kubelet waiting before it tries again'
run 'kubectl apply -f 07-imagepullbackoff/broken-pod.yaml'
watch_pod image-demo 60 'ImagePullBackOff'
note 'INVESTIGATE'
run 'kubectl get pod image-demo -o jsonpath="image: {.spec.containers[0].image}{\"\n\"}waiting: {.status.containerStatuses[0].state.waiting.reason}{\"\n\"}"'
run 'kubectl describe pod image-demo | grep -A12 "^Events" | grep -E "Pulling|Failed|BackOff"'
note 'ROOT CAUSE: the tag nginx:this-image-does-not-exist is not in Docker Hub'
note 'FIX: the image is one of the few fields that can be changed on a running Pod'
run 'kubectl apply -f 07-imagepullbackoff/fixed-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/image-demo --timeout=120s'
note 'VERIFY'
run 'kubectl get pod image-demo'
run 'kubectl describe pod image-demo | grep -A15 "^Events" | grep -E "Killing|Pulled|Started" | tail -3'
run 'kubectl delete pod image-demo --grace-period=1'
}

# ---------------------------------------------------------------- 4. Pending
part4() {
section s14-04-pending "Task 2: Pending"
note 'IDENTIFY'
run 'kubectl apply -f 08-pending-pods/broken-pod.yaml'
sleep 5
run 'kubectl get pod pending-demo -o wide'
note 'INVESTIGATE: the scheduler explains in the Events why no node fits'
run 'kubectl describe pod pending-demo | grep -A3 "^Node-Selectors"'
run 'kubectl describe pod pending-demo | grep -A8 "^Events" | grep FailedScheduling'
run 'kubectl get nodes -L kubernetes.io/hostname'
note 'ROOT CAUSE: nodeSelector kubernetes.io/hostname=node-that-does-not-exist matches no node'
note 'FIX: nodeSelector cannot be changed on an existing Pod, so delete and apply the fixed Pod'
run 'kubectl delete pod pending-demo --grace-period=1'
run 'kubectl apply -f 08-pending-pods/fixed-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/pending-demo --timeout=120s'
note 'VERIFY'
run 'kubectl get pod pending-demo -o wide'
run 'kubectl delete pod pending-demo --grace-period=1'
}

# ---------------------------------------------------------------- 5. ContainerCreating and configuration issues
part5() {
section s14-05-config-issues "Task 2: ContainerCreating (missing ConfigMap) and configuration issues (missing Secret)"
note 'A) ContainerCreating: the volume cannot be mounted'
run 'kubectl apply -f 10-config-issues/containercreating-pod.yaml'
sleep 15
run 'kubectl get pod mount-demo'
run 'kubectl describe pod mount-demo | grep -A10 "^Events" | grep FailedMount'
run 'kubectl get configmap app-settings'
note 'ROOT CAUSE: ConfigMap app-settings does not exist. FIX: create it, the kubelet retries the mount by itself'
run 'kubectl create configmap app-settings --from-literal=GREETING="Hello from Kiran N - Roll No 10446"'
run 'kubectl wait --for=condition=Ready pod/mount-demo --timeout=180s'
run 'kubectl get pod mount-demo'
run 'kubectl logs mount-demo'

note 'B) CreateContainerConfigError: env var from a Secret that does not exist'
run 'kubectl apply -f 10-config-issues/config-error-pod.yaml'
watch_pod config-demo 60 'CreateContainerConfigError'
run 'kubectl describe pod config-demo | grep -A10 "^Events" | grep -E "Failed|Warning"'
note 'ROOT CAUSE: Secret db-credentials is missing. FIX: create it, the kubelet retries'
run 'kubectl create secret generic db-credentials --from-literal=DB_PASSWORD=secretpassword'
run 'kubectl wait --for=condition=Ready pod/config-demo --timeout=120s'
run 'kubectl get pod config-demo'
run 'kubectl logs config-demo'
run 'kubectl delete pod mount-demo config-demo --grace-period=1'
run 'kubectl delete configmap app-settings'
run 'kubectl delete secret db-credentials'
}

# ---------------------------------------------------------------- 6. Service connectivity
part6() {
section s14-06-service "Task 2: Service connectivity - wrong selector and wrong targetPort"
run 'kubectl apply -f 09-service-dns-troubleshooting/deployment.yaml -f 09-service-dns-troubleshooting/service.yaml'
run 'kubectl rollout status deployment/web --timeout=120s'
note 'IDENTIFY: the pods run, but the Service does not answer'
run 'kubectl get pods -l app=web -o wide'
run 'kubectl get svc web-service'
run 'kubectl exec deploy/web -- curl -s -m 3 http://web-service || echo "curl failed (exit $?)"'
note 'INVESTIGATE: a Service sends traffic only to Pods whose labels match its selector'
run 'kubectl get endpoints web-service'
run 'kubectl describe svc web-service | grep -E "^Selector|^TargetPort|^Endpoints"'
run 'kubectl get pods --show-labels -l app=web'
run 'kubectl get pods -l app=web-ahsgdf'
note 'ROOT CAUSE: selector app=web-ahsgdf, pod label app=web'
note 'FIX'
run "kubectl patch svc web-service -p '{\"spec\":{\"selector\":{\"app\":\"web\"}}}'"
sleep 5
note 'VERIFY'
run 'kubectl get endpoints web-service'
run 'kubectl exec deploy/web -- curl -s -m 3 http://web-service | grep "<title>"'

note 'SECOND PROBLEM: targetPort points to a port nginx does not listen on'
run "kubectl patch svc web-service -p '{\"spec\":{\"ports\":[{\"port\":80,\"targetPort\":8080}]}}'"
sleep 5
run 'kubectl get endpoints web-service'
run 'kubectl exec deploy/web -- curl -s -m 3 http://web-service || echo "curl failed (exit $?)"'
run 'kubectl get pod -l app=web -o jsonpath="{.items[0].spec.containers[0].ports[0].containerPort}{\"\n\"}"'
note 'ROOT CAUSE: endpoints exist, but they point to :8080 and nginx listens on :80. FIX: targetPort 80'
run "kubectl patch svc web-service -p '{\"spec\":{\"ports\":[{\"port\":80,\"targetPort\":80}]}}'"
sleep 5
run 'kubectl get endpoints web-service'
run 'kubectl exec deploy/web -- curl -s -m 3 http://web-service | grep "<title>"'

note 'instructor broken-service.yaml: same kind of problem'
run 'kubectl apply -f 09-service-dns-troubleshooting/broken-service.yaml'
run 'kubectl get endpoints broken-service'
run 'kubectl get pods -l app=does-not-exist'
run 'kubectl delete -f 09-service-dns-troubleshooting/broken-service.yaml'
}

# ---------------------------------------------------------------- 7. DNS and Pod networking
part7() {
section s14-07-dns-networking "Task 2: DNS issues and Pod networking"
run 'kubectl apply -f 09-service-dns-troubleshooting/deployment.yaml -f 09-service-dns-troubleshooting/dns-test-pod.yaml'
run 'kubectl apply -f 09-service-dns-troubleshooting/service.yaml'
note 'with the selector fix from part 6'
run "kubectl patch svc web-service -p '{\"spec\":{\"selector\":{\"app\":\"web\"}}}'"
run 'kubectl wait --for=condition=Ready pod/dns-test --timeout=180s'
note 'DNS: is CoreDNS running?'
run 'kubectl get pods -n kube-system -l k8s-app=kube-dns'
run 'kubectl get svc -n kube-system kube-dns'
run 'kubectl exec dns-test -- cat /etc/resolv.conf'
note 'DNS: names that should resolve'
run 'kubectl exec dns-test -- nslookup kubernetes.default'
run 'kubectl exec dns-test -- nslookup web-service'
run 'kubectl exec dns-test -- dig +short web-service.default.svc.cluster.local'
run 'kubectl get svc web-service -o jsonpath="{.spec.clusterIP}{\"\n\"}"'
note 'DNS issue: a wrong name (typo) -> NXDOMAIN'
run 'kubectl exec dns-test -- nslookup web-servcie'
run 'kubectl exec dns-test -- nslookup web-service.wrong-namespace.svc.cluster.local'
note 'DNS issue: a short name only works inside the same namespace (kube-dns is in kube-system)'
run 'kubectl exec dns-test -- nslookup kube-dns'
run 'kubectl exec dns-test -- nslookup kube-dns.kube-system'
note 'POD NETWORKING: every Pod has its own IP and can reach every other Pod directly'
run 'kubectl get pods -l app=web -o wide'
P1=$(kubectl get pods -l app=web -o jsonpath='{.items[0].metadata.name}')
IP2=$(kubectl get pods -l app=web -o jsonpath='{.items[1].status.podIP}')
run "kubectl exec $P1 -- curl -s -o /dev/null -w \"$P1 -> pod IP $IP2:80 -> HTTP %{http_code}\n\" http://$IP2"
run "kubectl exec $P1 -- curl -s -m 3 http://$IP2:8080 || echo \"curl failed (exit \$?): nothing listens on 8080\""
run "kubectl exec $P1 -- curl -s -o /dev/null -w \"$P1 -> web-service.default.svc.cluster.local -> HTTP %{http_code}\n\" http://web-service.default.svc.cluster.local"
run 'kubectl delete pod dns-test --grace-period=1'
run 'kubectl delete -f 09-service-dns-troubleshooting/deployment.yaml -f 09-service-dns-troubleshooting/service.yaml'
}

# ---------------------------------------------------------------- 8. Triage gauntlet
part8() {
section s14-08-triage-gauntlet "Triage gauntlet: 5 broken pods, diagnose and fix each"
run 'bash scenarios/triage_all.sh'
note 'give the failures time to show (pulls, restarts, back-off)'
sleep 45
run 'kubectl get pods -l tier=triage-gauntlet'

note '--- 1. crashloop'
run 'kubectl logs fail-1-crashloop-pod --previous 2>/dev/null || kubectl logs fail-1-crashloop-pod'
note 'root cause: DATABASE_URL env var missing -> exit 1. fix: add the env var (and keep the app running)'
run 'kubectl delete pod fail-1-crashloop-pod --grace-period=1'
run 'kubectl apply -f scenarios/scenario-1-crashloop/fixed.yaml'

note '--- 2. imagepull'
run 'kubectl describe pod fail-2-imagepull-pod | grep -A12 "^Events" | grep -E "Failed" | head -2'
note 'root cause: image yatri-api-service:v999-invalid-tag-does-not-exist does not exist. fix: a real image'
run 'kubectl apply -f scenarios/scenario-2-imagepull/fixed.yaml'

note '--- 3. pending'
run 'kubectl describe pod fail-3-pending-pod | grep -A6 "^Events" | grep FailedScheduling'
run 'kubectl describe node minikube | grep -A3 "^Allocatable" | grep -E "cpu|memory"'
note 'root cause: requests 500 CPU / 1000Gi, the node has far less. fix: realistic requests'
run 'kubectl delete pod fail-3-pending-pod --grace-period=1'
run 'kubectl apply -f scenarios/scenario-3-pending/fixed.yaml'

note '--- 4. dns-failure (the pod is Running, the failure is hidden)'
run 'kubectl logs fail-4-dns-failure-pod'
run 'kubectl exec fail-4-dns-failure-pod -- curl -sS --connect-timeout 3 http://postgres-db-wrong-name.production.svc.cluster.local:5432 || true'
run 'kubectl exec fail-4-dns-failure-pod -- nslookup postgres-db-wrong-name.production.svc.cluster.local || true'
run 'kubectl get namespace production || true'
note 'root cause: no Service with that name (and no namespace production). fix: deploy the database Service and use its real name'
run 'kubectl apply -f scenarios/scenario-4-dns-failure/postgres-db.yaml'
run 'kubectl rollout status deployment/postgres-db -n production --timeout=180s'
run 'kubectl get svc,endpoints -n production'
run 'kubectl delete pod fail-4-dns-failure-pod --grace-period=1'
run 'kubectl apply -f scenarios/scenario-4-dns-failure/fixed.yaml'

note '--- 5. oomkilled'
run 'kubectl get pod fail-5-oomkilled-pod -o jsonpath="last state: {.status.containerStatuses[0].lastState.terminated.reason}, exit code {.status.containerStatuses[0].lastState.terminated.exitCode}{\"\n\"}"'
run 'kubectl describe pod fail-5-oomkilled-pod | grep -E "Limits|memory:|Reason|Exit Code|Restart Count"'
note 'root cause: the code allocates 100 x 10 MB = 1000 MB with a 20Mi limit. fix: allocate 100 MB, limit 256Mi'
run 'kubectl delete pod fail-5-oomkilled-pod --grace-period=1'
run 'kubectl apply -f scenarios/scenario-5-oomkilled/fixed.yaml'

note 'VERIFY all 5'
run 'kubectl wait --for=condition=Ready pod -l tier=triage-gauntlet --timeout=180s'
sleep 5
run 'kubectl get pods -l tier=triage-gauntlet'
run 'kubectl logs fail-1-crashloop-pod'
run 'kubectl logs fail-4-dns-failure-pod'
run 'kubectl logs fail-5-oomkilled-pod'
run 'kubectl top pod fail-5-oomkilled-pod'
run 'kubectl delete pod -l tier=triage-gauntlet --grace-period=1'
run 'kubectl delete namespace production'
}

# ---------------------------------------------------------------- 9. Mini project
part9() {
section s14-09-mini-project "Task 3: Mini project - troubleshooting challenge"
note '1. deploy the application'
run 'kubectl apply -f mini-project/deployment.yaml -f mini-project/service.yaml'
run 'kubectl rollout status deployment/troubleshooting-app --timeout=120s'
run 'kubectl get pods -l app=troubleshooting-app -o wide'
run 'kubectl get service troubleshooting-service'
note '2. check the application'
P=$(kubectl get pods -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}')
run "kubectl describe pod $P | grep -E '^Status:|^IP:|Image:|Ready:|Restart Count'"
run "kubectl logs $P | tail -3"
run "kubectl exec $P -- curl -s localhost | grep '<title>'"
note '3 and 4. check the Service and its endpoints'
run 'kubectl describe service troubleshooting-service | grep -E "^Selector|^TargetPort|^Endpoints"'
run 'kubectl get endpoints troubleshooting-service'
note '5 and 6. broken pod'
run 'kubectl apply -f mini-project/broken-pod.yaml'
watch_pod project-broken-pod 60 'ImagePullBackOff'
run 'kubectl get pod project-broken-pod'
run 'kubectl describe pod project-broken-pod | grep -A12 "^Events" | grep -E "Pulling|Failed|BackOff"'
run 'kubectl set image pod/project-broken-pod app=nginx:1.27'
run 'kubectl wait --for=condition=Ready pod/project-broken-pod --timeout=120s'
run 'kubectl get pod project-broken-pod'
note '8. break the Service selector'
run "kubectl patch service troubleshooting-service -p '{\"spec\":{\"selector\":{\"app\":\"wrong-app\"}}}'"
sleep 5
run 'kubectl get service troubleshooting-service'
run 'kubectl get endpoints troubleshooting-service'
run "kubectl exec $P -- curl -s -m 3 http://troubleshooting-service || echo \"curl failed (exit \$?)\""
note '9. find the root cause: compare pod labels and Service selector'
run 'kubectl get pods --show-labels -l app=troubleshooting-app'
run 'kubectl describe service troubleshooting-service | grep -E "^Selector|^Endpoints"'
note 'fix: put the selector back'
run 'kubectl apply -f mini-project/service.yaml'
sleep 5
run 'kubectl get endpoints troubleshooting-service'
run "kubectl exec $P -- curl -s http://troubleshooting-service | grep '<title>'"
run "kubectl exec $P -- getent hosts troubleshooting-service"
run 'kubectl delete pod project-broken-pod --grace-period=1'
run 'kubectl delete -f mini-project/deployment.yaml -f mini-project/service.yaml'
}

PARTS="${*:-1 2 3 4 5 6 7 8 9}"
[ -z "$*" ] && cleanup
for n in $PARTS; do part$n; done
echo "Done. Outputs saved in $OUTDIR/"
