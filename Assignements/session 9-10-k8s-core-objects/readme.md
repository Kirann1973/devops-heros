# ☸️ Session 9–10 — Kubernetes Deployment Strategies

---

## 📌 Overview

This session covers three important **Kubernetes deployment strategies** — Blue-Green, Canary, and Recreate. Each strategy is implemented using Kubernetes Deployments and Services, and tested on **Minikube**.

> **Name:** Kiran N
> **Roll No.:** 24bcs10446
> **Session:** 9–10 — Kubernetes Core Objects & Deployment Strategies

---

## 🛠️ Commands & Concepts Used

| Command / Concept                        | Description                                              |
|------------------------------------------|----------------------------------------------------------|
| `kubectl apply -f`                       | Create or update resources from a YAML file              |
| `kubectl get pods --show-labels`         | List pods with their labels                              |
| `kubectl scale deployment`               | Scale replicas up or down                                |
| `kubectl rollout status`                 | Check the rollout status of a deployment                 |
| `kubectl rollout undo`                   | Rollback a deployment to the previous revision           |
| `kubectl delete -f`                      | Delete resources defined in a YAML file                  |
| `minikube service --url`                 | Get the externally accessible URL for a service          |
| Blue-Green Deployment                    | Instant traffic switch between two identical environments|
| Canary Deployment                        | Gradual rollout to a subset of users                     |
| Recreate Deployment                      | Full shutdown of v1 before starting v2                   |

---

## 📊 Strategy Comparison

| Strategy       | Downtime | Resource Cost       | Rollback Speed | Best Use Case                        |
|----------------|----------|---------------------|----------------|--------------------------------------|
| Rolling Update | No       | Low                 | Fast           | Stateless applications               |
| Blue-Green     | No       | High (2× resources) | Instant        | Critical production releases         |
| Canary         | No       | Low                 | Fast           | Gradual production validation        |
| Recreate       | Yes      | Lowest              | Moderate       | Database migrations, RWO volumes     |

---

## 1️⃣ Blue-Green Deployment

### What is Blue-Green Deployment?

Blue-Green Deployment maintains two identical production environments:

- **Blue** = Current live version
- **Green** = New version being prepared

Traffic is switched instantly by changing the Kubernetes Service selector.

---

### Architecture

```text
Users
   |
   v
[Service]
   |
   +----> BLUE (v1)   <-- LIVE
   |
   +----> GREEN (v2)  <-- STANDBY
```

After switch:

```text
Users
   |
   v
[Service]
   |
   +----> GREEN (v2)  <-- LIVE
   |
   +----> BLUE (v1)   <-- STANDBY
```

---

### Step 1 — Deploy Blue and Green Environments

```bash
kubectl apply -f 02-blue-green/deployment-blue.yaml
kubectl apply -f 02-blue-green/deployment-green.yaml

kubectl get pods -l app=myapp --show-labels
```

---

### Step 2 — Make BLUE Live

```bash
kubectl apply -f 02-blue-green/service-blue.yaml

minikube service myapp-service --url
```

**Result:** BLUE environment becomes active.

![Blue-Green Step 1](Screenshots/blue-green(1).png)

---

### Step 3 — Switch Traffic to GREEN

```bash
kubectl apply -f 02-blue-green/service-green.yaml

minikube service myapp-service --url
```

**Result:** Traffic is instantly redirected to GREEN.

![Blue-Green Step 2](Screenshots/blue-green(2).png)

---

### Step 4 — Rollback to BLUE

```bash
kubectl apply -f 02-blue-green/service-blue.yaml
```

**Result:** Traffic instantly returns to BLUE.

![Blue-Green Rollback](Screenshots/blue-green(3).png)

---

### Cleanup

```bash
kubectl delete -f 02-blue-green/service-blue.yaml
kubectl delete -f 02-blue-green/deployment-blue.yaml
kubectl delete -f 02-blue-green/deployment-green.yaml
```

---

## 2️⃣ Canary Deployment

### What is Canary Deployment?

Canary Deployment releases a new version to a small percentage of users before full rollout.

```text
9 Stable Pods (v1)
1 Canary Pod  (v2)

≈ 90% traffic → Stable
≈ 10% traffic → Canary
```

---

### Architecture

```text
                    [SERVICE]
                         |
                         |
        +----------------+----------------+
        |                |                |
        v                v                v
    Stable v1       Stable v1       Canary v2

Traffic Distribution:
90% -> Stable (v1)
10% -> Canary (v2)
```

---

### Step 1 — Deploy Stable Version

```bash
kubectl apply -f 03-canary/deployment-stable.yaml

kubectl rollout status deployment/app-stable

kubectl apply -f 03-canary/service.yaml
```

