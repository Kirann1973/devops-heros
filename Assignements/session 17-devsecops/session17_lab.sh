#!/bin/bash
# Session 17 - DevSecOps: the same security checks as the pipeline, run by hand, then a Kubernetes deploy (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 17-devsecops" folder, after "minikube start".
# Each part is saved to its own file in outputs/.
#   bash session17_lab.sh        -> all parts (about 10 minutes, the first run downloads the scanners)
#   bash session17_lab.sh 2 4    -> only parts 2 and 4

OUTDIR=outputs
PROJECT=09-devsecops-project
WORK="$HOME/devsecops-kiran"     # scratch folder: python venv, scanner binaries, image tar (not part of the repo)
IMAGE=ghcr.io/kirann1973/session17-devsecops
NS=devsecops
GITLEAKS_VERSION=8.30.1
TRIVY_VERSION=0.76.0
mkdir -p "$OUTDIR" "$WORK/bin"
set -o pipefail                  # so "gate" shows the scanner's exit code even when its output is piped
export PATH="$WORK/bin:$PATH"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
# like run, but also prints the exit code (0 = pass, anything else = the gate stops the pipeline)
gate() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo "exit code: ${PIPESTATUS[0]}" | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }

install_tools() {
  local gl tv
  case "$(uname -m)" in
    aarch64|arm64) gl=arm64; tv=ARM64 ;;
    *)             gl=x64;   tv=64bit ;;
  esac
  if [ ! -x "$WORK/venv/bin/python" ]; then
    python3 -m venv "$WORK/venv" || {
      sudo apt-get update -qq && sudo apt-get install -y -qq python3-venv
      rm -rf "$WORK/venv"; python3 -m venv "$WORK/venv"
    }
  fi
  "$WORK/venv/bin/pip" install -q -r "$PROJECT/requirements-dev.txt" bandit pip-audit
  if [ ! -x "$WORK/bin/gitleaks" ]; then
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v$GITLEAKS_VERSION/gitleaks_${GITLEAKS_VERSION}_linux_$gl.tar.gz" | tar xz -C "$WORK/bin" gitleaks
  fi
  if [ ! -x "$WORK/bin/trivy" ]; then
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v$TRIVY_VERSION/trivy_${TRIVY_VERSION}_Linux-$tv.tar.gz" | tar xz -C "$WORK/bin" trivy
  fi
}

cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=true >/dev/null 2>&1
  pkill -f "port-forward.*devsecops-python-service" 2>/dev/null
  rm -f "$WORK/image.tar"
}

