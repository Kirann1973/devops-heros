# GitOps Demo with Argo CD

**Name:** Kiran N | **Roll No:** 10446 | **Session 20 - Task 3**

The Kubernetes manifests in [`app/`](app/) live in my GitHub repository. Argo CD runs inside the cluster, watches that folder and keeps the cluster equal to it. I never run `kubectl apply` on the app; I change Git.

```text
  me ── git commit / push ──▶ GitHub: Kirann1973/devops-heros, branch assignment
                               Assignements/session 20-.../10-gitops-argocd-demo/app/
                                    namespace.yaml  configmap.yaml  deployment.yaml  service.yaml
                                          │  desired state
                                          ▼  (Argo CD polls Git, or a refresh)
                  ┌───────────── Argo CD (namespace argocd) ─────────────┐
                  │ repo-server: reads Git, renders manifests             │
                  │ application-controller: compares desired vs actual    │
                  │   OutOfSync? -> sync (apply)  |  manual change? -> heal│
                  └──────────────────────────┬────────────────────────────┘
                                             ▼ actual state
                    Kubernetes (Minikube), namespace session20
                    Deployment session20-mini (nginx, replicas from Git) + Service + ConfigMap
```

## Files

| File | Purpose |
|---|---|
| [`app/namespace.yaml`](app/namespace.yaml) | Namespace `session20` |
| [`app/configmap.yaml`](app/configmap.yaml) | The web page (my name, roll number, "deployed by Argo CD from Git") |
| [`app/deployment.yaml`](app/deployment.yaml) | nginx:1.27-alpine, **replicas: 2**, readiness/liveness probes, CPU/memory requests and limits |
| [`app/service.yaml`](app/service.yaml) | ClusterIP Service on port 80 |
| [`argocd-application.yaml`](argocd-application.yaml) | The Argo CD `Application`: which repo, branch and folder to watch, where to deploy, and the sync policy. It is **outside** `app/`, so Argo CD does not manage itself |

```yaml
source:
  repoURL: https://github.com/Kirann1973/devops-heros.git
  targetRevision: assignment
  path: Assignements/session 20-monitoring-observability-gitops/10-gitops-argocd-demo/app
syncPolicy:
  automated:
    prune: true      # something deleted from Git is deleted from the cluster
    selfHeal: true   # a manual kubectl change is reverted to what Git says
```

## GitOps concepts

| Concept | Meaning | In this demo |
|---|---|---|
| **What is GitOps?** | Running infrastructure and apps by keeping their full desired state in Git. An agent in the cluster makes reality match Git, continuously | Argo CD + my GitHub repo |
| **Git as the source of truth** | Git is the single place that says what *should* run. Every change is a commit with author, time, message and review, and can be reverted | `replicas: 2 -> 3` is a commit by me; `git revert` would undo it |
| **Declarative configuration** | Describe the **end state** ("3 nginx pods with this page"), not the steps to get there | YAML manifests; no `kubectl scale` scripts |
| **Continuous reconciliation** | A loop: read desired state from Git, read actual state from the cluster, compare, fix the difference. It repeats forever | Argo CD polls Git (default every 3 minutes) and watches the cluster |
| **Desired state** | What Git says | `replicas: 3` in `deployment.yaml` |
| **Actual state** | What is running now | `kubectl get deploy` shows 1/1 right after a manual scale |
| **Drift** | Actual differs from desired | someone ran `kubectl scale --replicas=1` |
| **Self-healing** | Argo CD removes drift automatically (`selfHeal: true`) | back to 3/3 within seconds |
| **Pull model** | The agent in the cluster pulls from Git; CI does not need cluster credentials (more secure than `kubectl apply` from CI) | Argo CD only needs read access to the public repo |

### GitOps workflow

```text
1. Developer changes YAML (or CI updates the image tag) -> pull request
2. Review + merge into the branch Argo CD watches          (Git = audit log, approvals)
3. Argo CD notices the new commit                           (poll / webhook / refresh)
4. Argo CD compares Git with the cluster -> OutOfSync
5. Argo CD syncs: applies the difference                    (prune removes deleted objects)
6. Kubernetes rolls out the change -> Synced + Healthy
7. Anyone changes the cluster by hand -> drift -> Argo CD heals it back
8. Rollback = git revert (Argo CD deploys the previous state)
```

### Kubernetes + GitOps

- Kubernetes is itself declarative and reconciles: a Deployment controller keeps N pods running. GitOps adds **the same loop one level higher**: Git -> cluster.
- CI builds and tests the image and pushes it to a registry. CD becomes "update the tag in Git", and Argo CD (or Flux) does the deploy.
- One Git repo can drive many clusters and environments (dev/stage/prod folders, Kustomize overlays, Helm values), and they all stay consistent.
- Tools: **Argo CD** (UI, Applications, ApplicationSets), **Flux CD** (CLI/controllers, Kustomize/Helm), Jenkins X, Rancher Fleet.

## Run it

```bash
minikube start --driver=docker --cpus=2 --memory=3500    # or: kind create cluster --name session20
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy

kubectl apply -f argocd-application.yaml                  # the only kubectl apply
kubectl get applications -n argocd                       # Synced  Healthy
kubectl get all -n session20                             # 2 pods

# change replicas: 2 -> 3 in app/deployment.yaml, commit, push
kubectl -n argocd annotate application session20-mini argocd.argoproj.io/refresh=hard --overwrite
kubectl get deployment session20-mini -n session20 -w    # 3/3

kubectl scale deployment session20-mini -n session20 --replicas=1   # drift
kubectl get deployment session20-mini -n session20       # back to 3/3 (self-heal)

kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443   # UI: https://<vm-ip>:8080
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

kubectl delete -f argocd-application.yaml                # the finalizer also deletes the app's resources
```

I used Minikube instead of kind, because the earlier sessions on my VM already used it. Argo CD works the same on both.

All steps with my real outputs and screenshots are in [`../resultReadme.md`](../resultReadme.md).
