# Kiran N | Roll No: 10446 - Session 20 demo app
# A small web app with only the Python standard library that produces all three observability signals:
#   metrics -> /metrics in Prometheus text format (requests, errors, latency, CPU, memory)
#   logs    -> one JSON line per request on stdout (docker logs / kubectl logs), with the trace id
#   traces  -> spans sent to Jaeger in Zipkin v2 JSON format (one trace per request, child spans per step)
import json
import os
import queue
import random
import resource
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SERVICE = os.environ.get("SERVICE_NAME", "kiran-app")
VERSION = os.environ.get("APP_VERSION", "1.0.0")
ZIPKIN_URL = os.environ.get("ZIPKIN_URL", "")  # e.g. http://jaeger:9411/api/v2/spans
PORT = int(os.environ.get("PORT", "8000"))
STARTED = time.time()
BUCKETS = (0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5)

lock = threading.Lock()
requests_total = {}  # (method, path, status) -> count
duration_buckets = {}  # path -> [count per bucket]
duration_sum = {}
duration_count = {}
in_flight = 0


def log(level, msg, **fields):
    print(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "level": level,
                      "service": SERVICE, "msg": msg, **fields}), flush=True)


# ---------------------------------------------------------------- tracing (Zipkin v2 JSON -> Jaeger)
spans_out = queue.Queue()


def new_id(n):
    return "%0*x" % (n * 2, random.getrandbits(n * 8))


class Span:
    def __init__(self, trace_id, name, parent=None, kind=None):
        self.trace_id, self.id, self.name, self.parent, self.kind = trace_id, new_id(8), name, parent, kind
        self.tags = {}
        self.start = time.time()

    def child(self, name):
        return Span(self.trace_id, name, parent=self.id)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.finish()

    def finish(self):
        span = {"traceId": self.trace_id, "id": self.id, "name": self.name,
                "timestamp": int(self.start * 1e6), "duration": max(1, int((time.time() - self.start) * 1e6)),
                "localEndpoint": {"serviceName": SERVICE}, "tags": self.tags}
        if self.parent:
            span["parentId"] = self.parent
        if self.kind:
            span["kind"] = self.kind
        if ZIPKIN_URL:
            spans_out.put(span)


def span_sender():
    while True:
        batch = [spans_out.get()]
        time.sleep(0.5)
        while not spans_out.empty():
            batch.append(spans_out.get())
        try:
            req = urllib.request.Request(ZIPKIN_URL, data=json.dumps(batch).encode(),
                                         headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=3).read()
        except Exception as e:  # tracing must never break the app
            log("warn", "could not send spans", error=str(e), spans=len(batch))


# ---------------------------------------------------------------- metrics
def observe(method, path, status, seconds):
    with lock:
        key = (method, path, str(status))
        requests_total[key] = requests_total.get(key, 0) + 1
        b = duration_buckets.setdefault(path, [0] * len(BUCKETS))
        for i, le in enumerate(BUCKETS):
            if seconds <= le:
                b[i] += 1
        duration_sum[path] = duration_sum.get(path, 0) + seconds
        duration_count[path] = duration_count.get(path, 0) + 1


def process_memory_bytes():
    try:
        with open("/proc/self/status") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1]) * 1024
    except OSError:
        pass
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024


