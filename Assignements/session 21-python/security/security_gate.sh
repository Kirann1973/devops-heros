#!/bin/bash
# Kiran N | Roll No: 10446 - Session 21: DevSecOps security gate
# Runs every scanner against a repository and its container images, then decides PASS or FAIL.
# One failed check fails the whole gate (exit code 1), which is what stops a CI pipeline before the image push.
#
#   bash security_gate.sh <repo-dir> <image> [image...]
#
#   1. SAST            Bandit      backend Python code, fail on HIGH severity
#   2. SCA (Python)    pip-audit   backend/requirements.txt, fail on any known vulnerability
#   3. SCA (npm)       npm audit   frontend/package-lock.json, fail on HIGH or CRITICAL
#   4. Secret scan     Gitleaks    the whole Git history, fail on any secret
#   5. Image scan      Trivy       each image, fail on HIGH or CRITICAL with a fix available
# All tools run in Docker containers, so only Docker is needed.

REPO=$(cd "$1" && pwd) || { echo "usage: $0 <repo-dir> <image> [image...]"; exit 2; }
shift
IMAGES=("$@")
TOOLS=kiran-sec-tools:1
TRIVY=aquasec/trivy:0.67.2
GITLEAKS=zricethezav/gitleaks:v8.28.0
NODE=node:22-alpine
NET=${DOCKER_NET_OPTS:-}          # extra docker run options (only needed behind a proxy), empty on the VM
set -o pipefail
RESULTS=()
FAILED=0

check() {  # check <name> <command...>: runs the command, records PASS (exit 0) or FAIL
  local name=$1; shift
  echo "---------- $name ----------"
  if "$@"; then RESULTS+=("PASS  $name"); else RESULTS+=("FAIL  $name"); FAILED=$((FAILED + 1)); fi
  echo
}

HERE=$(cd "$(dirname "$0")" && pwd)
docker image inspect $TOOLS >/dev/null 2>&1 || docker build -q -t $TOOLS -f "$HERE/Dockerfile.tools" "$HERE" >/dev/null

sast()      { docker run --rm $NET -v "$REPO:/src:ro" $TOOLS bandit -r backend/app --severity-level high -q \
                -f custom --msg-template '{severity} {test_id} {relpath}:{line} {msg}' && echo "No HIGH severity issues"; }
sca_py()    { docker run --rm $NET -v "$REPO:/src:ro" $TOOLS pip-audit -r backend/requirements.txt --no-deps --disable-pip --progress-spinner off 2>&1 | grep -v '^WARNING' | awk '!seen[$0]++'; }
sca_npm()   { docker run --rm $NET -v "$REPO/frontend:/src:ro" -w /src -e NPM_CONFIG_UPDATE_NOTIFIER=false $NODE npm audit --omit=dev --audit-level=high; }
secrets()   { docker run --rm --user "$(id -u):$(id -g)" -v "$REPO:/repo:ro" $GITLEAKS git /repo --no-banner --no-color --redact -v; }
image()     { docker run --rm $NET -v trivy-cache:/root/.cache $TRIVY image --quiet --scanners vuln \
                --severity HIGH,CRITICAL --ignore-unfixed --format json "$1" | python3 "$HERE/../lab_helpers.py" trivy_image; }

check "SAST: Bandit (Python code)" sast
check "SCA: pip-audit (Python dependencies)" sca_py
check "SCA: npm audit (frontend dependencies)" sca_npm
check "Secret scan: Gitleaks (Git history)" secrets
for img in "${IMAGES[@]}"; do check "Image scan: Trivy $(basename "$img" | cut -c1-40)" image "$img"; done

echo "================ SECURITY GATE ================"
printf '%s\n' "${RESULTS[@]}"
if [ $FAILED -eq 0 ]; then
  echo "GATE PASSED: the image may be pushed and deployed"
else
  echo "GATE FAILED: $FAILED check(s) failed, the pipeline stops here (no push, no deploy)"
fi
exit $((FAILED > 0))
