# Task 3: FQDN in Kubernetes

**Name:** Kiran N | **Roll No.:** 10446 | **Session 11**

Output: [`../outputs/s11-06-fqdn.txt`](../outputs/s11-06-fqdn.txt) · Screenshot: [`../screenshots/s11-06-fqdn.png`](../screenshots/s11-06-fqdn.png)

---

## What is an FQDN?

A **Fully Qualified Domain Name** is the complete DNS name of a host, all the way to the root, with nothing left to guess. `www.google.com.` is an FQDN; `www` alone is not, because the resolver has to add the rest.

## Kubernetes Service DNS

Every Service gets a DNS record from CoreDNS automatically, so pods call `yatri-backend-service` instead of an IP that may change. The record points to the Service's ClusterIP (or to the pod IPs for a headless Service, or to a CNAME for ExternalName).

## Naming convention

```
<service-name>.<namespace>.svc.<cluster-domain>
yatri-backend-service.default.svc.cluster.local
        │              │      │       └── cluster domain (default: cluster.local)
        │              │      └────────── fixed word "svc" = this is a Service
        │              └───────────────── namespace
        └──────────────────────────────── Service name
```

| Record | Format | Example from my run |
|--------|--------|---------------------|
| Service | `<svc>.<ns>.svc.cluster.local` | `yatri-backend-service.default.svc.cluster.local` → 10.106.92.149 |
| Pod behind a headless Service | `<pod>.<svc>.<ns>.svc.cluster.local` | `web-stateful-0.web-service-headless.default.svc.cluster.local` → 10.244.0.161 |
| ExternalName | CNAME | `external-database-service.default.svc.cluster.local` → `api.github.com` |
| API server | `kubernetes.default.svc.cluster.local` | → 10.96.0.1 |

## How short names work: `/etc/resolv.conf`

```
$ kubectl exec curl-test-pod -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

* `nameserver 10.96.0.10` is the `kube-dns` Service (CoreDNS).
* `search` is the list of endings the resolver tries for a short name. The first one contains the pod's **own namespace** (`default`).
* `ndots:5` means: any name with fewer than 5 dots is first tried with the search endings.

So inside namespace `default`, `yatri-backend-service` is tried as `yatri-backend-service.default.svc.cluster.local` first and it works.

## Pod-to-Service communication in the same namespace

All four forms reached the backend from a pod in `default`:

```
$ kubectl exec curl-test-pod -- curl -s http://yatri-backend-service
Backend v1.0.0 listening on port 5000 (Kiran N - 10446)

$ kubectl exec curl-test-pod -- curl -s http://yatri-backend-service.default
Backend v1.0.0 listening on port 5000 (Kiran N - 10446)

$ kubectl exec curl-test-pod -- curl -s http://yatri-backend-service.default.svc
Backend v1.0.0 listening on port 5000 (Kiran N - 10446)

$ kubectl exec curl-test-pod -- curl -s http://yatri-backend-service.default.svc.cluster.local
Backend v1.0.0 listening on port 5000 (Kiran N - 10446)
```

## Namespace-based DNS (cross-namespace)

I created namespace `kiran-dev` and a client pod inside it:

```
$ kubectl exec -n kiran-dev dev-client -- curl -s -m 5 http://yatri-backend-service || echo "curl failed: name not found in kiran-dev"
command terminated with exit code 28
curl failed: name not found in kiran-dev

$ kubectl exec -n kiran-dev dev-client -- curl -s http://yatri-backend-service.default
Backend v1.0.0 listening on port 5000 (Kiran N - 10446)

$ kubectl exec -n kiran-dev dev-client -- curl -s http://yatri-backend-service.default.svc.cluster.local/healthz
{"status":"healthy","service":"yatri-backend"}
```

In `kiran-dev` the search list starts with `kiran-dev.svc.cluster.local`, so the short name became `yatri-backend-service.kiran-dev.svc.cluster.local`, which does not exist. The resolver then tried the other endings and the upstream DNS, and curl gave up after my 5 second limit (exit code 28 = timeout). Adding the namespace (`.default`) fixed it.

**Rule:** same namespace, the short name is enough. Different namespace, use at least `<service>.<namespace>`; in config files use the full FQDN, which is unambiguous and avoids extra search lookups.

## More examples

| From | To | Name to use |
|------|----|-------------|
| Pod in `default` | Service `yatri-backend-service` in `default` | `yatri-backend-service` |
| Pod in `kiran-dev` | same Service | `yatri-backend-service.default` |
| Any pod | Prometheus in `monitoring` | `prometheus.monitoring.svc.cluster.local:9090` |
| Any pod | MySQL primary of a StatefulSet | `mysql-0.mysql.default.svc.cluster.local:3306` |
| Any pod | Kubernetes API | `kubernetes.default.svc.cluster.local:443` |
| Any pod | CoreDNS itself | `kube-dns.kube-system.svc.cluster.local:53` |

---

**Kiran N | Roll No. 10446**