def metrics_text():
    ru = resource.getrusage(resource.RUSAGE_SELF)
    out = [
        "# HELP app_info Static information about the app.", "# TYPE app_info gauge",
        f'app_info{{service="{SERVICE}",version="{VERSION}",owner="Kiran N",roll_no="10446"}} 1',
        "# HELP http_requests_total Requests handled, by method, path and status code.",
        "# TYPE http_requests_total counter",
    ]
    with lock:
        for (m, p, s), v in sorted(requests_total.items()):
            out.append(f'http_requests_total{{method="{m}",path="{p}",status="{s}"}} {v}')
        out += ["# HELP http_request_duration_seconds Request latency.",
                "# TYPE http_request_duration_seconds histogram"]
        for p, b in sorted(duration_buckets.items()):
            for le, v in zip(BUCKETS, b):
                out.append(f'http_request_duration_seconds_bucket{{path="{p}",le="{le}"}} {v}')
            out.append(f'http_request_duration_seconds_bucket{{path="{p}",le="+Inf"}} {duration_count[p]}')
            out.append(f'http_request_duration_seconds_sum{{path="{p}"}} {duration_sum[p]:.6f}')
            out.append(f'http_request_duration_seconds_count{{path="{p}"}} {duration_count[p]}')
        inflight = in_flight
    out += [
        "# HELP http_requests_in_flight Requests being handled right now.", "# TYPE http_requests_in_flight gauge",
        f"http_requests_in_flight {inflight}",
        "# HELP process_cpu_seconds_total CPU time used by the app.", "# TYPE process_cpu_seconds_total counter",
        f"process_cpu_seconds_total {ru.ru_utime + ru.ru_stime:.3f}",
        "# HELP process_resident_memory_bytes Memory used by the app.",
        "# TYPE process_resident_memory_bytes gauge",
        f"process_resident_memory_bytes {process_memory_bytes()}",
        "# HELP process_start_time_seconds When the app started.", "# TYPE process_start_time_seconds gauge",
        f"process_start_time_seconds {STARTED:.0f}",
    ]
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- handlers
PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>Session 20 - Kiran N</title></head>
<body style="font-family:system-ui,sans-serif;max-width:700px;margin:40px auto;padding:0 16px">
<h1>Session 20 - Monitoring &amp; Observability demo</h1>
<p>Kiran N | Roll No: 10446 | service <code>{service}</code> v{version}</p>
<p>Endpoints: <a href="/health">/health</a> <a href="/metrics">/metrics</a> <a href="/work">/work</a>
<a href="/slow">/slow</a> <a href="/error">/error</a></p></body></html>"""


def handle(path, span):
    """Returns (status, content type, body). Each step is a child span, so Jaeger shows where time went."""
    if path == "/health":
        return 200, "application/json", json.dumps({"status": "ok", "uptime_seconds": int(time.time() - STARTED)})
    if path == "/metrics":
        return 200, "text/plain; version=0.0.4", metrics_text()
    if path == "/":
        with span.child("load-config"):
            time.sleep(random.uniform(0.002, 0.01))
        with span.child("render-page"):
            body = PAGE.format(service=SERVICE, version=VERSION)
        return 200, "text/html; charset=utf-8", body
    if path == "/work":  # burns CPU for ~0.3 s, used to trigger the CPU alert
        with span.child("cpu-work") as s:
            end, n = time.time() + 0.3, 0
            while time.time() < end:
                n += sum(i * i for i in range(2000))
            s.tags["iterations"] = str(n % 100000)
        return 200, "application/json", json.dumps({"result": "done"})
    if path == "/slow":  # a slow downstream call, visible as a long child span in the trace
        with span.child("call-inventory-service") as s:
            delay = random.uniform(0.8, 1.6)
            time.sleep(delay)
            s.tags["delay_ms"] = str(int(delay * 1000))
        return 200, "application/json", json.dumps({"result": "slow but ok"})
    if path == "/error":  # a failing database call -> HTTP 500
        with span.child("db-query") as s:
            time.sleep(random.uniform(0.01, 0.05))
            s.tags["error"] = "true"
            s.tags["error.message"] = "connection refused: orders-db:5432"
        return 500, "application/json", json.dumps({"error": "database unavailable"})
    return 404, "application/json", json.dumps({"error": "not found"})


class Handler(BaseHTTPRequestHandler):
    server_version = "kiran-app"

    def do_GET(self):
        global in_flight
        path = self.path.split("?")[0]
        start = time.time()
        span = Span(new_id(16), f"GET {path}", kind="SERVER")
        span.tags.update({"http.method": "GET", "http.path": path})
        with lock:
            in_flight += 1
        try:
            status, ctype, body = handle(path, span)
        finally:
            with lock:
                in_flight -= 1
        seconds = time.time() - start
        span.tags["http.status_code"] = str(status)
        if status >= 500:
            span.tags["error"] = "true"
        if path not in ("/metrics", "/health"):  # scrapes and health checks are not traced or logged
            span.finish()
            log("error" if status >= 500 else "info", "request", method="GET", path=path, status=status,
                duration_ms=round(seconds * 1000, 1), trace_id=span.trace_id)
        observe("GET", path if status != 404 else "other", status, seconds)
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Trace-Id", span.trace_id)
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):  # the JSON log line above replaces the default access log
        pass


if __name__ == "__main__":
    if ZIPKIN_URL:
        threading.Thread(target=span_sender, daemon=True).start()
    log("info", "starting", port=PORT, version=VERSION, tracing=ZIPKIN_URL or "off")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
