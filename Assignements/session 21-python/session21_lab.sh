#!/bin/bash
# Session 21 - Final DevOps Project: DevSecOps scans + final troubleshooting challenge
# Kiran N | Roll No: 10446
# My final project is StockPilot: https://github.com/Kirann1973/stockpilot-devops-capstone
# This script runs on my Ubuntu VM against that project. Run it from inside the "session 21-python" folder.
# Each part is saved to its own file in outputs/.
#   DevSecOps (all scanners run in Docker containers)
#     bash session21_lab.sh 1 2 3 4 5   -> tools + clone, SAST, SCA, secret scan, IaC + image scan
#     bash session21_lab.sh 6 7 8       -> security gate: PASS on StockPilot, FAIL on a bad commit, PASS after the fix
#   Final troubleshooting challenge (StockPilot Helm chart on Minikube)
#     bash session21_lab.sh 9           -> deploy, check every object, open the app (screenshot the browser)
#     bash session21_lab.sh 10 11 12    -> issues 1-3: ImagePullBackOff, CrashLoopBackOff, Pending
#     bash session21_lab.sh 13 14 15    -> issues 4-6: Service without endpoints, readiness probe, DNS
#     bash session21_lab.sh 16          -> summary and clean up

OUTDIR="$PWD/outputs"
SP="$HOME/stockpilot-devops-capstone"          # my final project, cloned from GitHub
BAD=/tmp/stockpilot-bad-commit                 # throw-away clone for the "bad commit" demo, never pushed
CHART="$SP/helm/stockpilot"
VALUES="$PWD/troubleshooting-challenge/values-lab.yaml"
NS=stockpilot
TAG=$(awk -F'"' '/tag:/ {print $2; exit}' "$VALUES")
IMG_B=ghcr.io/kirann1973/stockpilot-backend:$TAG
IMG_F=ghcr.io/kirann1973/stockpilot-frontend:$TAG
TOOLS=kiran-sec-tools:1
TRIVY=aquasec/trivy:0.67.2
GITLEAKS=zricethezav/gitleaks:v8.28.0
H="python3 lab_helpers.py"         # turns Trivy JSON into short tables
mkdir -p "$OUTDIR"
set -o pipefail
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }
vm_ip() { hostname -I | awk '{print $1}'; }
k() { kubectl -n $NS "$@"; }
rev() { helm list -n $NS -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["revision"])'; }
wait_for() {  # wait_for <max seconds> <shell condition>
  local i
  for i in $(seq 1 "$1"); do eval "$2" >/dev/null 2>&1 && return 0; sleep 1; done
  return 1
}
app_check() {  # the app through the Ingress: the page and the API
  run "curl -s -o /dev/null -w 'GET /                    -> HTTP %{http_code}\n' http://\$(minikube ip)/; curl -s -o /dev/null -w 'GET /api/products/stats -> HTTP %{http_code}\n' http://\$(minikube ip)/api/products/stats"
}
fix_with_helm() {  # helm rollback to the last good revision, then wait until everything is ready again
  run "helm rollback stockpilot $GOOD -n $NS --wait --timeout 5m"
  k rollout status deploy/stockpilot-backend --timeout=180s >/dev/null 2>&1
  k rollout status deploy/stockpilot-frontend --timeout=180s >/dev/null 2>&1
  wait_for 60 "[ \$(k get pods --no-headers | grep -vc ' Running') = 0 ]"
}
pods() { run "kubectl get pods -n $NS -o wide | cut -c1-105"; }

# ---------------------------------------------------------------- 1. Tools and the project
part1() {
section s21-01-setup "Tools, VM, and my final project StockPilot"
run "docker --version; minikube version | head -1; kubectl version --client | head -1; helm version --short"
run "echo VM IP: \$(vm_ip); nproc; free -h | head -2; df -h / | tail -1"
if [ -d "$SP/.git" ]; then git -C "$SP" pull -q; else git clone -q https://github.com/Kirann1973/stockpilot-devops-capstone.git "$SP"; fi
run "git -C '$SP' log --oneline | wc -l; git -C '$SP' log --format='%h %an  %s' -6"
run "ls '$SP'"
note 'build the scanner image once (Bandit + pip-audit) and pull Trivy, Gitleaks, Node'
docker build -q -t $TOOLS -f security/Dockerfile.tools security > /dev/null
for i in $TRIVY $GITLEAKS node:22-alpine; do docker pull -q "$i" > /dev/null; done
run "docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E 'kiran-sec|trivy|gitleaks|node:22'"
run "docker run --rm $TOOLS sh -c 'bandit --version | head -1; pip-audit --version'; docker run --rm $TRIVY --version | head -1; docker run --rm $GITLEAKS version"
}

