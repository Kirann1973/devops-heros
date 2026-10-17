# Python Hello World - Kiran N (Roll No: 10446)
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 5000


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h1>Hello World from Python!</h1><p>Kiran N - Roll No: 10446</p>")


if __name__ == "__main__":
    print(f"Python app listening on port {PORT}", flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
