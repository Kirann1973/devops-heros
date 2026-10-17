#!/bin/bash
# Session 12 - ConfigMaps, Secrets, Ingress and troubleshooting (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 12-ingress-configmaps-secrets" folder, after "minikube start".
# Each part is saved to its own file in outputs/ so it fits in one screenshot.
#   bash session12_lab.sh        -> all parts
#   bash session12_lab.sh 4 5    -> only parts 4 and 5

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }

IP=$(minikube ip)
HOSTARG="--resolve yatri.local:80:$IP"   # same as an /etc/hosts entry "$IP yatri.local", without sudo

cleanup() {
  kubectl delete pod configmap-demo secret-demo db-login-check --ignore-not-found --grace-period=1 >/dev/null 2>&1
  kubectl delete secret db-login-secret --ignore-not-found >/dev/null 2>&1
  bash 04-full-demo/cleanup.sh >/dev/null 2>&1
}

# ---------------------------------------------------------------- 1. ConfigMap
part1() {
section s12-01-configmap "Task 1: ConfigMap - create, inject into a Pod, verify inside the container"
run 'kubectl apply -f 01-configmap/app-config.yaml'
run 'kubectl get configmap yatri-app-config'
run 'kubectl describe configmap yatri-app-config | sed -n "/^Data/,/^Events/p"'
run 'kubectl get configmap yatri-app-config -o jsonpath="{.data.DEFAULT_CURRENCY}"; echo'
run 'kubectl apply -f 01-configmap/configmap-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/configmap-demo --timeout=180s'
run 'kubectl logs configmap-demo'
note 'as environment variables'
run 'kubectl exec configmap-demo -- env | grep -E "ENVIRONMENT|LOG_LEVEL|PORT|CURRENCY|MAX_BOOKING" | sort'
note 'as files in the mounted volume'
run 'kubectl exec configmap-demo -- ls /etc/config'
run 'kubectl exec configmap-demo -- cat /etc/config/LOG_LEVEL; echo'
note 'change LOG_LEVEL to DEBUG: the mounted file updates by itself, the env var keeps the old value'
run "kubectl patch configmap yatri-app-config -p '{\"data\":{\"LOG_LEVEL\":\"DEBUG\"}}'"
for i in $(seq 1 40); do
  V=$(kubectl exec configmap-demo -- cat /etc/config/LOG_LEVEL 2>/dev/null)
  [ "$V" = "DEBUG" ] && break; sleep 3
done
note "file changed after about $((i*3)) seconds"
run 'kubectl exec configmap-demo -- cat /etc/config/LOG_LEVEL; echo'
run 'kubectl exec configmap-demo -- printenv LOG_LEVEL'
run 'kubectl delete pod configmap-demo --grace-period=1'
run 'kubectl delete -f 01-configmap/app-config.yaml'
}

# ---------------------------------------------------------------- 2. Secret
part2() {
section s12-02-secret "Task 2: Secret - create, inject into a Pod, verify, and why it must not go to Git"
note 'encode values with echo -n (plain echo adds a newline)'
run 'echo -n "yatri_admin" | base64'
run 'echo -n "secretpassword" | base64'
run 'kubectl apply -f 02-secret/db-secret.yaml'
run 'kubectl get secret yatri-db-secret'
run 'kubectl describe secret yatri-db-secret | grep -A5 "^Data"'
note 'base64 is NOT encryption: anyone who can read the YAML (or the Git repo) gets the password'
run 'kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_PASSWORD}"; echo'
run 'kubectl get secret yatri-db-secret -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d; echo'
run 'kubectl apply -f 02-secret/secret-pod.yaml'
run 'kubectl wait --for=condition=Ready pod/secret-demo --timeout=180s'
run 'kubectl logs secret-demo'
note 'inside the container the values are already decoded'
run 'kubectl exec secret-demo -- env | grep DB_ | sort'
run 'kubectl exec secret-demo -- ls -l /etc/db-secret/'
run 'kubectl exec secret-demo -- cat /etc/db-secret/POSTGRES_DB; echo'
note 'safer way: create the Secret from the command line, never write the value in a file in Git'
run 'kubectl create secret generic demo-secret --from-literal=API_KEY=kiran-10446-demo --dry-run=client -o yaml'
run 'kubectl delete pod secret-demo --grace-period=1'
run 'kubectl delete -f 02-secret/db-secret.yaml'
}

