#!/bin/bash
# Session 15 - Helm: create, chart structure, values, templates, all main commands, repos, rollback, mini project (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 15-helm" folder, after "minikube start".
# Each part is saved to its own file in outputs/.
#   bash session15_lab.sh        -> all parts (about 10 minutes)
#   bash session15_lab.sh 3 5    -> only parts 3 and 5

OUTDIR=outputs
WORK="$HOME/helm-kiran"          # scratch folder for "helm create" and "helm pull" (not part of the repo)
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }

# print "kubectl get pods -l app=<label>" every 3 s whenever it changes,
# until a pod STATUS matches $3 or $2 seconds pass.   usage: watch_pods <app-label> <seconds> <regex>
watch_pods() {
  local app=$1 max=$2 re=$3 last="" now start
  start=$(date +%s)
  note "watching pods app=$app (every 3 s)"
  while [ $(( $(date +%s) - start )) -le "$max" ]; do
    now=$(kubectl get pods -l app="$app" --no-headers 2>&1 | awk '{print $1, $2, $3, $4}' | sort)
    if [ "$now" != "$last" ]; then
      say "+$(( $(date +%s) - start ))s"; say "$now"; last=$now
    fi
    echo "$now" | awk '{print $3}' | grep -Eq "$re" && break
    sleep 3
  done
  echo | tee -a "$OUT"
}

# Helm 3 calls auto-rollback "--atomic", Helm 4 renamed it to "--rollback-on-failure"
atomic_flag() { helm upgrade --help 2>/dev/null | grep -q -- '--rollback-on-failure' && echo --rollback-on-failure || echo --atomic; }

cleanup() {
  for r in kiran-app web-app rollback-demo guestbook notes-dev my-podinfo; do
    helm uninstall "$r" --wait >/dev/null 2>&1
  done
  rm -rf "$WORK"
}

# ---------------------------------------------------------------- 1. Install Helm + helm create
part1() {
section s15-01-helm-create "Helm setup and helm create"
if ! command -v helm >/dev/null; then
  note 'helm is not installed: install it with the official script'
  run 'curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'
fi
run 'helm version'
run 'kubectl config current-context'
run 'kubectl get nodes'
note 'helm create: generate a complete starter chart'
rm -rf "$WORK"; mkdir -p "$WORK"
run "cd $WORK && helm create kiran-app; cd - >/dev/null"
run "find $WORK/kiran-app | sed 's|$WORK/||' | sort"
run "grep -vE '^\s*#|^\s*$' $WORK/kiran-app/Chart.yaml"
run "grep -E '^replicaCount|^image:|^  repository|^  tag|^service:|^  type|^  port|^ingress:|^  enabled|^autoscaling:' $WORK/kiran-app/values.yaml"
note 'helm lint: check the chart for errors'
run "helm lint $WORK/kiran-app"
note 'helm template: render the YAML locally, nothing is sent to the cluster'
run "helm template kiran-app $WORK/kiran-app | grep -E '^# Source|^kind:'"
run "helm template kiran-app $WORK/kiran-app --set replicaCount=3 --set image.tag=1.27 | grep -E 'replicas:|image:'"
}

# ---------------------------------------------------------------- 2. Chart structure, Chart.yaml, values, templates
part2() {
section s15-02-structure-values-templates "Chart structure, Chart.yaml, values.yaml and templates"
note '03 simple chart: the minimum a chart needs'
run "find 03-chart-structure/simple-chart -type f | sort"
run 'helm template demo 03-chart-structure/simple-chart'
note '04 Chart.yaml: version = chart version, appVersion = app version'
run "grep -vE '^\s*#|^\s*$' 04-chart-yaml/Chart.yaml"
note '05 values: defaults, then -f file, then --set (the last one wins)'
run "helm template demo 05-values-yaml/my-app | grep -E 'replicas:|image:'"
run "helm template demo 05-values-yaml/my-app -f 05-values-yaml/values-prod.yaml | grep -E 'replicas:|image:'"
run "helm template demo 05-values-yaml/my-app -f 05-values-yaml/values-prod.yaml --set replicaCount=2 --set image.tag=1.27 | grep -E 'replicas:|image:'"
note '06 templates: .Release.Name, .Values and an if block'
run "helm template kiran 06-templates/template-demo | grep -E '^kind:|name:|replicas:|image:'"
run "helm template kiran 06-templates/template-demo --set service.enabled=false | grep -E '^kind:'"
note 'dry run: the API server validates the rendered YAML, nothing is created'
run "helm install kiran 06-templates/template-demo --dry-run=server | grep -E '^NAME|^STATUS|^kind:'"
}

