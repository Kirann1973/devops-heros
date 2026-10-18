# Monitoring and Observability Demo

**Name:** Kiran N | **Roll No:** 10446 | **Session 20 - Tasks 1 and 2**

One `docker compose up` starts a small web app plus everything needed to watch it. The setup covers:
- **Metrics** with Prometheus, shown in **dashboards** in Grafana.
- **Logs** as JSON lines.
- **Traces** with Jaeger.
- **Alerts** with Prometheus rules and Alertmanager.

The app is written with only the Python standard library, so nothing needs to be built or installed.

## Architecture

```text
                    my browser (Mac)  ->  http://<vm-ip>:3000 Grafana | :9090 Prometheus | :9093 Alertmanager | :16686 Jaeger
                                                     |                       |                       |                 |
  curl / traffic  -->  app :8000  ---- /metrics ---> Prometheus ---- alerts ---> Alertmanager ---> alert-receiver (webhook)
                        |   |                         ^    ^ evaluates alert-rules.yml          (prints FIRING / RESOLVED)
                        |   |                         |    |
                        |   |        node-exporter ---+    +--- Grafana reads Prometheus and Jaeger
                        |   |        (VM CPU, memory, disk)
                        |   +--- spans (Zipkin JSON) ---> Jaeger :9411 (stores traces)
                        +------- JSON logs on stdout ---> docker compose logs app
```

| Service | Image | Job |
|---|---|---|
| `app` | python:3.13-alpine + [`app/app.py`](app/app.py) | Web app with `/`, `/health`, `/metrics`, `/slow`, `/error`, `/work` |
| `prometheus` | prom/prometheus:v3.5.0 | Scrapes metrics every 5 s, stores them, evaluates [alert rules](prometheus/alert-rules.yml) |
| `alertmanager` | prom/alertmanager:v0.28.1 | Groups and routes alerts ([config](alertmanager/alertmanager.yml)) |
| `alert-receiver` | python:3.13-alpine + [`receiver.py`](alert-receiver/receiver.py) | Webhook that prints the notifications (stands in for Slack or e-mail) |
| `node-exporter` | prom/node-exporter:v1.9.1 | CPU, memory, disk and network of the VM |
| `jaeger` | jaegertracing/all-in-one:1.62.0 | Receives and shows traces |
| `grafana` | grafana/grafana:12.1.1 | Dashboard, with data sources and dashboard [provisioned from files](grafana/) |

## Task 1: Monitoring

| What the homework asks | How it is shown here |
|---|---|
| **Metrics** | The app exposes `http_requests_total`, `http_request_duration_seconds` (histogram), `process_cpu_seconds_total`, `process_resident_memory_bytes`, `app_info` on `/metrics`. Prometheus scrapes 5 targets |
| **Logs** | One JSON line per request: time, level, path, status, duration, **trace_id**. Errors use `level: error` |
| **Alerts** | 8 rules: `AppDown`, `HighErrorRate`, `SlowRequests`, `HighAppCPU`, `HighAppMemory`, `HostHighCPU`, `HostHighMemory`, `HostDiskAlmostFull`. Alertmanager sends FIRING and RESOLVED to the webhook |
| **CPU utilization** | App: `rate(process_cpu_seconds_total[1m])`; VM: `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100` |
| **Memory utilization** | App: `process_resident_memory_bytes`; VM: `(1 - MemAvailable / MemTotal) * 100` |
| **Application health** | `/health` endpoint, Docker healthcheck, and `up{job="kiran-app"}` (1 = Prometheus can reach it, 0 = `AppDown`) |

The Grafana dashboard **"Kiran N (10446) - Session 20 Monitoring"** has these panels:
- App health (UP/DOWN), request rate, error rate, p95 latency, firing alerts
- Requests per second by path and status
- Latency p50, p95 and p99
- App CPU, app memory, VM CPU %, VM memory %
- A table of pending and firing alerts

### How an alert works

```text
alert rule (PromQL) true?  --no-->  inactive
        | yes
        v
   pending  (true for less than "for:")      e.g. AppDown: up == 0 for 15s
        | still true after "for:"
        v
   firing  --> Alertmanager --> group, deduplicate, route --> webhook / Slack / e-mail / PagerDuty
        | condition false again
        v
   resolved --> Alertmanager sends a RESOLVED notification (send_resolved: true)
```

## Task 2: Observability

### Monitoring vs observability

- **Monitoring** answers questions you knew to ask in advance: *is the app up, is CPU above 85%, are more than 10% of requests failing?* It uses fixed dashboards and alerts.
- **Observability** is how well you can answer **new** questions from the outside, without shipping new code. For example: *why are only `/slow` requests slow, and which step inside them takes the time?* You get it by collecting rich metrics, logs and traces that can be linked together.
- Monitoring tells you **that** something is wrong. Observability helps you find out **why**.

