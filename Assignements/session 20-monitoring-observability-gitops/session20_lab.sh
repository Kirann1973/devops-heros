#!/bin/bash
# Session 20 - Monitoring, Observability and GitOps
# Kiran N | Roll No: 10446
# Run from inside the "session 20-monitoring-observability-gitops" folder. Each part is saved to its own file in outputs/.
#   Monitoring + observability (Docker Compose: app, Prometheus, Alertmanager, Grafana, Jaeger, node-exporter)
#     bash session20_lab.sh 1 2 3 4   -> tools, start the stack, metrics, logs + traces (screenshot the UIs now)
#     bash session20_lab.sh 5         -> make alerts fire (screenshot Prometheus / Alertmanager / Grafana now)
#     bash session20_lab.sh 6 7       -> fix the problem, alerts resolve, stop the stack
#   GitOps (Minikube + Argo CD, watching my GitHub repo)
#     bash session20_lab.sh 8 9       -> install Argo CD, create the Application, 2 replicas from Git
#     (the replicas: 2 -> 3 commit is pushed to Git)
#     bash session20_lab.sh 10 11     -> Argo CD rolls out the Git change, then self-heals a manual change
#     bash session20_lab.sh 12        -> clean up

OUTDIR="$PWD/outputs"
MON="$PWD/09-monitoring-observability-demo"
GITOPS="$PWD/10-gitops-argocd-demo"
mkdir -p "$OUTDIR"
set -o pipefail
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }
dc() { docker compose -f "$MON/docker-compose.yml" "$@"; }
vm_ip() { hostname -I | awk '{print $1}'; }

H="python3 lab_helpers.py"        # prints the JSON APIs of Prometheus, Alertmanager and Jaeger as short tables
pq() { curl -s --get localhost:9090/api/v1/query --data-urlencode "query=$1" | $H query; }   # PromQL query
alerts() { curl -s localhost:9090/api/v1/alerts | $H alerts; }
showtrace() { curl -s "localhost:16686/api/traces/$1" | $H trace; }
wait_alert() {  # wait_alert <name> <state> <max seconds>
  local i
  for i in $(seq 1 "$3"); do curl -s localhost:9090/api/v1/alerts | $H has_alert "$1" "$2" && return 0; sleep 1; done
  return 1
}
# send requests to the app for <seconds> with a mix of normal pages, errors or CPU-heavy work
traffic() {  # traffic <seconds> <mix: normal|errors|cpu>
  local end=$((SECONDS + $1))
  while [ $SECONDS -lt $end ]; do
    case $2 in
      normal) curl -s -o /dev/null localhost:8000/; curl -s -o /dev/null localhost:8000/
              [ $((RANDOM % 5)) = 0 ] && curl -s -o /dev/null localhost:8000/slow
              [ $((RANDOM % 8)) = 0 ] && curl -s -o /dev/null localhost:8000/error ;;
      errors) curl -s -o /dev/null localhost:8000/error; curl -s -o /dev/null localhost:8000/ ;;
      cpu)    curl -s -o /dev/null localhost:8000/work ;;
    esac
    sleep 0.2
  done
}

# ---------------------------------------------------------------- 1. Tools
part1() {
section s20-01-setup "Tools, VM size, free disk"
run "docker --version; docker compose version"
run "nproc; free -h | head -2"
run "df -h / | tail -1"
run "echo VM IP: \$(hostname -I | awk '{print \$1}')"
}