---

### Step 2 — Deploy Canary Version

```bash
kubectl apply -f 03-canary/deployment-canary.yaml

kubectl get pods -l app=myapp-canary --show-labels
```

![Canary Step 1](Screenshots/canary(1).png)

---

### Step 3 — Increase Canary Traffic

```bash
kubectl scale deployment app-canary --replicas=3

kubectl scale deployment app-stable --replicas=7

kubectl get endpoints myapp-canary-service
```

**Result:** Traffic distribution becomes approximately **70% Stable / 30% Canary**.

![Canary Step 2](Screenshots/canary(2).png)

---

### Step 4 — Promote Canary to Production

```bash
kubectl scale deployment app-canary --replicas=9

kubectl scale deployment app-stable --replicas=0
```

Remove old Stable deployment:

```bash
kubectl delete deployment app-stable
```

---

### Rollback Canary

```bash
kubectl scale deployment app-canary --replicas=0

kubectl scale deployment app-stable --replicas=9
```

---

### Cleanup

```bash
kubectl delete -f 03-canary/service.yaml
kubectl delete -f 03-canary/deployment-canary.yaml
kubectl delete -f 03-canary/deployment-stable.yaml
```

---

## 3️⃣ Recreate Deployment

### What is Recreate Deployment?

Recreate Deployment completely shuts down the old version before starting the new version.

```text
[v1] [v1] [v1]
      |
      v
All Pods Terminated
      |
      v
*** DOWNTIME ***
      |
      v
[v2] [v2] [v2]
```

---

### Step 1 — Deploy Version 1

```bash
kubectl apply -f 04-recreate/deployment-v1.yaml

kubectl apply -f 04-recreate/service.yaml

kubectl get pods -l app=app-recreate
```

---

### Step 2 — Verify Service

```bash
minikube service app-recreate-service --url
```

![Recreate Step 1](Screenshots/recreate(1).png)

---

### Step 3 — Trigger Recreate Update

**Terminal 1** — Watch pods:

```bash
kubectl get pods -l app=app-recreate -w
```

**Terminal 2** — Apply v2:

```bash
kubectl apply -f 04-recreate/deployment-v2.yaml
```

![Recreate Step 2](Screenshots/recreate(2).png)

![Recreate Step 3](Screenshots/recreate(3).png)

**Observations:**

- Existing v1 pods terminate first.
- No pods are available temporarily (**downtime window**).
- New v2 pods are created afterward.

---

### Step 4 — Verify Version 2

```bash
minikube service app-recreate-service --url
```

![Recreate Step 4](Screenshots/recreate(4).png)

---

### Rollback

```bash
kubectl rollout undo deployment/app-recreate

kubectl rollout status deployment/app-recreate
```

**Output:**

```text
deployment.apps/app-recreate rolled back
deployment "app-recreate" successfully rolled out
```

![Recreate Rollback](Screenshots/recreate(5).png)

---

### Cleanup

```bash
kubectl delete -f 04-recreate/service.yaml
kubectl delete -f 04-recreate/deployment-v2.yaml
```

---

## 📝 Key Learnings

### Blue-Green Deployment

| ✅ Advantages                                      | ❌ Disadvantages                    |
|----------------------------------------------------|------------------------------------|
| Zero downtime deployment                           | Requires double infrastructure     |
| Instant rollback                                   | Higher resource consumption        |
| Complete production testing before cutover          |                                    |

### Canary Deployment

| ✅ Advantages                                      | ❌ Disadvantages                           |
|----------------------------------------------------|-------------------------------------------|
| Gradual rollout                                    | Traffic distribution is approximate       |
| Real user validation                               | Requires monitoring and metrics           |
| Reduced production risk                            |                                           |

### Recreate Deployment

| ✅ Advantages                                      | ❌ Disadvantages                              |
|----------------------------------------------------|----------------------------------------------|
| Simple deployment process                          | Causes downtime                              |
| Useful for schema migrations                       | Not suitable for highly available apps       |
| Works with ReadWriteOnce volumes                   |                                              |

---

## 🏁 Conclusion

This project demonstrates three widely used Kubernetes deployment strategies:

- **Blue-Green Deployment** — for instant switching and rollback.
- **Canary Deployment** — for gradual and controlled releases.
- **Recreate Deployment** — for applications that cannot run multiple versions simultaneously.

Understanding these strategies helps DevOps engineers choose the appropriate deployment model based on availability requirements, rollback needs, infrastructure costs, and application architecture.

---

## ✍️ Author

**Kiran N**
**Roll No.:** 24bcs10446
