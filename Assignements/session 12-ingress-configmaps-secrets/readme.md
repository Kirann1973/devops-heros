# Session 12 — Ingress, ConfigMaps & Secrets

## Overview

This session covers three important Kubernetes concepts:

- **ConfigMaps** — storing non-sensitive configuration outside container images.
- **Secrets** — storing sensitive information such as passwords and credentials.
- **Ingress** — routing external HTTP/HTTPS traffic to Kubernetes Services.

The session also combines these concepts into a complete Kubernetes application using **Minikube + NGINX Ingress**.

---

# 1. ConfigMap

## What is a ConfigMap?

A ConfigMap stores **non-sensitive configuration data** separately from the application container image.

Instead of hardcoding configuration:

```python
LOG_LEVEL = "DEBUG"
PORT = 5000
DATABASE_HOST = "localhost"
```

we can keep the configuration in Kubernetes:

```text
Application Image
       +
   ConfigMap
       ↓
Application Pod
```

This allows the same container image to be used across environments while changing only the configuration.

### Example Configuration

```yaml
apiVersion: v1
kind: ConfigMap

metadata:
  name: yatri-app-config

data:
  ENVIRONMENT: "production"
  LOG_LEVEL: "INFO"
  PORT: "5000"
  DEFAULT_CURRENCY: "INR"
  MAX_BOOKING_DAYS: "30"
```

### Apply ConfigMap

```bash
kubectl apply -f app-config.yaml
```

### View ConfigMaps

```bash
kubectl get configmaps
```

### Inspect ConfigMap

```bash
kubectl get configmap yatri-app-config -o yaml
```

### Read a Specific Value

```bash
kubectl get configmap yatri-app-config -o jsonpath='{.data.LOG_LEVEL}'
```

Expected output:

```text
INFO
```

### Important Points

- ConfigMaps are intended for **non-sensitive data**.
- Examples include log levels, feature flags, environment names and application configuration.
- ConfigMaps can be consumed as environment variables or mounted as files.
- Updating a ConfigMap does not automatically restart Pods.
- ConfigMaps have a size limit of approximately **1 MiB**.

### ConfigMap Screenshot

![alt text](Screenshots/configmap.png)

---

# 2. Secret

## What is a Secret?

A Kubernetes Secret is used to store **sensitive information**, such as:

- Database passwords
- API tokens
- User credentials
- Certificates

Example:

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: yatri-db-secret

type: Opaque

data:
  POSTGRES_USER: <base64-value>
  POSTGRES_PASSWORD: <base64-value>
  POSTGRES_DB: <base64-value>
```

### Apply Secret

```bash
kubectl apply -f db-secret.yaml
```

### View Secrets

```bash
kubectl get secrets
```

### Inspect Secret

```bash
kubectl get secret yatri-db-secret -o yaml
```

Secret values are displayed as **Base64-encoded values**.

### Base64 Is Encoding, Not Encryption

For example:

```bash
echo -n "yat ri_admin" | base64
```

Output:

```text
eWF0IHJpX2FkbWlu
```

Decode it using:

```bash
echo -n "eWF0IHJpX2FkbWlu" | base64 --decode
```

Output:

```text
yat ri_admin
```

Base64 only changes the representation of the data. It should **not be treated as encryption**.

### Decode a Kubernetes Secret Value

```bash
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

### Secret Screenshot

![alt text](Screenshots/secrets.png)

---

# 3. Ingress

## What is Ingress?

Ingress provides rules for routing **external HTTP/HTTPS traffic** to Kubernetes Services.

Instead of exposing every application separately:

```text
Internet
   |
   +---- Service A
   |
   +---- Service B
   |
   +---- Service C
```

Ingress allows multiple applications to be accessed through a common entry point:

```text
                    Ingress
                      |
             +--------+--------+
             |                 |
          /api/                /
             |                 |
       Backend Service    Frontend Service
```

---

# 4. Ingress vs Ingress Controller