# ---------------------------------------------------------------- 2. SAST
part2() {
section s21-02-sast "SAST: Bandit scans the StockPilot backend source code"
note 'static analysis: reads the code without running it, looks for insecure patterns (OWASP / CWE)'
run "docker run --rm -v '$SP:/src:ro' $TOOLS bandit -r backend/app"
}

# ---------------------------------------------------------------- 3. SCA
part3() {
section s21-03-sca "SCA: known vulnerabilities in third-party dependencies"
run "cat '$SP/backend/requirements.txt'"
note 'pip-audit: Python packages against the PyPI / OSV advisory databases'
run "docker run --rm -v '$SP:/src:ro' $TOOLS pip-audit -r backend/requirements.txt --no-deps --disable-pip --progress-spinner off 2>&1 | grep -v '^WARNING' | awk '!seen[\$0]++'"
note 'npm audit: every package in the React frontend lock file (production dependencies)'
run "docker run --rm -v '$SP/frontend:/src:ro' -w /src -e NPM_CONFIG_UPDATE_NOTIFIER=false node:22-alpine npm audit --omit=dev"
note 'Trivy filesystem scan: both lock files at once, HIGH and CRITICAL'
run "docker run --rm -v trivy-cache:/root/.cache -v '$SP:/src:ro' $TRIVY fs --quiet --scanners vuln --severity HIGH,CRITICAL /src"
}

# ---------------------------------------------------------------- 4. Secret scanning
part4() {
section s21-04-secrets "Secret scanning: Gitleaks checks every commit in the Git history"
run "git -C '$SP' log --oneline | wc -l"
run "docker run --rm --user \$(id -u):\$(id -g) -v '$SP:/repo:ro' $GITLEAKS git /repo --no-banner --no-color --redact -v"
note 'the backend reads the DB password from an environment variable / Kubernetes Secret, nothing is hard-coded'
run "grep -n 'database_url' '$SP/backend/app/config.py'; grep -n 'secretKeyRef' -A2 '$CHART/templates/backend-deployment.yaml'"
}

# ---------------------------------------------------------------- 5. IaC scan + container image scan
part5() {
section s21-05-iac-image-scan "IaC misconfiguration scan (Helm, Terraform, Dockerfiles) and container image scan"
note 'Trivy config: Kubernetes manifests, Terraform and Dockerfiles against security best practices (report only)'
run "docker run --rm -v trivy-cache:/root/.cache -v '$SP:/src:ro' $TRIVY config --quiet --severity HIGH,CRITICAL --format json /src | $H trivy_config"
note 'Trivy image: the images GitHub Actions pushed to GHCR (tag = commit SHA)'
run "docker run --rm -v trivy-cache:/root/.cache $TRIVY image --quiet --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --format json $IMG_B | $H trivy_image"
run "docker run --rm -v trivy-cache:/root/.cache $TRIVY image --quiet --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --format json $IMG_F | $H trivy_image"
}

# ---------------------------------------------------------------- 6. Security gate on StockPilot
part6() {
section s21-06-gate-pass "Security gate on StockPilot as it is on GitHub"
run "bash security/security_gate.sh '$SP' $IMG_B $IMG_F; echo gate exit code: \$?"
}

# ---------------------------------------------------------------- 7. A bad commit
part7() {
section s21-07-gate-fail "Security gate on a bad commit (throw-away local clone, never pushed)"
rm -rf "$BAD"; git clone -q "$SP" "$BAD"
note 'the bad commit adds: insecure code, two old libraries, a hard-coded GitHub token, and the app is built on an old base image'
cp security/bad-commit/export_report.py "$BAD/backend/app/"
printf 'requests==2.19.1\nPyYAML==5.3\n' >> "$BAD/backend/requirements.txt"
printf '# local settings\nGITHUB_TOKEN = "%s"\n' "ghp_$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)" > "$BAD/backend/app/settings_local.py"
git -C "$BAD" add -A
git -C "$BAD" -c user.name="Kiran N" -c user.email=kirann1234569@gmail.com commit -qm "Add product export feature"
run "git -C '$BAD' show --stat --format='%h %an  %s' HEAD"
note 'the token is random and fake. Gitleaks prints it as REDACTED'
run "bash security/security_gate.sh '$BAD' nginx:1.21.0-alpine; echo gate exit code: \$?"
}

