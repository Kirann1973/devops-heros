#!/bin/bash
# Session 11 - Kubernetes Services, DNS (FQDN) and CoreDNS (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 11-kubernetes-services" folder, after "minikube start".
# Each part is saved to its own file in outputs/ so it fits in one screenshot.

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }

IP=$(minikube ip)

# clean up anything left from an earlier run
kubectl delete -f 01-clusterip/ -f 02-nodeport/ -f 03-loadbalancer/ -f 04-externalname/ -f 05-headless/ \
  -f deployment/ -f service/ -f dns-test/ -f troubleshooting/ --ignore-not-found >/dev/null 2>&1
kubectl delete namespace kiran-dev --ignore-not-found >/dev/null 2>&1
kubectl wait --for=delete pod --all --timeout=120s >/dev/null 2>&1

# ---------------------------------------------------------------- 1. ClusterIP
section s11-01-clusterip "Service 1: ClusterIP (internal only, port 8080 -> pod port 80)"
run 'kubectl apply -f 01-clusterip/'
run 'kubectl rollout status deployment/web-app-clusterip --timeout=180s'
run 'kubectl wait --for=condition=Ready pod/curl-client --timeout=180s'
run 'kubectl get pods -l app=web-clusterip -o wide'
run 'kubectl get service web-service-clusterip'
run 'kubectl get endpointslices -l kubernetes.io/service-name=web-service-clusterip'
run 'kubectl exec curl-client -- curl -s http://web-service-clusterip:8080'
note '12 requests from inside the cluster: the Service spreads them over the 3 pods'
kubectl exec curl-client -- sh -c 'for i in $(seq 1 12); do curl -s http://web-service-clusterip:8080; done' 2>&1 | sort | uniq -c | tee -a "$OUT"; echo | tee -a "$OUT"
CIP=$(kubectl get svc web-service-clusterip -o jsonpath='{.spec.clusterIP}')
run "curl -s -m 3 http://$CIP:8080 || echo \"curl from the VM to $CIP:8080 failed: ClusterIP is not reachable from outside the cluster\""
run 'kubectl delete -f 01-clusterip/'

# ---------------------------------------------------------------- 2. NodePort
section s11-02-nodeport "Service 2: NodePort (node IP : 30080 from outside the cluster)"
run 'kubectl apply -f 02-nodeport/'
run 'kubectl rollout status deployment/web-app-nodeport --timeout=180s'
sleep 5   # give kube-proxy a moment to add the new pods to the Service
run 'kubectl get pods -l app=web-nodeport -o wide'
run 'kubectl get service web-service-nodeport'
run "curl -s http://$IP:30080"
note "10 requests from the VM to http://$IP:30080"
for i in $(seq 1 10); do curl -s "http://$IP:30080"; done | sort | uniq -c | tee -a "$OUT"; echo | tee -a "$OUT"
run 'minikube service web-service-nodeport --url'
run 'kubectl delete -f 02-nodeport/'

