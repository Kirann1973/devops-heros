# Kiran N | Roll No: 10446 - a stand-in for Slack/e-mail/PagerDuty.
# Alertmanager POSTs its notifications here (webhook receiver) and each alert is printed as one log line,
# so "docker compose logs alert-receiver" shows exactly what an on-call engineer would be sent.
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        for a in payload.get("alerts", []):
            labels, notes = a.get("labels", {}), a.get("annotations", {})
            print(f"[{a.get('status', '?').upper():8}] {labels.get('alertname')} severity={labels.get('severity')} "
                  f"since={a.get('startsAt', '')[:19]} - {notes.get('summary', '')}", flush=True)
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print("alert receiver listening on :5001", flush=True)
    HTTPServer(("0.0.0.0", 5001), Handler).serve_forever()