# ---------------------------------------------------------------- 3. Ingress controller
part3() {
section s12-03-ingress-controller "Task 3 and 4: install the NGINX Ingress Controller"
run 'kubectl get ingressclass'
run 'minikube addons enable ingress'
run 'kubectl wait -n ingress-nginx --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=240s'
run 'kubectl get pods -n ingress-nginx'
run 'kubectl get svc -n ingress-nginx'
run 'kubectl get ingressclass'
run 'kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath="{.spec.template.spec.containers[0].image}"; echo'
note 'no Ingress rules yet: the controller answers every request with 404'
run "curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://$IP/"
}

# ---------------------------------------------------------------- 4. Full demo: ConfigMap + Secret + Ingress
part4() {
section s12-04-ingress-demo "Task 3: Ingress demo - frontend on /, backend on /api (ConfigMap + Secret inside)"
run 'kubectl apply -f 04-full-demo/configmap.yaml -f 04-full-demo/secret.yaml -f 04-full-demo/frontend.yaml -f 04-full-demo/backend.yaml'
run 'kubectl rollout status deployment/yatri-frontend --timeout=180s'
run 'kubectl rollout status deployment/yatri-backend --timeout=180s'
run 'kubectl apply -f 04-full-demo/ingress.yaml'
for i in $(seq 1 40); do
  [ -n "$(kubectl get ingress yatri-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')" ] && break; sleep 3
done
sleep 5
run 'kubectl get pods -l "app in (yatri-frontend,yatri-backend)" -o wide'
run 'kubectl get svc yatri-frontend-service yatri-backend-service'
run 'kubectl get ingress yatri-ingress'
run 'kubectl describe ingress yatri-ingress | sed -n "/^Rules/,/^Annotations/p"'
note "yatri.local -> $IP (minikube ip), where the Ingress Controller listens on port 80"
run "curl -s $HOSTARG http://yatri.local/"
run "curl -s $HOSTARG http://yatri.local/api/"
note '6 requests to / are spread over the 2 frontend pods'
for i in $(seq 1 6); do curl -s $HOSTARG http://yatri.local/; done | sort | uniq -c | tee -a "$OUT"; echo | tee -a "$OUT"
note 'routing is by host name: the bare IP has no rule, so the controller returns 404'
run "curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://$IP/"
run 'kubectl exec deploy/yatri-backend -- env | grep -E "ENVIRONMENT|LOG_LEVEL|CURRENCY|POSTGRES" | sort'
run 'bash 04-full-demo/cleanup.sh'
}

# ---------------------------------------------------------------- 5. Troubleshooting
part5() {
section s12-05-troubleshooting "Task 5: Troubleshooting - login fails because of a hidden newline in the Secret"
note 'BEFORE: apply the broken Secret and the app that logs in with it'
run 'kubectl apply -f troubleshooting/broken-db-secret.yaml -f troubleshooting/db-login-pod.yaml'
run "kubectl wait --for=jsonpath='{.status.phase}'=Failed pod/db-login-check --timeout=120s"
run 'kubectl get pod db-login-check'
run 'kubectl logs db-login-check'
note 'investigate: the user is right, so look at the exact bytes of the password'
run 'kubectl get secret db-login-secret -o jsonpath="{.data.POSTGRES_PASSWORD}"; echo'
run 'kubectl get secret db-login-secret -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d | od -c'
run 'kubectl get secret db-login-secret -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d | wc -c'
note 'root cause: the value was made with echo "secretpassword" | base64, so it ends with \n (15 bytes, not 14)'
note 'fix: recreate the Secret with the exact value (--from-literal adds no newline)'
run 'kubectl create secret generic db-login-secret --from-literal=POSTGRES_USER=yatri_admin --from-literal=POSTGRES_PASSWORD=secretpassword --dry-run=client -o yaml | kubectl apply -f -'
run 'kubectl get secret db-login-secret -o jsonpath="{.data.POSTGRES_PASSWORD}"; echo'
run 'kubectl get secret db-login-secret -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d | wc -c'
note 'AFTER: env vars are read only when a container starts, so recreate the pod'
run 'kubectl delete pod db-login-check --grace-period=1'
run 'kubectl apply -f troubleshooting/db-login-pod.yaml'
run "kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/db-login-check --timeout=120s"
run 'kubectl get pod db-login-check'
run 'kubectl logs db-login-check'
run 'kubectl delete -f troubleshooting/db-login-pod.yaml -f troubleshooting/broken-db-secret.yaml --grace-period=1'
}

PARTS="${*:-1 2 3 4 5}"
[ -z "$*" ] && cleanup
for n in $PARTS; do part$n; done
echo "Done. Outputs saved in $OUTDIR/"