# ---------------------------------------------------------------- 8. Fix the bad commit
part8() {
section s21-08-gate-fixed "Fix: drop the bad commit, then the gate passes again"
note 'the commit was never pushed, so it can simply be removed. If a real token had been pushed: revoke it first, then rewrite history'
run "git -C '$BAD' reset -q --hard HEAD~1 && git -C '$BAD' log --format='%h %an  %s' -2"
run "git -C '$BAD' status --short | wc -l"
run "bash security/security_gate.sh '$BAD' $IMG_B; echo gate exit code: \$?"
rm -rf "$BAD"
}

# ---------------------------------------------------------------- 9. Deploy StockPilot with Helm
part9() {
section s21-09-deploy "Deploy StockPilot on Minikube with its Helm chart"
if ! kubectl get nodes >/dev/null 2>&1; then
  note 'starting Minikube (same settings as earlier sessions)'
  minikube start --driver=docker --cpus=2 --memory=3500 > "$OUTDIR/minikube-start.log" 2>&1 || { say "minikube start failed:"; tail -5 "$OUTDIR/minikube-start.log" | tee -a "$OUT"; }
fi
note 'Ingress controller and metrics-server (needed by the HPA)'
minikube addons enable ingress > /dev/null 2>&1; minikube addons enable metrics-server > /dev/null 2>&1
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s > /dev/null 2>&1
run "kubectl get nodes; minikube addons list | grep -E '\\| (ingress|metrics-server) '"
run "cat '$VALUES' | grep -vE '^\\s*#'"
run "helm upgrade --install stockpilot '$CHART' -n $NS --create-namespace -f '$VALUES' --wait --timeout 8m"
run "helm list -n $NS"
pods
run "kubectl get deploy,statefulset,svc,ingress,hpa,pvc -n $NS"
run "kubectl get configmap,secret -n $NS | grep -v kube-root"
note 'probes and resources on the backend'
run "k get deploy stockpilot-backend -o jsonpath='readiness: {.spec.template.spec.containers[0].readinessProbe.httpGet.path}{\"\\n\"}liveness:  {.spec.template.spec.containers[0].livenessProbe.httpGet.path}{\"\\n\"}requests:  {.spec.template.spec.containers[0].resources.requests}{\"\\n\"}limits:    {.spec.template.spec.containers[0].resources.limits}{\"\\n\"}'"
app_check
run "curl -s http://\$(minikube ip)/api/products/stats; echo"
pkill -f "port-forward.*ingress-nginx-controller" 2>/dev/null
nohup kubectl port-forward --address 0.0.0.0 -n ingress-nginx svc/ingress-nginx-controller 8088:80 > /dev/null 2>&1 &
say "Open from your Mac: http://$(vm_ip):8088   (StockPilot through the Ingress)"
}

# ---------------------------------------------------------------- 10. Issue 1
part10() {
section s21-10-issue1-imagepull "Issue 1: a release with an image tag that does not exist"
GOOD=$(rev)
note "break it: someone deploys tag v2.0.0, which CI never built"
run "helm upgrade stockpilot '$CHART' -n $NS -f '$VALUES' --set image.tag=v2.0.0 2>&1 | grep -E 'STATUS|REVISION'"
wait_for 90 "k get pods | grep -qE 'ErrImagePull|ImagePullBackOff'"
note 'symptom'
pods
app_check
note 'investigate'
NEWPOD=$(k get pods -l app=stockpilot-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)
run "k describe $NEWPOD | grep -E '^Name:|Image:|Failed|Back-off' | cut -c1-160"
run "helm history stockpilot -n $NS --max 3"
say "ROOT CAUSE: tag v2.0.0 does not exist in ghcr.io/kirann1973 (manifest unknown). The old pods keep running because a"
say "            rolling update only removes old pods after new ones are Ready, so users saw no outage."
note "fix: roll back to the last good Helm revision ($GOOD)"
fix_with_helm
note 'verify'
pods
app_check
}