These two terms are related but **not the same thing**.

## Ingress

An **Ingress** is a Kubernetes API resource containing routing rules.

For example:

```text
yatri.local/
       ↓
Frontend Service

yatri.local/api/
       ↓
Backend Service
```

The Ingress resource describes **what routing should happen**.

It does not itself process network traffic.

---

## Ingress Controller

An **Ingress Controller** is the actual component that watches Ingress resources and implements their routing rules.

In this session we use:

```text
NGINX Ingress Controller
```

The controller receives the request and routes it according to the Ingress rules.

---

## Simple Difference

```text
Ingress
   ↓
"Here are the routing rules."

Ingress Controller
   ↓
"I will actually implement those rules."
```

### Analogy

Think of:

```text
Ingress = Traffic Rules
Ingress Controller = Traffic Police
```

The rules describe what should happen.

The controller actually observes traffic and applies those rules.

---

# 5. Creating an Ingress vs Creating an Ingress Controller

These are two separate operations.

## Creating an Ingress Resource

Example:

```bash
kubectl apply -f ingress.yaml
```

This creates an object inside Kubernetes containing routing rules.

Example:

```text
/api/  → yatri-backend-service
/      → yatri-frontend-service
```

By itself, this does **not** provide a component that processes the incoming HTTP traffic.

---

## Creating / Installing an Ingress Controller

The Ingress Controller is the actual software responsible for implementing those rules.

In Minikube, we enabled the NGINX controller using:

```bash
minikube addons enable ingress
```

The controller then runs inside the Kubernetes cluster.

Check it using:

```bash
kubectl get pods -n ingress-nginx
```

The controller must be running for the Ingress rules to actually handle traffic.

---

## How They Work Together

```text
Client
  |
  | HTTP Request
  ↓
NGINX Ingress Controller
  |
  | reads Ingress rules
  ↓
Ingress Resource
  |
  +-----------------------+
  |                       |
  ↓                       ↓
/                       /api/
  |                       |
  ↓                       ↓
Frontend Service       Backend Service
  |                       |
  ↓                       ↓
Frontend Pods          Backend Pods
```

The **Ingress resource defines the desired routing**, while the **Ingress Controller implements it**.

---

# 6. Path-Based Routing

Path-based routing uses the URL path to decide which Service receives the request.

Example:

```text
http://yatri.local/
        ↓
Frontend Service

http://yatri.local/api/
        ↓
Backend Service
```

Conceptually:

```text
yatri.local/
      ↓
Frontend

yatri.local/api/
      ↓
Backend
```

This allows multiple applications to be exposed through the same host.

---

# 7. Complete Session 12 Demo

The `04-full-demo` directory combines:

- ConfigMap
- Secret
- Frontend Deployment
- Backend Deployment
- ClusterIP Services
- NGINX Ingress Controller
- Ingress routing
- Local hostname configuration

Files used:

```text
04-full-demo/
├── README.md
├── backend.yaml
├── configmap.yaml
├── frontend.yaml
├── ingress.yaml
├── secret.yaml
├── run-demo.sh
└── cleanup.sh
```

---

## Step-by-Step Manual Run

### Step 1: Enable the NGINX Ingress Addon on Minikube
```bash
minikube addons enable ingress
```

Wait for the Ingress Controller to become ready:
```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

Expected output:
```text
pod/ingress-nginx-controller-7c6974c4d8-xqzvf condition met
```

### Step 2: Apply the ConfigMap
```bash
kubectl apply -f 04-full-demo/configmap.yaml
```

Verify the stored values:
```bash
kubectl describe configmap yatri-app-config
```

Expected output:
```text
Name:         yatri-app-config
Data
====
DEFAULT_CURRENCY:  INR
ENVIRONMENT:       production
LOG_LEVEL:         INFO
MAX_BOOKING_DAYS:  30
APP_PORT:          5000
```

### Step 3: Apply the Secret
```bash
kubectl apply -f 04-full-demo/secret.yaml
```

Verify (values are masked):
```bash
kubectl describe secret yatri-db-secret
```

Expected output:
```text
Name:         yatri-db-secret
Type:         Opaque

