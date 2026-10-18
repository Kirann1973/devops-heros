# Final Troubleshooting Challenge

**Name:** Kiran N | **Roll No:** 10446 | **Session 21 - Final project, troubleshooting part**

My final project StockPilot ([repo](https://github.com/Kirann1973/stockpilot-devops-capstone)) is deployed on Minikube with its own Helm chart and [`values-lab.yaml`](values-lab.yaml). The release contains:
- Deployments for the backend and frontend, each with 2 replicas, readiness/liveness probes and resource limits
- a Postgres StatefulSet with a PVC
- Services, an Ingress and an HPA
- a Secret and a ConfigMap

Then I break it **six times**, the way real outages happen. For each issue I:
1. identify it
2. investigate the logs and resources
3. find the root cause
4. fix it
5. verify the fix

| # | Issue I introduced | Symptom | Investigation | Root cause | Fix |
|---|---|---|---|---|---|
| 1 | `helm upgrade --set image.tag=v2.0.0` | New pods `ErrImagePull` / `ImagePullBackOff`, old pods still serve | `kubectl get pods`, `kubectl describe pod` (Failed to pull, manifest unknown), `helm history` | The tag was never built or pushed to GHCR | `helm rollback` to the last good revision |
| 2 | `helm upgrade --set postgres.password=...` | New backend pod `CrashLoopBackOff`, restarts climbing | `kubectl logs --previous` (password authentication failed), decode the Secret | The Secret changed, but Postgres keeps the password from its first start | `helm rollback` (real change: `ALTER USER` in Postgres first, then the Secret) |
| 3 | Backend requests 4 CPUs | New pod `Pending` forever | `kubectl describe pod` (FailedScheduling: Insufficient cpu), `kubectl describe node` | The node has only 2 CPUs, so no node can fit the pod | `helm rollback` to requests 100m / limits 500m |
| 4 | `kubectl patch` of the Service selector to `app: stockpilot-api` | Page loads, `/api` returns **503** | `kubectl get endpointslices` (none), `kubectl get svc -o wide`, `kubectl get pods --show-labels` | The selector matches no pod label | `helm rollback` to the same revision. Helm 3's three-way merge restores the live object |
| 5 | Readiness probe path changed to `/healthz` | New pod `Running` but `0/1`, rollout stuck | `kubectl describe pod` (Readiness probe failed: 404), `kubectl exec ... wget` | nginx only answers `/nginx-health` | `kubectl rollout undo` |
| 6 | `BACKEND_URL` points at namespace `stockpilot-prod` | New frontend pod crashes | `kubectl logs` (`host not found in upstream`), `nslookup` from a busybox pod (NXDOMAIN) | **DNS**: the name `<svc>.<namespace>.svc.cluster.local` has the wrong namespace | `kubectl rollout undo` |

What the challenge taught me:
- **A rolling update protects users.** In issues 1, 2, 5 and 6 the broken new pods never became Ready, so the old pods kept serving and the app stayed up.
- **Helm history is a rollback log.** Every bad upgrade was one `helm rollback` away.
- **Pod states point to the cause:**

  | State | Where to look |
  |---|---|
  | `ImagePullBackOff` | image name or tag, registry access |
  | `CrashLoopBackOff` | `kubectl logs --previous` |
  | `Pending` | scheduler events: resources, PVC, taints |
  | `0/1 Running` | probes |
  | `503` from the Ingress | Service endpoints |

- **Manual `kubectl` changes are drift.** The fix is to re-apply what is in Git or Helm, which is what Argo CD does automatically in StockPilot.

Commands, real outputs and screenshots are in [`../resultReadme.md`](../resultReadme.md). The lab is [`../session21_lab.sh`](../session21_lab.sh), parts 9-16.