# ---------------------------------------------------------------- 2. Start the monitoring stack
part2() {
section s20-02-stack "Start the stack: app + Prometheus + Alertmanager + Grafana + Jaeger + node-exporter"
note 'first run downloads the images (about 1 GB)'
dc pull -q > /dev/null 2>&1
run "dc up -d 2>&1 | grep -E 'Started|Running|Error' | sort"
for i in $(seq 1 60); do curl -sf localhost:9090/-/ready >/dev/null && curl -sf localhost:8000/health >/dev/null && curl -sf localhost:3000/api/health >/dev/null && break; sleep 2; done
sleep 10
run "dc ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | sed 's/0.0.0.0://g; s/, \[::\]:[0-9]*->[0-9]*\/tcp//g'"
note 'application health check'
run "curl -s localhost:8000/health; echo"
note 'Prometheus scrape targets (health = up means the metrics are being collected)'
run "curl -s localhost:9090/api/v1/targets | $H targets"
note 'Grafana: data sources and dashboard created from files (provisioning)'
run "curl -s -u admin:session20 localhost:3000/api/datasources | python3 -c 'import json,sys; [print(\"  datasource:\", d[\"name\"], d[\"type\"], d[\"url\"]) for d in json.load(sys.stdin)]'"
run "curl -s -u admin:session20 'localhost:3000/api/search?type=dash-db' | python3 -c 'import json,sys; [print(\"  dashboard:\", d[\"title\"], \"->\", d[\"url\"]) for d in json.load(sys.stdin)]'"
say "Open from your Mac:  Grafana http://$(vm_ip):3000   Prometheus http://$(vm_ip):9090   Jaeger http://$(vm_ip):16686   App http://$(vm_ip):8000"
}

# ---------------------------------------------------------------- 3. Metrics
part3() {
section s20-03-metrics "Metrics: requests, errors, latency, CPU, memory (PromQL)"
note 'sending 60 seconds of traffic: normal pages, some slow requests, some errors'
traffic 60 normal
sleep 5
note 'raw metrics the app exposes on /metrics (Prometheus text format)'
run "curl -s localhost:8000/metrics | grep -E '^(app_info|http_requests_total|process_)' | head -12"
note 'PromQL: is the app up? (1 = up)'
run "pq 'up{job=\"kiran-app\"}'"
note 'PromQL: requests per second by path and status'
run "pq 'sum by (path, status) (rate(http_requests_total{job=\"kiran-app\",path!=\"/metrics\",path!=\"/health\"}[1m]))'"
note 'PromQL: error rate (share of requests with status 5xx)'
run "pq 'sum(rate(http_requests_total{job=\"kiran-app\",status=~\"5..\"}[1m])) / sum(rate(http_requests_total{job=\"kiran-app\"}[1m]))'"
note 'PromQL: latency p50 and p95 in seconds (from the histogram)'
run "pq 'histogram_quantile(0.5, sum by (le) (rate(http_request_duration_seconds_bucket{job=\"kiran-app\"}[1m])))'"
run "pq 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job=\"kiran-app\"}[1m])))'"
note 'PromQL: app CPU (cores) and memory (MB)'
run "pq 'rate(process_cpu_seconds_total{job=\"kiran-app\"}[1m])'"
run "pq 'process_resident_memory_bytes{job=\"kiran-app\"} / 1e6'"
note 'PromQL: VM CPU % and memory % (node-exporter)'
run "pq '100 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[1m])) * 100'"
run "pq '(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100'"
note 'per-container CPU and memory, straight from Docker'
run "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' | sed 's/session20-//; s/-1 / /'"
}

# ---------------------------------------------------------------- 4. Logs and traces
part4() {
section s20-04-logs-traces "Logs (JSON, with trace id) and traces (Jaeger)"
note 'a few more requests, so the newest logs and traces are easy to find'
for p in / /slow /error /; do curl -s -o /dev/null "localhost:8000$p"; done
sleep 3
note 'logs: one JSON line per request (docker compose logs = kubectl logs for containers)'
run "dc logs app --no-log-prefix --tail 6"
note 'logs: only the errors'
run "dc logs app --no-log-prefix | grep '\"level\": \"error\"' | tail -3"
note 'traces: services Jaeger has received spans from'
run "curl -s localhost:16686/api/services | $H services"
note 'traces: the trace id from the last error log line, looked up in Jaeger (logs -> traces)'
TID=$(dc logs app --no-log-prefix | grep '"level": "error"' | $H trace_id)
run "echo trace_id=$TID"
run "showtrace $TID"
note 'traces: the slowest recent request - the child span shows where the time went'
SID=$(curl -s "localhost:16686/api/traces?service=kiran-app&operation=GET%20/slow&limit=20&lookback=1h" | $H slowest)
run "showtrace $SID"
say "Now screenshot: Grafana dashboard (http://$(vm_ip):3000), Prometheus > Status > Targets (http://$(vm_ip):9090/targets),"
say "Jaeger: search service kiran-app and open a /slow and an /error trace (http://$(vm_ip):16686)."
}