# ---------------------------------------------------------------- 1. Build + unit tests + SAST
part1() {
section s17-01-tests-sast "Build, unit tests and SAST (Bandit)"
note 'installing the tools into a python venv and ~/devsecops-kiran/bin'
install_tools > "$WORK/install.log" 2>&1 || say "tool install failed, see $WORK/install.log"
run "$WORK/venv/bin/python --version; $WORK/venv/bin/bandit --version | head -1; $WORK/venv/bin/pip-audit --version; gitleaks version; trivy --version | head -1"
note 'build: every module must compile'
run "cd $PROJECT && $WORK/venv/bin/python -m compileall -q app && echo 'Build OK'"
note 'unit tests with a coverage gate of 90%'
gate "cd $PROJECT && $WORK/venv/bin/python -m pytest -v -p no:cacheprovider --cov=app --cov-report=term-missing --cov-fail-under=90"
note 'SAST - Bandit reads the source code without running it'
gate "$WORK/venv/bin/bandit -c $PROJECT/security/bandit.yaml -r $PROJECT/app -ll"
note 'SAST demo: code with debug=True, shell=True and a hard-coded password'
mkdir -p "$WORK/bad-code"
cat > "$WORK/bad-code/bad_app.py" <<'EOF'
import subprocess
from flask import Flask
app = Flask(__name__)
DB_PASSWORD = "admin123"

@app.route("/ping/<host>")
def ping(host):
    return subprocess.check_output("ping -c 1 " + host, shell=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
EOF
gate "cd $WORK && $WORK/venv/bin/bandit -r bad-code -ll -f custom --msg-template '{relpath}:{line}  {test_id}  {severity}  {msg}'"
}

# ---------------------------------------------------------------- 2. SCA + secret scanning
part2() {
section s17-02-sca-secrets "SCA (pip-audit) and secret scanning (Gitleaks)"
[ -x "$WORK/bin/gitleaks" ] || install_tools > "$WORK/install.log" 2>&1 || say "tool install failed, see $WORK/install.log"
note 'SCA - pip-audit checks every pinned dependency against the vulnerability databases'
run "cat $PROJECT/requirements.txt"
gate "$WORK/venv/bin/pip-audit -r $PROJECT/requirements.txt --strict"
note 'SCA demo: the old requests 2.19.1 that pipeline run #3 blocked'
printf 'Flask==3.1.3\nrequests==2.19.1\n' > "$WORK/requirements-vulnerable.txt"
gate "$WORK/venv/bin/pip-audit -r $WORK/requirements-vulnerable.txt --strict | cut -c1-120"
note 'Secret scan - Gitleaks on the project'
gate "gitleaks dir $PROJECT --config $PROJECT/security/gitleaks.toml --redact --no-banner --no-color"
note 'Secret scan demo: a fake key written into a scratch file (never committed)'
mkdir -p "$WORK/leak-demo"
printf 'import os\napi_key = "kiranFakeKey10446abcdefXYZ"\nsafe_key = os.getenv("API_KEY")\n' > "$WORK/leak-demo/settings.py"
run "cat $WORK/leak-demo/settings.py"
gate "gitleaks dir $WORK/leak-demo --config $PROJECT/security/gitleaks.toml --no-banner --no-color -v"
}

# ---------------------------------------------------------------- 3. Docker build + image scan + security gate
part3() {
section s17-03-image-scan "Docker build inside Minikube, Trivy image scan and the security gate"
[ -x "$WORK/bin/trivy" ] || install_tools > "$WORK/install.log" 2>&1 || say "tool install failed, see $WORK/install.log"
note 'build two versions of the image straight into Minikube (native for this machine)'
run "minikube image build -t $IMAGE:local-v1 --build-opt=build-arg=APP_VERSION=local-v1 $PROJECT | tail -3"
run "minikube image build -t $IMAGE:local-v2 --build-opt=build-arg=APP_VERSION=local-v2 $PROJECT | tail -3"
run "minikube image ls | grep session17"
run "minikube image save $IMAGE:local-v1 $WORK/image.tar && ls -lh $WORK/image.tar"
note 'Trivy full report: every severity, information only'
run "trivy image -q --input $WORK/image.tar --format table 2>&1 | grep -E '^Total|^Report Summary' "
note 'the security gate: fail only on HIGH/CRITICAL that already have a fix (security/trivy.yaml)'
run "grep -vE '^#' $PROJECT/security/trivy.yaml"
gate "cd $PROJECT && trivy image -q --config security/trivy.yaml --input $WORK/image.tar"
note 'the same scan without ignore-unfixed: the base OS has HIGH findings that have no fix yet'
gate "cd $PROJECT && trivy image -q --config security/trivy.yaml --ignore-unfixed=false --input $WORK/image.tar 2>&1 | grep -E '^Total|^Report'"
note 'Trivy config scan: Dockerfile + Kubernetes manifests'
gate "trivy config -q --severity HIGH,CRITICAL --exit-code 1 $PROJECT"
}

# ---------------------------------------------------------------- 4. Deploy to Kubernetes
part4() {
section s17-04-k8s-deploy "Deploy to Kubernetes (Minikube) with a restricted namespace"
run 'kubectl config current-context'
run "kubectl apply -f $PROJECT/k8s/namespace.yaml"
run "kubectl get namespace $NS --show-labels"
note 'deployment.yaml has the __TAG__ placeholder: the pipeline puts the commit tag there, here we use local-v1'
run "sed 's|__TAG__|local-v1|' $PROJECT/k8s/deployment.yaml | kubectl apply -f -"
run "kubectl apply -f $PROJECT/k8s/service.yaml"
run "kubectl -n $NS rollout status deployment/devsecops-python --timeout=120s"
run "kubectl -n $NS get deployment,pods,service -o wide"
run "kubectl -n $NS get pod -l app=devsecops-python -o jsonpath='{range .items[*]}{.metadata.name}{\"  user=\"}{.spec.securityContext.runAsUser}{\"  readOnlyRootFS=\"}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{\"\\n\"}{end}'"
note 'test the app through the Service'
kubectl -n "$NS" port-forward service/devsecops-python-service 8080:80 >/dev/null 2>&1 &
PF=$!; sleep 4
run 'curl -s http://localhost:8080/health; echo'
run 'curl -s http://localhost:8080/api/info; echo'
run "curl -s -X POST http://localhost:8080/api/calculate -H 'Content-Type: application/json' -d '{\"a\": 104, \"b\": 46, \"operation\": \"add\"}'; echo"
run "curl -s -X POST http://localhost:8080/api/password-check -H 'Content-Type: application/json' -d '{\"password\": \"Kiran-N-10446!\"}'; echo"
run 'curl -sI http://localhost:8080/ | grep -iE "^HTTP|x-frame|x-content|content-security"'
kill $PF 2>/dev/null
note 'Pod Security "restricted": a normal root nginx pod is rejected in this namespace'
run "kubectl -n $NS run root-test --image=nginx"
}

# ---------------------------------------------------------------- 5. Rolling update + rollback
part5() {
section s17-05-rolling-update "Change the image tag, kubectl set image, rollout, rollback"
run "kubectl -n $NS get deployment devsecops-python -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"
note 'what the pipeline does on every release: point the Deployment at the new image'
run "kubectl -n $NS set image deployment/devsecops-python devsecops-python=$IMAGE:local-v2"
run "kubectl -n $NS annotate deployment/devsecops-python kubernetes.io/change-cause='image local-v2 (Kiran N - 10446)' --overwrite"
run "kubectl -n $NS rollout status deployment/devsecops-python --timeout=120s"
run "kubectl -n $NS get pods -o jsonpath='{range .items[*]}{.metadata.name}{\"  \"}{.spec.containers[0].image}{\"  \"}{.status.phase}{\"\\n\"}{end}'"
kubectl -n "$NS" port-forward service/devsecops-python-service 8080:80 >/dev/null 2>&1 &
PF=$!; sleep 4
run 'curl -s http://localhost:8080/health; echo'
kill $PF 2>/dev/null
run "kubectl -n $NS rollout history deployment/devsecops-python"
note 'roll back to the previous version'
run "kubectl -n $NS rollout undo deployment/devsecops-python"
run "kubectl -n $NS rollout status deployment/devsecops-python --timeout=120s"
run "kubectl -n $NS get deployment devsecops-python -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}'"
run "kubectl -n $NS rollout history deployment/devsecops-python"
}

PARTS="${*:-1 2 3 4 5}"
for p in $PARTS; do "part$p"; done
if [ -z "$*" ]; then
  echo "Cleaning up (namespace $NS)..."
  cleanup
fi
echo "Done. Outputs are in $OUTDIR/"