### The three pillars

| Pillar | What it is | Example from my app | Good for | Tool here |
|---|---|---|---|---|
| **Metrics** | Numbers measured over time, cheap to store, easy to aggregate and alert on | `http_requests_total{path="/error",status="500"} 18`, p95 latency 0.6 s | Trends, dashboards, alerts, capacity | Prometheus + Grafana |
| **Logs** | Timestamped records of single events, with details | `{"level": "error", "path": "/error", "status": 500, "duration_ms": 45.3, "trace_id": "b294..."}` | The exact error message and context of one event | `docker compose logs` (`kubectl logs` on Kubernetes) |
| **Traces** | The path of one request through the system, split into timed **spans** | `GET /slow` 1600 ms, of which `call-inventory-service` 1599 ms | Finding which step or service is slow or failing | Jaeger |

They work best **together**:
1. A **metric** alert fires: `HighErrorRate`.
2. The **logs** show which requests failed, each with its `trace_id`.
3. The **trace** for that id shows the failing step: `db-query`, with `error.message=connection refused`.

The lab script follows exactly this path, from a log line to the trace in Jaeger.

### Why observability is required

- Modern systems have many services, containers and pods that come and go. A single request crosses several of them, so `ssh` into one server and reading one log file no longer works.
- It cuts **MTTD/MTTR** (mean time to detect and to resolve): alerts detect the problem, and logs and traces explain it.
- It shows what users actually experience (latency, errors), which lets you define **SLIs/SLOs** such as "99% of requests under 300 ms".
- It is needed for capacity planning, cost control and verifying deployments: did the new version raise the error rate?

### Common tools

| Area | Tools |
|---|---|
| Metrics | Prometheus, Thanos / Mimir / VictoriaMetrics (long-term storage), CloudWatch, Datadog |
| Dashboards | Grafana, Kibana, CloudWatch dashboards |
| Logs | Loki + Promtail/Alloy, ELK/EFK (Elasticsearch, Logstash/Fluentd/Fluent Bit, Kibana), CloudWatch Logs, Splunk |
| Traces | Jaeger, Grafana Tempo, Zipkin, AWS X-Ray |
| Alerting | Alertmanager, Grafana Alerting, PagerDuty, Opsgenie |
| Standard for collecting everything | **OpenTelemetry** (SDKs + Collector) for metrics, logs and traces |
| All-in-one (SaaS) | Datadog, New Relic, Dynatrace, Elastic Observability |

### Kubernetes observability

| What | Source | How to see it |
|---|---|---|
| Node and pod CPU/memory now | metrics-server | `kubectl top nodes`, `kubectl top pods` (also used by HPA) |
| Container CPU/memory history | cAdvisor (built into kubelet) | Prometheus scrapes it: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes` |
| State of Kubernetes objects | kube-state-metrics | `kube_deployment_status_replicas_available`, `kube_pod_container_status_restarts_total` |
| Nodes | node-exporter (DaemonSet) | the same `node_*` metrics as in this demo |
| App metrics | `/metrics` in the app | found through a **ServiceMonitor / PodMonitor** (Prometheus Operator) or pod annotations |
| Logs | container stdout/stderr on each node | `kubectl logs`; collected by Fluent Bit / Promtail (DaemonSet) into Loki or Elasticsearch |
| Events | Kubernetes API | `kubectl get events`, `kubectl describe pod` (OOMKilled, BackOff, FailedScheduling) |
| Health | liveness, readiness and startup probes | restarts and `READY 0/1` in `kubectl get pods` |
| Traces | OpenTelemetry SDK in the app -> OTel Collector -> Jaeger/Tempo | trace view per request |

Usual install: the **kube-prometheus-stack** Helm chart (Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics) plus Loki for logs and Tempo or Jaeger for traces.

## Run it

```bash
docker compose up -d                       # start everything (first time pulls about 1 GB)
docker compose ps
curl localhost:8000/health
curl localhost:8000/metrics | head
for i in $(seq 50); do curl -s localhost:8000/ >/dev/null; curl -s localhost:8000/error >/dev/null; done
curl -s --get localhost:9090/api/v1/query --data-urlencode 'query=rate(http_requests_total[1m])'
docker compose logs app --tail 5           # logs
docker compose stop app                    # AppDown fires after 15 s
docker compose logs alert-receiver         # FIRING / RESOLVED notifications
docker compose start app
docker compose down
```

Open from the Mac:
- **Grafana:** `http://<vm-ip>:3000` (anonymous viewer, or admin / session20)
- **Prometheus:** `http://<vm-ip>:9090`
- **Alertmanager:** `http://<vm-ip>:9093`
- **Jaeger:** `http://<vm-ip>:16686`

All steps with my real outputs and screenshots are in [`../resultReadme.md`](../resultReadme.md).