# ---------------------------------------------------------------- 11. Issue 2
part11() {
section s21-11-issue2-crashloop "Issue 2: wrong database password in the Secret"
GOOD=$(rev)
note 'break it: the DB password in the release values is changed, but the database still has the old one'
run "helm upgrade stockpilot '$CHART' -n $NS -f '$VALUES' --set postgres.password=Summer2026 2>&1 | grep -E 'STATUS|REVISION'"
wait_for 150 "k get pods -l app=stockpilot-backend -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}' | tr ' ' '\\n' | awk '\$1>=2' | grep -q ."
note 'symptom'
pods
NEWPOD=$(k get pods -l app=stockpilot-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)
note 'investigate'
run "k get $NEWPOD -o jsonpath='{.metadata.name}  restarts={.status.containerStatuses[0].restartCount}  last exit code={.status.containerStatuses[0].lastState.terminated.exitCode}{\"\\n\"}'"
run "k logs $NEWPOD --previous --tail 40 | grep -E 'OperationalError|FATAL|password' | head -3 | cut -c1-200"
run "k get secret stockpilot-db -o jsonpath='{.data.DATABASE_URL}' | base64 -d | sed -E 's#(://[^:]+:)[^@]+@#\\1*****@#'; echo"
say "ROOT CAUSE: the Secret now holds a new password, but Postgres keeps the password it was initialised with (it is only"
say "            read on the first start). The new backend pods fail at 'alembic upgrade', exit with code 1, and restart in a loop."
note "fix: roll back to revision $GOOD (old Secret). Changing a DB password needs ALTER USER in Postgres first"
fix_with_helm
note 'verify'
pods
app_check
}

# ---------------------------------------------------------------- 12. Issue 3
part12() {
section s21-12-issue3-pending "Issue 3: a pod that asks for more CPU than the node has"
GOOD=$(rev)
note 'break it: backend requests 4 CPUs, the Minikube node has 2'
run "helm upgrade stockpilot '$CHART' -n $NS -f '$VALUES' --set backend.resources.requests.cpu=4 --set backend.resources.limits.cpu=4 2>&1 | grep -E 'STATUS|REVISION'"
wait_for 60 "k get pods | grep -q Pending"
note 'symptom'
pods
note 'investigate'
run "k describe pod \$(k get pods --field-selector=status.phase=Pending -o name | head -1 | cut -d/ -f2) | grep -A4 '^Events:' | cut -c1-170"
run "kubectl describe node minikube | grep -A6 'Allocated resources' ; kubectl get node minikube -o jsonpath='allocatable cpu: {.status.allocatable.cpu}{\"\\n\"}'"
say "ROOT CAUSE: the scheduler cannot find a node with 4 free CPUs (Insufficient cpu), so the pod stays Pending forever."
note "fix: roll back to revision $GOOD (requests 100m, limits 500m)"
fix_with_helm
note 'verify'
pods
}

# ---------------------------------------------------------------- 13. Issue 4
part13() {
section s21-13-issue4-service "Issue 4: the backend Service selects no pods"
GOOD=$(rev)
note 'break it: a manual kubectl change of the Service selector (typo: stockpilot-api)'
run "k patch svc stockpilot-backend --type merge -p '{\"spec\":{\"selector\":{\"app\":\"stockpilot-api\"}}}'"
sleep 5
note 'symptom: the page loads but the API behind the Ingress fails'
app_check
note 'investigate'
run "k get endpointslices -l kubernetes.io/service-name=stockpilot-backend"
run "k get svc stockpilot-backend -o wide"
run "k get pods -l app=stockpilot-backend --show-labels | cut -c1-120"
say "ROOT CAUSE: the Service selector app=stockpilot-api matches no pod (the pods are labelled app=stockpilot-backend),"
say "            so the Service has no endpoints and the Ingress returns 503."
note "fix: helm rollback to the same revision $GOOD re-applies the chart. Helm 3 compares chart, old release and live object, so it undoes the manual change"
fix_with_helm
if ! k get endpointslices -l kubernetes.io/service-name=stockpilot-backend -o jsonpath='{.items[*].endpoints[*].addresses}' | grep -q .; then
  note 'Helm did not change the selector back, so patch it to the label the pods really have'
  run "k patch svc stockpilot-backend --type merge -p '{\"spec\":{\"selector\":{\"app\":\"stockpilot-backend\"}}}'"
fi
note 'verify'
run "k get svc stockpilot-backend -o wide; k get endpointslices -l kubernetes.io/service-name=stockpilot-backend"
app_check
}