Data
====
POSTGRES_DB:        22 bytes
POSTGRES_PASSWORD:  14 bytes
POSTGRES_USER:      11 bytes
```

### Step 4: Deploy the Frontend
```bash
kubectl apply -f 04-full-demo/frontend.yaml
```

Check pods and service:
```bash
kubectl get pods -l app=yatri-frontend
kubectl get svc yatri-frontend-service
```

Expected:
```text
NAME                             READY   STATUS    RESTARTS   AGE
yatri-frontend-7b69b5b5d7-6k9qh  1/1     Running   0          18s
yatri-frontend-7b69b5b5d7-8mxzt  1/1     Running   0          18s

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
yatri-frontend-service    ClusterIP   10.96.210.51    <none>        80/TCP    20s
```

### Step 5: Deploy the Backend
```bash
kubectl apply -f 04-full-demo/backend.yaml
```

Check pods and service:
```bash
kubectl get pods -l app=yatri-backend
kubectl get svc yatri-backend-service
```

Wait until Running:
```bash
kubectl rollout status deployment/yatri-backend --timeout=90s
```

### Step 6: Apply the Ingress
```bash
kubectl apply -f 04-full-demo/ingress.yaml
```

Inspect routing rules:
```bash
kubectl describe ingress yatri-ingress
```

Expected output (key section):
```text
Name:             yatri-ingress
Namespace:        default
Address:          192.168.49.2
Ingress Class:    nginx

Rules:
  Host        Path              Backends
  ----        ----              --------
  yatri.local
              /api(/|$)(.*)    yatri-backend-service:80
              /                yatri-frontend-service:80
```

### Step 7: Add yatri.local to /etc/hosts
```bash
echo "$(minikube ip)  yatri.local" | sudo tee -a /etc/hosts
```

Verify:
```bash
cat /etc/hosts | grep yatri.local
# Expected: 192.168.49.2  yatri.local
```
![alt text](<Screenshots/Full demo(3).png>)

---

## How to Check the Website

### Test 1: Frontend (at root path /)
Open your browser and visit:
```text
http://yatri.local
```

Or via curl:
```bash
curl http://yatri.local
```

### Test 2: Backend API (at /api/)
```bash
curl http://yatri.local/api/
```

Expected output:
```text
Yatri Backend API
=================
ENVIRONMENT     : production
LOG_LEVEL       : INFO
DEFAULT_CURRENCY: INR
POSTGRES_USER   : yatri_admin
POSTGRES_DB     : yatri_production_db
```

## Decode Secret Password

```bash
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

---

## Full Demo Output

![alt text](<Screenshots/Full demo(1).png>)
---
![alt text](<Screenshots/Full demo(2).png>)

---

# 9. Resource Flow

```text
                         Client
                           |
                           | HTTP
                           ↓
                NGINX Ingress Controller
                           |
                    Ingress Rules
                           |
              +------------+------------+
              |                         |
           /api/                         /
              |                         |
              ↓                         ↓
    Backend ClusterIP          Frontend ClusterIP
         Service                    Service
              |                         |
              ↓                         ↓
       Backend Pods              Frontend Pods
              |
              |
       +------+------+
       |             |
   ConfigMap       Secret
       |             |
       ↓             ↓
  Application      Database
  Configuration   Credentials
```

---

# Key Takeaways

```text
ConfigMap          → Non-sensitive application configuration
Secret             → Sensitive configuration / credentials
Ingress            → Kubernetes resource containing HTTP/HTTPS routing rules
Ingress Controller → Component that implements those routing rules
Path-Based Routing → URL path determines the destination Service
ClusterIP Service  → Internal stable endpoint for Pods
Deployment         → Manages replicated application Pods
```
