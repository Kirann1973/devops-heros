#!/bin/bash
# Session 10 - Task 2: Pod lifecycle (Minikube)
# Kiran N | Roll No: 10446
# Run from inside the "session 10" folder, after "minikube start".
# For each YAML: apply -> pod status -> pod details -> logs. Each one is saved to outputs/.

OUTDIR=outputs
mkdir -p "$OUTDIR"
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
# short "kubectl describe": the state fields and the last events
details() {
  kubectl describe pod "$1" | grep -E "^Status:|^ *State:|^ *Reason:|Exit Code:|^ *Ready:|Restart Count:|Liveness:|Readiness:|Startup:"
  echo "Events (last 8):"
  kubectl describe pod "$1" | sed -n '/^Events:/,$p' | tail -n +4 | tail -8
}

kubectl delete -f pod-lifecycle/ --ignore-not-found --grace-period=1 >/dev/null 2>&1
kubectl wait --for=delete pod -l app=lifecycle-lab --timeout=60s >/dev/null 2>&1
L=pod-lifecycle

section s10-lc-01-running "Pod lifecycle 01: Running"
run "kubectl apply -f $L/01-running.yaml"
run 'kubectl wait --for=condition=Ready pod/lifecycle-running --timeout=180s'
run 'kubectl get pod lifecycle-running -o wide'
run 'details lifecycle-running'
run 'kubectl delete pod lifecycle-running'

section s10-lc-02-pending "Pod lifecycle 02: Pending (asks for 9Gi memory, no node has it)"
run "kubectl apply -f $L/02-pending.yaml"
run 'sleep 10'
run 'kubectl get pod lifecycle-pending'
run 'details lifecycle-pending'
run 'kubectl delete pod lifecycle-pending'

section s10-lc-03-succeeded "Pod lifecycle 03: Succeeded (exit 0, restartPolicy Never)"
run "kubectl apply -f $L/03-succeeded.yaml"
run "kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/lifecycle-succeeded --timeout=180s"
run 'kubectl get pod lifecycle-succeeded'
run 'kubectl logs lifecycle-succeeded'
run 'details lifecycle-succeeded'
run 'kubectl delete pod lifecycle-succeeded'

section s10-lc-04-failed "Pod lifecycle 04: Failed (exit 1, restartPolicy Never)"
run "kubectl apply -f $L/04-failed.yaml"
run "kubectl wait --for=jsonpath='{.status.phase}'=Failed pod/lifecycle-failed --timeout=180s"
run 'kubectl get pod lifecycle-failed'
run 'kubectl logs lifecycle-failed'
run 'details lifecycle-failed'
run 'kubectl delete pod lifecycle-failed'

section s10-lc-05-crashloopbackoff "Pod lifecycle 05: CrashLoopBackOff (keeps exiting, restartPolicy Always)"
run "kubectl apply -f $L/05-crashloopbackoff.yaml"
run "kubectl wait --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=CrashLoopBackOff pod/lifecycle-crashloop --timeout=180s"
run 'sleep 20'
run 'kubectl get pod lifecycle-crashloop'
run 'kubectl logs lifecycle-crashloop --previous'
run 'details lifecycle-crashloop'
run 'kubectl delete pod lifecycle-crashloop --grace-period=1'

section s10-lc-06-imagepullbackoff "Pod lifecycle 06: ErrImagePull / ImagePullBackOff (image does not exist)"
run "kubectl apply -f $L/06-imagepullbackoff.yaml"
run "kubectl wait --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}'=ImagePullBackOff pod/lifecycle-image-error --timeout=180s"
run 'kubectl get pod lifecycle-image-error'
run 'details lifecycle-image-error'
run 'kubectl delete pod lifecycle-image-error --grace-period=1'

section s10-lc-07-readiness "Pod lifecycle 07: Readiness probe (Running but not Ready until the probe passes)"
run "kubectl apply -f $L/07-readiness.yaml"
run 'kubectl wait --for=jsonpath="{.status.phase}"=Running pod/lifecycle-readiness --timeout=180s'
run 'kubectl get pod lifecycle-readiness'
run 'sleep 12'
run 'kubectl get pod lifecycle-readiness'
run 'details lifecycle-readiness'
run 'kubectl delete pod lifecycle-readiness'

section s10-lc-08-liveness "Pod lifecycle 08: Liveness probe (health file removed after 20s, kubelet restarts the container)"
run "kubectl apply -f $L/08-liveness.yaml"
run 'kubectl wait --for=condition=Ready pod/lifecycle-liveness --timeout=180s'
run 'kubectl get pod lifecycle-liveness'
run 'sleep 45'
run 'kubectl get pod lifecycle-liveness'
run 'details lifecycle-liveness'
run 'kubectl delete pod lifecycle-liveness --grace-period=1'

section s10-lc-09-startup "Pod lifecycle 09: Startup probe (app needs 30s to start)"
run "kubectl apply -f $L/09-startup.yaml"
run 'kubectl wait --for=jsonpath="{.status.phase}"=Running pod/lifecycle-startup --timeout=180s'
run 'kubectl get pod lifecycle-startup'
run 'kubectl wait --for=condition=Ready pod/lifecycle-startup --timeout=90s'
run 'kubectl get pod lifecycle-startup'
run 'kubectl logs lifecycle-startup'
run 'details lifecycle-startup'
run 'kubectl delete pod lifecycle-startup --grace-period=1'

section s10-lc-10-init-container "Pod lifecycle 10: Init container (runs to completion before the app starts)"
run "kubectl apply -f $L/10-init-container.yaml"
run 'sleep 3'
run 'kubectl get pod lifecycle-init'
run 'kubectl wait --for=condition=Ready pod/lifecycle-init --timeout=180s'
run 'kubectl get pod lifecycle-init'
run 'kubectl logs lifecycle-init -c setup'
run 'details lifecycle-init'
run 'kubectl delete pod lifecycle-init'

section s10-lc-11-multi-container "Pod lifecycle 11: Multi-container pod (app + sidecar)"
run "kubectl apply -f $L/11-multi-container.yaml"
run 'kubectl wait --for=condition=Ready pod/lifecycle-multi-container --timeout=180s'
run 'kubectl get pod lifecycle-multi-container'
run 'kubectl get pod lifecycle-multi-container -o jsonpath="{.spec.containers[*].name}"; echo'
run 'sleep 10'
run 'kubectl logs lifecycle-multi-container -c sidecar'
run 'details lifecycle-multi-container'
run 'kubectl delete pod lifecycle-multi-container --grace-period=1'

section s10-lc-12-termination "Pod lifecycle 12: Graceful termination (SIGTERM, 20s grace period)"
run "kubectl apply -f $L/12-termination.yaml"
run 'kubectl wait --for=condition=Ready pod/lifecycle-termination --timeout=180s'
run 'kubectl get pod lifecycle-termination'
run 'kubectl delete pod lifecycle-termination --wait=false'
run 'sleep 3'
run 'kubectl get pod lifecycle-termination'
run 'kubectl logs lifecycle-termination'
run 'sleep 12'
run 'kubectl get pod lifecycle-termination'

echo "Saved each pod to $OUTDIR/"