# ---------------------------------------------------------------- 5. Alerts
part5() {
section s20-05-alerts "Alerts: rules, then make them fire"
note 'the alert rules Prometheus evaluates every 5 seconds'
run "curl -s localhost:9090/api/v1/rules | $H rules"
note 'before: no alerts'
run alerts
note 'problem 1: CPU load on the app (/work) and many failing requests (/error), for about 70 seconds'
traffic 75 cpu & traffic 75 cpu & traffic 75 errors & wait
run alerts
note 'problem 2: the app crashes (container stopped)'
run "dc stop app 2>&1 | tail -1"
wait_alert AppDown firing 60
sleep 8
run alerts
note 'Alertmanager received them (API v2)'
run "curl -s localhost:9093/api/v2/alerts | $H am_alerts"
note 'the notifications Alertmanager sent to the webhook (stands in for Slack / e-mail)'
run "dc logs alert-receiver --no-log-prefix | grep FIRING"
say "Now screenshot: Prometheus Alerts page (http://$(vm_ip):9090/alerts), Alertmanager (http://$(vm_ip):9093),"
say "and the Grafana dashboard (app DOWN, firing alerts). Then run: bash session20_lab.sh 6 7"
}

# ---------------------------------------------------------------- 6. Recover
part6() {
section s20-06-resolved "Fix: start the app again, alerts resolve"
run "dc start app 2>&1 | tail -1"
for i in $(seq 1 30); do curl -sf localhost:8000/health >/dev/null && break; sleep 2; done
run "curl -s localhost:8000/health; echo"
note 'normal traffic again, then wait until Prometheus has no firing alerts'
traffic 20 normal
for i in $(seq 1 90); do alerts | grep -q firing || break; sleep 2; done
sleep 15
run alerts
run "pq 'up{job=\"kiran-app\"}'"
note 'Alertmanager also sent RESOLVED notifications (send_resolved: true)'
run "dc logs alert-receiver --no-log-prefix | tail -8"
}

# ---------------------------------------------------------------- 7. Stop the stack
part7() {
section s20-07-stop "Stop the monitoring stack"
run "dc down 2>&1 | grep -E 'Removed' | sort"
run "dc ps | tail -n +2 | wc -l"
}

# ---------------------------------------------------------------- 8. Cluster + Argo CD
part8() {
section s20-08-argocd-install "Cluster and Argo CD installation"
if ! kubectl get nodes >/dev/null 2>&1; then
  note 'starting Minikube (same settings as earlier sessions)'
  minikube start --driver=docker --cpus=2 --memory=3500 > "$OUTDIR/minikube-start.log" 2>&1 || { say "minikube start failed:"; tail -5 "$OUTDIR/minikube-start.log" | tee -a "$OUT"; }
fi
run "kubectl get nodes -o wide | cut -c1-110"
run "kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -"
note 'install Argo CD (stable manifests from the Argo CD project)'
run "kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>&1 | tail -4"
note 'waiting for every Argo CD component (first time downloads the images)'
kubectl -n argocd rollout status deploy --timeout=600s > /dev/null 2>&1
kubectl -n argocd rollout status statefulset argocd-application-controller --timeout=300s > /dev/null 2>&1
run "kubectl get pods -n argocd"
run "kubectl -n argocd get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}'; echo"
}

