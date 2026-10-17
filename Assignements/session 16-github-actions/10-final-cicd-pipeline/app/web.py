# Session 16 calculator web app - Kiran N | Roll No: 10446
# Standard library only, so the Docker image needs no pip install.
#   GET /                      -> HTML page
#   GET /health                -> {"status": "ok"}
#   GET /api/<op>?a=10&b=5     -> {"op": "add", "a": 10.0, "b": 5.0, "result": 15.0}   (op: add, subtract, multiply, divide)
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from app.calculator import add, divide, multiply, subtract

OWNER = "Kiran N - Roll No 10446"
VERSION = os.environ.get("APP_VERSION", "dev")
OPERATIONS = {"add": add, "subtract": subtract, "multiply": multiply, "divide": divide}


def calculate(op, a, b):
    """Return (status code, body dict) for /api/<op>."""
    if op not in OPERATIONS:
        return 404, {"error": f"unknown operation '{op}'", "operations": sorted(OPERATIONS)}
    try:
        a, b = float(a), float(b)
    except (TypeError, ValueError):
        return 400, {"error": "a and b must be numbers"}
    try:
        return 200, {"op": op, "a": a, "b": b, "result": OPERATIONS[op](a, b)}
    except ValueError as e:
        return 400, {"error": str(e)}


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, content_type="application/json"):
        data = body.encode() if isinstance(body, str) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/health":
            self._send(200, {"status": "ok", "version": VERSION})
        elif url.path.startswith("/api/"):
            q = parse_qs(url.query)
            code, body = calculate(url.path[len("/api/"):], q.get("a", [None])[0], q.get("b", [None])[0])
            self._send(code, body)
        elif url.path == "/":
            self._send(200, (
                "<html><head><title>Session 16 Calculator</title></head><body>"
                f"<h1>Session 16 Calculator</h1><p>Built and shipped by GitHub Actions for {OWNER}</p>"
                f"<p>Version: {VERSION}</p><p>Try <code>/api/add?a=10&amp;b=5</code></p></body></html>"
            ), "text/html")
        else:
            self._send(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}", flush=True)


def main():
    port = int(os.environ.get("PORT", "8000"))
    print(f"Session 16 calculator ({OWNER}) version {VERSION} listening on :{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