# ---------------------------------------------------------------- 3. Task 1: Helm commands
part3() {
section s15-03-helm-commands "Task 1: helm install, list, status, get, upgrade, history, rollback, uninstall"
[ -d "$WORK/kiran-app" ] || (mkdir -p "$WORK" && cd "$WORK" && helm create kiran-app >/dev/null)
note 'helm install: create a release (revision 1)'
run "helm install kiran-app $WORK/kiran-app --set image.tag=1.27 --wait --timeout 180s"
note 'helm list: all releases in the namespace'
run 'helm list'
note 'helm status: state of one release (+ its NOTES)'
run 'helm status kiran-app'
note 'helm get: what Helm stored for this release'
run 'helm get values kiran-app'
run 'helm get values kiran-app --all | grep -E "^replicaCount|^  tag|^  repository"'
run "helm get manifest kiran-app | grep -E '^# Source|^kind:|image:'"
run 'helm get notes kiran-app | head -6'
run 'helm get metadata kiran-app'
run 'kubectl get deploy,svc,pods -l app.kubernetes.io/instance=kiran-app'
note 'helm upgrade: change the release, creates revision 2'
run "helm upgrade kiran-app $WORK/kiran-app --set image.tag=1.27 --set replicaCount=2 --wait --timeout 180s"
run 'kubectl get pods -l app.kubernetes.io/instance=kiran-app'
note 'helm history: every revision of the release'
run 'helm history kiran-app'
note 'helm rollback: go back to revision 1 (creates revision 3)'
run 'helm rollback kiran-app 1 --wait --timeout 180s'
run 'kubectl get pods -l app.kubernetes.io/instance=kiran-app'
run 'helm history kiran-app'
note 'Helm 3 keeps every revision as a Secret in the namespace'
run 'kubectl get secrets -l owner=helm,name=kiran-app'
note 'helm upgrade --install: installs if new, upgrades if it exists (the CI/CD way)'
run "helm upgrade --install web-app 07-install-upgrade/app-chart --wait --timeout 180s | grep -E '^NAME|^STATUS|^REVISION'"
run "helm upgrade --install web-app 07-install-upgrade/app-chart --set replicaCount=3 --wait --timeout 180s | grep -E 'upgraded|^STATUS|^REVISION'"
run 'helm list'
note 'helm uninstall: removes the release, its objects and its history'
run 'helm uninstall kiran-app web-app --wait'
run 'helm list --all'
run 'kubectl get secrets -l owner=helm'
}

# ---------------------------------------------------------------- 4. helm repo + helm search
part4() {
section s15-04-repo-search "Task 1: helm repo and helm search"
note 'helm repo: add chart repositories'
run 'helm repo add podinfo https://stefanprodan.github.io/podinfo'
run 'helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx'
run 'helm repo update'
run 'helm repo list'
note 'helm search repo: search the repos I added'
run 'helm search repo podinfo'
run 'helm search repo ingress-nginx/ingress-nginx --versions | head -5'
note 'helm search hub: search Artifact Hub (all public charts)'
run 'helm search hub nginx --max-col-width 50 | head -8'
note 'look at a chart before installing it'
run 'helm show chart podinfo/podinfo'
run "helm show values podinfo/podinfo | grep -E '^replicaCount|^ui:|^  message|^  color'"
run "mkdir -p $WORK && cd $WORK && helm pull podinfo/podinfo --untar && ls podinfo; cd - >/dev/null"
note 'install a chart from a repo, with my own values'
run "helm install my-podinfo podinfo/podinfo --set ui.message='Hello from Kiran N - Roll No 10446' --set replicaCount=2 --wait --timeout 180s | grep -E '^NAME|^STATUS|^REVISION'"
run 'kubectl rollout status deploy/my-podinfo --timeout=120s'
run 'kubectl get pods | grep -E "NAME|my-podinfo"'
note 'open the app through a port-forward and read its JSON answer'
kubectl port-forward svc/my-podinfo 9898:9898 >/dev/null 2>&1 &
PF=$!; sleep 4
run "curl -s http://localhost:9898 | grep -E 'hostname|message|version'"
kill $PF 2>/dev/null
run 'helm uninstall my-podinfo --wait'
}