# ---------------------------------------------------------------- 3. LoadBalancer
section s11-03-loadbalancer "Service 3: LoadBalancer (external IP from minikube tunnel)"
run 'kubectl apply -f 03-loadbalancer/'
run 'kubectl rollout status deployment/web-app-loadbalancer --timeout=180s'
sleep 5   # give kube-proxy a moment to add the new pods to the Service
run 'kubectl get service web-service-loadbalancer'
note 'EXTERNAL-IP is <pending>: there is no cloud load balancer yet, so start minikube tunnel'
minikube tunnel >/tmp/s11-tunnel.log 2>&1 &
TPID=$!
for i in $(seq 1 30); do
  LBIP=$(kubectl get svc web-service-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [ -n "$LBIP" ] && break; sleep 2
done
run 'kubectl get service web-service-loadbalancer'
if [ -n "$LBIP" ]; then
  run "curl -s -m 5 http://$LBIP"
  note "10 requests to the external IP http://$LBIP"
  for i in $(seq 1 10); do curl -s -m 5 "http://$LBIP"; done | sort | uniq -c | tee -a "$OUT"; echo | tee -a "$OUT"
else
  note 'tunnel gave no external IP, so use the NodePort that every LoadBalancer Service also gets'
fi
LBPORT=$(kubectl get svc web-service-loadbalancer -o jsonpath='{.spec.ports[0].nodePort}')
run "curl -s http://$IP:$LBPORT"
kill $TPID >/dev/null 2>&1; pkill -f "minikube tunnel" >/dev/null 2>&1; sleep 2
run 'kubectl delete -f 03-loadbalancer/'

# ---------------------------------------------------------------- 4. ExternalName
section s11-04-externalname "Service 4: ExternalName (DNS alias to api.github.com)"
run 'kubectl apply -f 04-externalname/'
run 'kubectl wait --for=condition=Ready pod/dns-test-client --timeout=180s'
run 'kubectl get service external-database-service'
run 'kubectl exec dns-test-client -- nslookup external-database-service.default.svc.cluster.local'
run 'kubectl exec dns-test-client -- curl -s -o /dev/null -w "HTTPS %{http_code} from %{remote_ip}\n" https://api.github.com/zen'
run 'kubectl get endpointslices -l kubernetes.io/service-name=external-database-service'
run 'kubectl delete -f 04-externalname/ --grace-period=1'

# ---------------------------------------------------------------- 5. Headless
section s11-05-headless "Service 5: Headless (clusterIP None, DNS returns every pod IP)"
run 'kubectl apply -f 05-headless/'
run 'kubectl rollout status statefulset/web-stateful --timeout=180s'
run 'kubectl wait --for=condition=Ready pod/headless-dns-client --timeout=180s'
run 'kubectl get pods -l app=web-headless -o wide'
run 'kubectl get service web-service-headless'
run 'kubectl exec headless-dns-client -- nslookup web-service-headless.default.svc.cluster.local'
run 'kubectl exec headless-dns-client -- nslookup web-stateful-0.web-service-headless.default.svc.cluster.local'
run 'kubectl exec headless-dns-client -- curl -s http://web-stateful-0.web-service-headless'
run 'kubectl exec headless-dns-client -- curl -s http://web-stateful-2.web-service-headless'
run 'kubectl delete -f 05-headless/ --grace-period=1'

# ---------------------------------------------------------------- 6. FQDN and namespaces
section s11-06-fqdn "FQDN: <service>.<namespace>.svc.cluster.local and cross-namespace access"
run 'kubectl apply -f deployment/ -f service/clusterip.yaml -f dns-test/'
run 'kubectl rollout status deployment/yatri-backend --timeout=180s'
run 'kubectl wait --for=condition=Ready pod/curl-test-pod --timeout=180s'
run 'kubectl get svc yatri-backend-service'
run 'kubectl exec curl-test-pod -- cat /etc/resolv.conf'
for name in yatri-backend-service yatri-backend-service.default yatri-backend-service.default.svc yatri-backend-service.default.svc.cluster.local; do
  run "kubectl exec curl-test-pod -- curl -s http://$name"
done
run 'kubectl create namespace kiran-dev'
run 'kubectl run dev-client -n kiran-dev --image=curlimages/curl:8.6.0 --restart=Never --command -- sleep 3600'
run 'kubectl wait --for=condition=Ready pod/dev-client -n kiran-dev --timeout=180s'
note 'from namespace kiran-dev the short name does not work, the namespace must be added'
run 'kubectl exec -n kiran-dev dev-client -- curl -s -m 5 http://yatri-backend-service || echo "curl failed: name not found in kiran-dev"'
run 'kubectl exec -n kiran-dev dev-client -- curl -s http://yatri-backend-service.default'
run 'kubectl exec -n kiran-dev dev-client -- curl -s http://yatri-backend-service.default.svc.cluster.local/healthz'
run 'kubectl delete namespace kiran-dev --wait=false'

# ---------------------------------------------------------------- 7. CoreDNS
section s11-07-coredns "CoreDNS: the cluster DNS server"
run 'kubectl get deployment coredns -n kube-system'
run 'kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide'
run 'kubectl get service kube-dns -n kube-system'
run 'kubectl get configmap coredns -n kube-system -o jsonpath="{.data.Corefile}"'
run 'kubectl exec curl-test-pod -- nslookup kubernetes.default.svc.cluster.local'
run 'kubectl exec curl-test-pod -- nslookup yatri-backend-service'
run 'kubectl exec curl-test-pod -- nslookup does-not-exist.default.svc.cluster.local'
run 'kubectl logs -n kube-system -l k8s-app=kube-dns --tail=5'

# ---------------------------------------------------------------- 8. Troubleshooting: Service with no endpoints
section s11-08-troubleshooting "Troubleshooting: Service with empty endpoints (selector mismatch)"
run 'kubectl apply -f troubleshooting/empty-endpoints.yaml'
run 'kubectl get svc broken-backend-service'
run 'kubectl get endpointslices -l kubernetes.io/service-name=broken-backend-service'
run 'kubectl exec curl-test-pod -- curl -s -m 5 http://broken-backend-service || echo "curl failed: no pods behind the Service"'
run 'kubectl get svc broken-backend-service -o jsonpath="{.spec.selector}"; echo'
run 'kubectl get pods -l tier=api --show-labels'
note 'root cause: selector app=wrong-backend-name matches no pod. Fix: point it to app=yatri-backend'
run "kubectl patch svc broken-backend-service -p '{\"spec\":{\"selector\":{\"app\":\"yatri-backend\"}}}'"
run 'kubectl get endpointslices -l kubernetes.io/service-name=broken-backend-service'
run 'kubectl exec curl-test-pod -- curl -s http://broken-backend-service'
run 'kubectl delete -f troubleshooting/ -f service/clusterip.yaml -f deployment/ -f dns-test/ --grace-period=1'

echo "Done. Outputs saved in $OUTDIR/"
