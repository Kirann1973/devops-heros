# Kiran N | Roll No: 10446 - used by session20_lab.sh to print the JSON APIs of Prometheus,
# Alertmanager and Jaeger as short tables. Usage: curl ... | python3 lab_helpers.py <command> [arg]
import json
import sys


def query(d):  # Prometheus /api/v1/query
    if d.get("status") != "success":
        print("query error:", d.get("error"))
        return
    if not d["data"]["result"]:
        print("  (no data)")
    for r in d["data"]["result"]:
        m = {k: v for k, v in r["metric"].items() if k not in ("__name__", "job", "instance", "owner")}
        lab = ", ".join(f"{k}={v}" for k, v in sorted(m.items())) or "value"
        print(f"  {lab:<45} {float(r['value'][1]):.4g}")


def targets(d):  # Prometheus /api/v1/targets
    print(f"  {'JOB':<14}{'SCRAPE URL':<38}HEALTH")
    for t in d["data"]["activeTargets"]:
        print(f"  {t['labels']['job']:<14}{t['scrapeUrl']:<38}{t['health']}")


def rules(d):  # Prometheus /api/v1/rules
    print(f"  {'RULE':<20}{'STATE':<10}{'FOR':>5}  QUERY")
    for g in d["data"]["groups"]:
        for r in g["rules"]:
            q = " ".join(r["query"].split())
            print(f"  {r['name']:<20}{r['state']:<10}{int(r.get('duration', 0)):>4}s  {q[:72]}")


def alerts(d):  # Prometheus /api/v1/alerts
    a = sorted(d["data"]["alerts"], key=lambda x: x["labels"]["alertname"])
    if not a:
        print("  (no pending or firing alerts)")
        return
    print(f"  {'ALERT':<20}{'STATE':<10}{'SEVERITY':<10}SUMMARY")
    for x in a:
        print(f"  {x['labels']['alertname']:<20}{x['state']:<10}{x['labels'].get('severity', ''):<10}"
              f"{x['annotations'].get('summary', '')}")


def has_alert(d, name, state):  # exit code 0 if alert <name> is in <state>
    sys.exit(0 if any(x["labels"]["alertname"] == name and x["state"] == state for x in d["data"]["alerts"]) else 1)


def am_alerts(d):  # Alertmanager /api/v2/alerts
    if not d:
        print("  (no alerts)")
    for a in sorted(d, key=lambda a: a["labels"]["alertname"]):
        print(f"  {a['labels']['alertname']:<20}{a['status']['state']:<10}{a['labels'].get('severity', ''):<10}"
              f"since {a['startsAt'][:19]}")


def trace(d):  # Jaeger /api/traces/<id>: one line per span, child spans indented
    t = d["data"][0]
    spans = sorted(t["spans"], key=lambda s: s["startTime"])
    root = spans[0]["startTime"]
    for s in spans:
        tags = {x["key"]: x["value"] for x in s["tags"]}
        indent = "  " if s["references"] else ""
        extra = ", ".join(f"{k}={tags[k]}" for k in ("http.status_code", "error", "error.message", "delay_ms") if k in tags)
        print(f"  {indent + s['operationName']:<28} start +{(s['startTime'] - root) / 1000:6.1f} ms"
              f"  took {s['duration'] / 1000:7.1f} ms  {extra}")


def slowest(d):  # Jaeger /api/traces?service=..: id of the longest trace
    print(max(d["data"], key=lambda t: max(s["duration"] for s in t["spans"]))["traceID"])


def services(d):  # Jaeger /api/services
    print("  services with traces:", ", ".join(d["data"]))


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    raw = sys.stdin.read()
    if cmd == "trace_id":  # last JSON log line on stdin -> its trace_id
        print(json.loads(raw.strip().splitlines()[-1])["trace_id"])
    elif cmd == "has_alert":
        has_alert(json.loads(raw), *args)
    else:
        globals()[cmd](json.loads(raw))