# ---------------------------------------------------------------- 5. Task 2: rollback workflow
part5() {
section s15-05-rollback-workflow "Task 2: install -> upgrade -> verify -> upgrade again -> verify -> rollback -> verify"
note 'INSTALL (revision 1): 1 replica, nginx:1.24'
run 'helm install rollback-demo 07-install-upgrade/app-chart --wait --timeout 180s'
note 'VERIFY'
run 'kubectl get pods -l app=rollback-demo'
run "kubectl get deploy rollback-demo-app -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}{\"\n\"}'"
note 'UPGRADE (revision 2): 3 replicas, nginx:1.25'
run 'helm upgrade rollback-demo 07-install-upgrade/app-chart --set replicaCount=3 --set image.tag=1.25 --wait --timeout 180s'
note 'VERIFY'
run 'kubectl get pods -l app=rollback-demo'
run "kubectl get deploy rollback-demo-app -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}{\"\n\"}'"
run 'helm get values rollback-demo'
note 'UPGRADE AGAIN (revision 3): a bad image tag. --reuse-values keeps replicaCount=3 from revision 2'
run 'helm upgrade rollback-demo 07-install-upgrade/app-chart --reuse-values --set image.tag=doesnotexist'
note 'VERIFY: Helm says "deployed", but the new pods cannot start'
watch_pods rollback-demo 90 'ImagePullBackOff'
run 'kubectl get pods -l app=rollback-demo'
run "kubectl describe pods -l app=rollback-demo | grep -E 'Failed to pull image' | head -1"
run 'kubectl rollout status deploy/rollback-demo-app --timeout=20s'
run 'helm history rollback-demo'
note 'ROLLBACK to revision 2 (the last good one)'
run 'helm rollback rollback-demo 2 --wait --timeout 180s'
note 'VERIFY'
run 'kubectl get pods -l app=rollback-demo'
run "kubectl get deploy rollback-demo-app -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}{\"\n\"}'"
run 'helm history rollback-demo'
F=$(atomic_flag)
note "BONUS: automatic rollback with $F (helm waits, the pods never get ready, helm rolls back by itself)"
run "helm upgrade rollback-demo 07-install-upgrade/app-chart --reuse-values --set image.tag=doesnotexist $F --timeout 60s"
run 'kubectl get pods -l app=rollback-demo'
run 'helm history rollback-demo'
run 'helm uninstall rollback-demo --wait'
}

# ---------------------------------------------------------------- 6. 09 Deploying an application (guestbook)
part6() {
section s15-06-guestbook "Deploying an application: guestbook chart (lint, install, upgrade, rollback)"
run 'helm lint 09-deploying-application/guestbook-chart'
run "helm install guestbook 09-deploying-application/guestbook-chart --set image.tag=1.27 --wait --timeout 180s | grep -E '^NAME|^STATUS|^REVISION'"
run 'kubectl get deploy/guestbook-app svc/guestbook-svc configmap/guestbook-config'
P='deploy/guestbook-app'
run "kubectl exec $P -- printenv welcome appName"
run "curl -s http://\$(minikube ip):30080 | grep '<title>'"
note 'upgrade: change the ConfigMap values'
run "helm upgrade guestbook 09-deploying-application/guestbook-chart --reuse-values --set config.welcomeMessage='Welcome from Kiran N - Roll No 10446' --set config.appName='Kiran Guestbook' --wait | grep -E 'upgraded|^REVISION'"
run 'kubectl get configmap guestbook-config -o jsonpath="{.data}{\"\n\"}"'
note 'the running pod still has the OLD values: env from a ConfigMap is read only when the container starts'
run "kubectl exec $P -- printenv welcome appName"
run "kubectl rollout restart $P && kubectl rollout status $P --timeout=120s"
run "kubectl exec $P -- printenv welcome appName"
run 'helm history guestbook'
note 'rollback to revision 1'
run 'helm rollback guestbook 1 --wait'
run 'kubectl get configmap guestbook-config -o jsonpath="{.data}{\"\n\"}"'
run 'helm history guestbook'
run 'helm uninstall guestbook --wait'
}