# ---------------------------------------------------------------- 9. Application from Git
part9() {
section s20-09-application "Argo CD Application: Git -> Kubernetes"
run "cat '$GITOPS/argocd-application.yaml' | grep -vE '^#'"
note 'the manifests Argo CD reads from Git'
run "ls -1 '$GITOPS/app'"
run "grep -E 'replicas|image' '$GITOPS/app/deployment.yaml'"
note 'only the Application is applied by hand. The Deployment, Service and ConfigMap come from Git.'
run "kubectl apply -f '$GITOPS/argocd-application.yaml'"
for i in $(seq 1 90); do
  [ "$(kubectl -n argocd get application session20-mini -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)" = "Synced/Healthy" ] && break; sleep 2
done
run "kubectl get applications -n argocd"
note 'any error Argo CD reports (empty = none)'
run "kubectl -n argocd get application session20-mini -o jsonpath='{range .status.conditions[*]}{.type}: {.message}{\"\\n\"}{end}'"
run "kubectl -n argocd get application session20-mini -o jsonpath='repo: {.spec.source.repoURL}{\"\\n\"}branch: {.spec.source.targetRevision}{\"\\n\"}synced to commit: {.status.sync.revision}{\"\\n\"}'"
run "kubectl get all -n session20"
note 'the app answers (through the Service)'
run "kubectl -n session20 run curl-check --rm -i --restart=Never --image=curlimages/curl:8.16.0 -q -- curl -s session20-mini | grep -E 'h1|Kiran'"
pkill -f "port-forward.*argocd-server" 2>/dev/null
nohup kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
say "Argo CD UI: https://$(vm_ip):8080  user: admin  password: $PASS  (accept the self-signed certificate warning)"
}

# ---------------------------------------------------------------- 10. A change in Git
part10() {
section s20-10-git-change "Git change: replicas 2 -> 3, Argo CD applies it"
run "git -C '$GITOPS' fetch -q origin assignment && git -C '$GITOPS' log origin/assignment -3 --format='%h %an %s' -- app/"
run "git -C '$GITOPS' show origin/assignment:\"./app/deployment.yaml\" | grep replicas"
note 'ask Argo CD to check Git now instead of waiting for its 3-minute poll'
run "kubectl -n argocd annotate application session20-mini argocd.argoproj.io/refresh=hard --overwrite"
for i in $(seq 1 120); do
  [ "$(kubectl -n session20 get deploy session20-mini -o jsonpath='{.status.readyReplicas}')" = 3 ] && break; sleep 2
done
run "kubectl get deployment session20-mini -n session20"
run "kubectl get pods -n session20 -o wide | cut -c1-100"
run "kubectl get applications -n argocd"
run "kubectl -n argocd get application session20-mini -o jsonpath='{range .status.history[*]}deployed {.deployedAt}  commit {.revision}{\"\\n\"}{end}'"
}

# ---------------------------------------------------------------- 11. Self-healing
part11() {
section s20-11-self-heal "Self-healing: a manual kubectl change is undone"
note 'someone scales by hand, outside Git'
run "kubectl scale deployment session20-mini -n session20 --replicas=1"
run "kubectl get deployment session20-mini -n session20"
note 'Argo CD sees actual (1) != desired in Git (3) and reconciles'
for i in $(seq 1 60); do
  [ "$(kubectl -n session20 get deploy session20-mini -o jsonpath='{.spec.replicas}/{.status.readyReplicas}')" = 3/3 ] && break; sleep 2
done
run "kubectl get deployment session20-mini -n session20"
run "kubectl get events -n session20 --sort-by=.lastTimestamp | grep -iE 'Scaled|ScalingReplicaSet' | tail -4"
run "kubectl get applications -n argocd"
note 'logs of the app pods'
run "kubectl logs deployment/session20-mini -n session20 --tail 5"
}

# ---------------------------------------------------------------- 12. Cleanup
part12() {
section s20-12-cleanup "Cleanup"
pkill -f "port-forward.*argocd-server" 2>/dev/null
run "kubectl delete -f '$GITOPS/argocd-application.yaml' --wait=true"
for i in $(seq 1 30); do kubectl get ns session20 >/dev/null 2>&1 || break; kubectl -n session20 get deploy 2>/dev/null | grep -q session20-mini || break; sleep 2; done
run "kubectl get all -n session20 2>&1"
run "kubectl delete namespace argocd session20 --ignore-not-found --wait=false"
}

PARTS="${*:-1}"
for p in $PARTS; do "part$p"; done
echo "Done. Outputs are in outputs/"
