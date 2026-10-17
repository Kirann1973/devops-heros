# Task 4: Ingress vs Ingress Controller

| | |
|---|---|
| **Name** | Kiran N |
| **Roll No.** | 10446 |
| **Session** | 12: Ingress, ConfigMaps and Secrets |

Back to the [session readme](../readme.md).

---

## In one line each

- **Ingress** is a Kubernetes **object** (YAML) that holds routing **rules**: "requests for host `yatri.local` with path `/api` go to `yatri-backend-service`".
- **Ingress Controller** is a **running program** (pods) that reads those rules and actually receives and forwards the traffic, usually a reverse proxy such as NGINX.

A good comparison: the Ingress is the traffic plan written on paper, the Ingress Controller is the traffic police officer who follows it. A plan with no officer does nothing; an officer with no plan sends everyone away.

---

## Side by side

| | Ingress | Ingress Controller |
|---|---|---|
| What it is | API resource (`kind: Ingress`, `networking.k8s.io/v1`) | Deployment / DaemonSet of proxy pods + a Service |
| Where it lives | Stored in etcd, like a ConfigMap | Runs as pods, here in namespace `ingress-nginx` |
| Who writes it | The app team, one per app | The cluster admin, installed once per cluster |
| Contains | Hosts, paths, backend Services, TLS secret, annotations | NGINX / Envoy / HAProxy config generated from all Ingresses |
| Handles traffic? | No, it is only data | Yes, every request goes through it |
| Built into Kubernetes? | Yes, the API type exists in every cluster | No, it must be installed (addon, Helm chart or cloud provider) |
| How they are linked | `spec.ingressClassName: nginx` | Owns the IngressClass `nginx` (controller `k8s.io/ingress-nginx`) |
| My example | [`04-full-demo/ingress.yaml`](../04-full-demo/ingress.yaml) (`yatri-ingress`) | `ingress-nginx-controller-d7cd8c989-kcqrk`, image `controller:v1.15.1` |

---

## Proof from my cluster

### 1. Before the controller: nothing can serve an Ingress

```
$ kubectl get ingressclass
No resources found
```

With no IngressClass there is no controller. An Ingress created now would be stored, but it would never get an ADDRESS and no request would reach the app.

### 2. Installing the controller

```
$ minikube addons enable ingress
  - Using image registry.k8s.io/ingress-nginx/controller:v1.15.1
* The 'ingress' addon is enabled

$ kubectl get pods -n ingress-nginx
NAME                                       READY   STATUS      RESTARTS      AGE
ingress-nginx-admission-create-kl87j       0/1     Completed   0             44s
ingress-nginx-admission-patch-mgt7p        0/1     Completed   2 (37s ago)   44s
ingress-nginx-controller-d7cd8c989-kcqrk   1/1     Running     0             44s

$ kubectl get svc -n ingress-nginx
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.100.95.220   <none>        80:30186/TCP,443:30383/TCP   44s
ingress-nginx-controller-admission   ClusterIP   10.101.102.65   <none>        443/TCP                      44s

$ kubectl get ingressclass
NAME              CONTROLLER             PARAMETERS   AGE
nginx (default)   k8s.io/ingress-nginx   <none>       44s
```

The controller is just pods and a Service, like any other app:

- `ingress-nginx-controller` pod: NGINX plus a small program that watches Ingress objects and rewrites `nginx.conf`.
- `ingress-nginx-controller` Service: how traffic reaches the controller (port 80 and 443 on the node).
- `ingress-nginx-controller-admission`: a validating webhook that rejects a broken Ingress before it is saved. The two `admission-*` Jobs only create its certificate, so `Completed` is correct.

### 3. Controller with no Ingress rules

```
$ curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://192.168.49.2/
HTTP 404
```

The controller is up and answering, but it has no rules, so every request gets its default 404.

### 4. Controller + Ingress

```
$ kubectl get ingress yatri-ingress
NAME            CLASS   HOSTS         ADDRESS        PORTS   AGE
yatri-ingress   nginx   yatri.local   192.168.49.2   80      59s

$ curl -s --resolve yatri.local:80:192.168.49.2 http://yatri.local/
Yatri Frontend | Kiran N - Roll No 10446 | ENVIRONMENT=production | pod: yatri-frontend-5b5b5b7b9f-6tlgx

$ curl -s --resolve yatri.local:80:192.168.49.2 http://yatri.local/api/
Yatri Backend API
Student         : Kiran N - Roll No 10446
...
```

- `CLASS nginx` links my Ingress to the controller.
- `ADDRESS 192.168.49.2` was filled in **by the controller**; that is how you know a controller has picked up an Ingress.
- Now the same port routes by host and path.

Screenshots: [controller](../screenshots/s12-03-ingress-controller.png) and [Ingress demo](../screenshots/s12-04-ingress-demo.png).

---

## Why both are needed

- Kubernetes only defines the Ingress **API**. It does not ship a proxy, because every environment wants a different one (NGINX on-prem, a cloud load balancer on AWS or GCP, Envoy in a service mesh).
- Splitting them lets app teams write simple, portable rules while the platform team chooses and runs the proxy.
- One controller serves **all** Ingresses in the cluster, so 10 apps need 1 entry point instead of 10 LoadBalancer Services.

## Request flow

```
Browser -> http://yatri.local/api/
   -> node 192.168.49.2 port 80 (Service ingress-nginx-controller)
   -> NGINX controller pod
        matches rule: host yatri.local, path /api(/|$)(.*)
        rewrite-target /$2  ->  /
   -> yatri-backend-service (ClusterIP)
   -> backend pod 10.244.0.181:5000 or 10.244.0.182:5000
```

The controller sends traffic straight to the pod IPs it reads from the Service's endpoints (that is why `describe ingress` lists `10.244.0.181:5000,10.244.0.182:5000`).

---

## Examples of Ingress Controllers

| Controller | Notes |
|---|---|
| **ingress-nginx** | Community NGINX controller; the one I used (minikube addon) |
| **NGINX Ingress Controller (F5/NGINX Inc.)** | Different project with its own annotations |
| **Traefik** | Default in k3s; auto-discovery and Let's Encrypt support |
| **HAProxy Ingress** | Very fast, fine-grained load balancing |
| **AWS Load Balancer Controller** | Creates an AWS ALB for each Ingress |
| **GKE Ingress** | Creates a Google Cloud HTTP(S) Load Balancer |
| **Azure Application Gateway Ingress Controller (AGIC)** | Uses Azure Application Gateway |
| **Contour / Emissary / Istio Gateway** | Envoy based |

The same `kind: Ingress` YAML works with any of them; usually only `ingressClassName` and the annotations change.

## Related: Gateway API

Gateway API (`GatewayClass`, `Gateway`, `HTTPRoute`) is the newer Kubernetes standard that follows the same idea, but splits it further: the platform team owns the Gateway (like the controller's entry point) and app teams own HTTPRoutes (like Ingress rules). Most controllers above support it too.