# ---------------------------------------------------------------- 14. Issue 5
part14() {
section s21-14-issue5-probe "Issue 5: a readiness probe on a path that does not exist"
note 'break it: the frontend readiness probe is changed to /healthz (nginx only answers on /nginx-health)'
run "k patch deploy stockpilot-frontend --type json -p '[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"/healthz\"}]'"
sleep 40
note 'symptom: the new pod is Running but never Ready, and the rollout is stuck'
pods
run "k rollout status deploy/stockpilot-frontend --timeout=10s"
note 'investigate'
run "k describe pod \$(k get pods -l app=stockpilot-frontend --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d/ -f2) | grep -E 'Readiness|Unhealthy' | cut -c1-170"
run "k exec deploy/stockpilot-frontend -- sh -c 'wget -qO- -T 2 localhost:8080/nginx-health; wget -qO- -T 2 localhost:8080/healthz 2>&1 | head -1'"
say "ROOT CAUSE: /healthz returns 404, so the probe fails and Kubernetes never sends traffic to the new pod."
say "            The 2 old pods keep serving (maxUnavailable), so the app stays up, but the new version never rolls out."
note 'fix: undo the rollout (go back to the previous ReplicaSet)'
run "k rollout undo deploy/stockpilot-frontend && k rollout status deploy/stockpilot-frontend --timeout=120s"
note 'verify'
pods
app_check
}

# ---------------------------------------------------------------- 15. Issue 6
part15() {
section s21-15-issue6-dns "Issue 6: the frontend points at a backend name that does not resolve (DNS)"
note 'break it: BACKEND_URL copied from another environment, with namespace stockpilot-prod (it does not exist here)'
run "k set env deploy/stockpilot-frontend BACKEND_URL=http://stockpilot-backend.stockpilot-prod.svc.cluster.local:8000"
wait_for 90 "k get pods -l app=stockpilot-frontend --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].status.containerStatuses[0].restartCount}' | grep -qvE '^0?\$'"
note 'symptom'
pods
NEWPOD=$(k get pods -l app=stockpilot-frontend --sort-by=.metadata.creationTimestamp -o name | tail -1)
note 'investigate'
run "k logs $NEWPOD --previous --tail 20 2>/dev/null | grep -E 'emerg|host not found' | cut -c1-200 || k logs $NEWPOD --tail 20 | grep -E 'emerg|host not found' | cut -c1-200"
run "kubectl run dns-test -n $NS --rm -i --restart=Never --image=busybox:1.37 -q -- sh -c 'nslookup stockpilot-backend.stockpilot-prod.svc.cluster.local; echo ---; nslookup stockpilot-backend.stockpilot.svc.cluster.local' 2>&1 | grep -vE '^\$' | cut -c1-120"
say "ROOT CAUSE: CoreDNS has no record for stockpilot-backend.stockpilot-prod (NXDOMAIN). nginx resolves proxy_pass hosts at"
say "            start-up, fails with 'host not found in upstream' and the container crashes. The right name is"
say "            stockpilot-backend.stockpilot.svc.cluster.local (<service>.<namespace>.svc.cluster.local)."
note 'fix: undo the rollout'
run "k rollout undo deploy/stockpilot-frontend && k rollout status deploy/stockpilot-frontend --timeout=120s"
note 'verify'
run "k get deploy stockpilot-frontend -o jsonpath='{.spec.template.spec.containers[0].env}'; echo"
pods
app_check
}

# ---------------------------------------------------------------- 16. Summary and cleanup
part16() {
section s21-16-cleanup "Summary of the challenge, then clean up"
run "helm history stockpilot -n $NS"
run "k get events --sort-by=.lastTimestamp | grep -E 'Failed|BackOff|FailedScheduling|Unhealthy' | awk '{print \$2, \$3, \$4}' | sort | uniq -c | sort -rn | head -8"
pkill -f "port-forward.*ingress-nginx-controller" 2>/dev/null
run "helm uninstall stockpilot -n $NS"
run "kubectl delete namespace $NS --wait=true --timeout=120s"
run "kubectl get ns | grep -c stockpilot"
}

PARTS="${*:-1}"
for p in $PARTS; do "part$p"; done
echo "Done. Outputs are in outputs/"
