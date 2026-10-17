# Task 4: CoreDNS

**Name:** Kiran N | **Roll No.:** 10446 | **Session 11**

Output: [`../outputs/s11-07-coredns.txt`](../outputs/s11-07-coredns.txt) · Screenshot: [`../screenshots/s11-07-coredns.png`](../screenshots/s11-07-coredns.png)

> Parts 6 and 8 of my lab were run a second time to fix a timing issue, so the ClusterIP of `yatri-backend-service` here (10.110.175.172, first run) is different from the FQDN page (10.106.92.149, second run).

---

## What is CoreDNS?

CoreDNS is the DNS server that runs inside the cluster. It is a small Go program (a CNCF graduated project) built from **plugins**. In Kubernetes it runs as a Deployment in `kube-system` behind a Service still called `kube-dns` for backward compatibility.

```
$ kubectl get deployment coredns -n kube-system
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
coredns   1/1     1            1           52m

$ kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE
coredns-559f6c778d-x7k6w   1/1     Running   0          52m   10.244.0.2   minikube

$ kubectl get service kube-dns -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   52m
```

Port 53 is DNS (UDP and TCP) and 9153 is its Prometheus metrics.

## Why Kubernetes uses CoreDNS

* Pods and Services are created and deleted all the time, and their IPs change. Something has to turn names into the **current** IPs automatically.
* CoreDNS watches the Kubernetes API, so a new Service gets a DNS record within seconds without anyone editing a file.
* It replaced the older `kube-dns` (dnsmasq + sidecars) in Kubernetes 1.13 because it is one process, faster, and easy to extend with plugins (caching, forwarding, rewrites, metrics).

## How Service discovery works

1. I create a Service; the API server stores it and gives it a ClusterIP.
2. CoreDNS (plugin `kubernetes`) watches Services and EndpointSlices and builds records like `yatri-backend-service.default.svc.cluster.local → 10.110.175.172`.
3. The kubelet writes `/etc/resolv.conf` into every pod with `nameserver 10.96.0.10`, so every pod asks CoreDNS.
4. The pod connects to the returned ClusterIP and kube-proxy forwards it to one of the pods.

## How a DNS query is resolved

```
pod: curl http://yatri-backend-service
  │ 1. resolver adds search domain (ndots:5)  → yatri-backend-service.default.svc.cluster.local
  ▼
kube-dns Service 10.96.0.10:53 → CoreDNS pod 10.244.0.2
  │ 2. kubernetes plugin: cluster.local zone → answer from the Service list
  │    (any other name, e.g. api.github.com → forward plugin → node /etc/resolv.conf → internet DNS)
  ▼
answer 10.110.175.172 → pod connects → kube-proxy → backend pod :5000
```

What I saw with `nslookup`:

```
$ kubectl exec curl-test-pod -- nslookup kubernetes.default.svc.cluster.local
Server:   10.96.0.10
Name:     kubernetes.default.svc.cluster.local
Address:  10.96.0.1

$ kubectl exec curl-test-pod -- nslookup yatri-backend-service
** server can't find yatri-backend-service.cluster.local: NXDOMAIN
Name:     yatri-backend-service.default.svc.cluster.local
Address:  10.110.175.172
** server can't find yatri-backend-service.svc.cluster.local: NXDOMAIN

$ kubectl exec curl-test-pod -- nslookup does-not-exist.default.svc.cluster.local
** server can't find does-not-exist.default.svc.cluster.local: NXDOMAIN
```

The short name was found as `...default.svc.cluster.local`. The NXDOMAIN lines are the **other search endings** busybox `nslookup` also tried (it prints every attempt and exits with code 1); they are normal. A Service that does not exist returns **NXDOMAIN** (no such name).

The CoreDNS log (the `log` plugin) shows the same queries:

```
$ kubectl logs -n kube-system -l k8s-app=kube-dns --tail=5
[INFO] 10.244.0.165:39510 - 41615 "AAAA IN yatri-backend-service.default.svc.cluster.local. udp 65 false 512" NOERROR ...
[INFO] 10.244.0.165:39510 - 44615 "AAAA IN yatri-backend-service.svc.cluster.local. udp 57 false 512" NXDOMAIN ...
[INFO] 10.244.0.165:39510 - 41156 "A IN yatri-backend-service.cluster.local. udp 53 false 512" NXDOMAIN ...
[INFO] 10.244.0.165:39295 - 41728 "A IN does-not-exist.default.svc.cluster.local. udp 58 false 512" NXDOMAIN ...
```

`10.244.0.165` is my `curl-test-pod`; NOERROR = found, NXDOMAIN = not found.

## CoreDNS configuration (Corefile)

The config lives in the ConfigMap `coredns` in `kube-system`:

```
$ kubectl get configmap coredns -n kube-system -o jsonpath="{.data.Corefile}"
.:53 {
    log
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    hosts {
       192.168.49.1 host.minikube.internal
       fallthrough
    }
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30 {
       disable success cluster.local
       disable denial cluster.local
    }
    loop
    reload
    loadbalance
}
```

| Plugin | What it does |
|--------|--------------|
| `.:53` | Serve all zones on port 53 |
| `log` / `errors` | Log every query / log errors (minikube enables `log`, which is why I could see my queries) |
| `health`, `ready` | Liveness (:8080/health) and readiness (:8181/ready) endpoints for the CoreDNS pod's own probes |
| `kubernetes cluster.local ...` | Answer names in `cluster.local` (and reverse lookups) from the Kubernetes API; `pods insecure` allows pod A records; `ttl 30` |
| `prometheus :9153` | Metrics for monitoring |
| `hosts` | Static entry added by minikube: `host.minikube.internal` → my VM (192.168.49.1) |
| `forward . /etc/resolv.conf` | Anything outside the cluster (like `api.github.com`) goes to the node's upstream DNS |
| `cache 30` | Cache answers 30s (not for `cluster.local`, so Service changes show up at once) |
| `loop` | Stop if a forwarding loop is detected |
| `reload` | Re-read the Corefile when the ConfigMap changes (no restart) |
| `loadbalance` | Shuffle the order of A records (round robin), for example the 3 headless pod IPs |

To change it: `kubectl edit configmap coredns -n kube-system` (for example, add a `forward` for a company domain), and `reload` applies it.

## How to troubleshoot DNS issues

| Step | Command | What to look for |
|------|---------|------------------|
| 1. Is CoreDNS running? | `kubectl get pods -n kube-system -l k8s-app=kube-dns` | `Running`, `1/1`, no restarts |
| 2. Does kube-dns have endpoints? | `kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns` | CoreDNS pod IP on port 53 |
| 3. Does the pod use it? | `kubectl exec <pod> -- cat /etc/resolv.conf` | `nameserver 10.96.0.10` and the right `search` line |
| 4. Can the pod resolve? | `kubectl exec <pod> -- nslookup kubernetes.default` | Should return 10.96.0.1 |
| 5. Does the Service exist in that namespace? | `kubectl get svc -n <ns>` | NXDOMAIN usually means wrong name or wrong namespace |
| 6. Read CoreDNS logs | `kubectl logs -n kube-system -l k8s-app=kube-dns` | Errors, `SERVFAIL`, loop detected, upstream timeouts |
| 7. Check the Corefile | `kubectl get cm coredns -n kube-system -o yaml` | Typos, bad `forward` target |
| 8. Name resolves but no answer? | `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` | DNS is fine; the Service has no pods (see [troubleshooting in readme](../readme.md#extra-troubleshooting-a-service-with-empty-endpoints)) |

Common causes: calling a Service in another namespace by its short name (I reproduced this in [FQDN](../fqdn/README.md)), a Service name typo, CoreDNS pods crashing (CrashLoopBackOff because of a forwarding loop), NetworkPolicies blocking UDP 53, or the upstream DNS of the node not working (only external names fail).

---

**Kiran N | Roll No. 10446**