# ---------------------------------------------------------------- 7. Task 3: Mini project - Notes app
part7() {
section s15-07-mini-project "Task 3: Mini project - package and deploy the Notes app with Helm"
C=mini-project/notes-chart
note 'Steps 1-7: the chart'
run "find $C -type f | sort"
run "cat $C/Chart.yaml"
run "diff $C/values.yaml $C/values-prod.yaml"
note 'Step 8: lint'
run "helm lint $C"
note 'Step 9: render locally, every {{ }} must be replaced'
run "helm template notes-dev $C | grep -E '^kind:|name:|replicas:|image:|APP_NAME|ENVIRONMENT|nodePort'"
run "helm template notes-dev $C | grep -c '{{' || true"
note 'Step 10: install (development values)'
run "helm install notes-dev $C --set app.name='notes-app (Kiran N - 10446)' --wait --timeout 180s"
run 'kubectl get pods -l app=notes-dev'
run 'kubectl get svc notes-dev-svc'
run 'kubectl get configmap notes-dev-config -o jsonpath="{.data}{\"\n\"}"'
run 'kubectl exec deploy/notes-dev-deploy -- printenv APP_NAME ENVIRONMENT'
run "curl -s http://\$(minikube ip):30090 | grep '<title>'"
run "curl -sI http://\$(minikube ip):30090 | grep -i '^server'"
note 'Step 11: upgrade to production values (3 replicas, nginx:1.25)'
run "helm upgrade notes-dev $C -f $C/values-prod.yaml --wait --timeout 180s"
run 'kubectl get pods -l app=notes-dev'
run 'kubectl exec deploy/notes-dev-deploy -- printenv APP_NAME ENVIRONMENT'
run "curl -sI http://\$(minikube ip):30090 | grep -i '^server'"
note 'Step 12: history'
run 'helm history notes-dev'
note 'Step 13: simulate a bad upgrade (exactly as in the project: no -f, so the dev defaults come back too)'
run "helm upgrade notes-dev $C --set image.tag=broken-tag-does-not-exist"
watch_pods notes-dev 90 'ImagePullBackOff'
run 'kubectl get pods -l app=notes-dev'
run "kubectl get deploy notes-dev-deploy -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}{\"\n\"}'"
run "curl -s -o /dev/null -w 'app still answers: HTTP %{http_code}\n' http://\$(minikube ip):30090"
note 'Step 14: rollback to revision 2'
run 'helm rollback notes-dev 2 --wait --timeout 180s'
sleep 10   # let the broken pod finish terminating
run 'kubectl get pods -l app=notes-dev'
run "kubectl get deploy notes-dev-deploy -o jsonpath='replicas={.spec.replicas} image={.spec.template.spec.containers[0].image}{\"\n\"}'"
run 'helm history notes-dev'
note 'Step 15: clean up'
run 'helm uninstall notes-dev --wait'
kubectl wait --for=delete pod -l app=notes-dev --timeout=90s >/dev/null 2>&1
run 'kubectl get pods -l app=notes-dev'
run 'kubectl get svc,configmap | grep notes-dev || echo "no notes-dev objects left"'
run 'helm list --all'
}

PARTS="${*:-1 2 3 4 5 6 7}"
[ -z "$*" ] && cleanup
for n in $PARTS; do part$n; done
echo "Done. Outputs saved in $OUTDIR/"
