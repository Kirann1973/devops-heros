# Session 17 DevSecOps app - Kiran N | Roll No: 10446
# A small Flask API that the DevSecOps pipeline builds, tests, scans and deploys.
#   GET  /                        -> HTML page
#   GET  /health                  -> {"status": "healthy", ...}   (used by the Kubernetes probes)
#   GET  /api/info                -> app, owner, version, python
#   POST /api/calculate           -> {"a": 6, "b": 3, "operation": "multiply"}
#   POST /api/password-check      -> {"password": "..."}  strength report, the password is never stored or logged
import os
import platform
import re
import sys
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request

OWNER = "Kiran N"
ROLL_NO = "10446"
APP_VERSION = os.environ.get("APP_VERSION", "dev")
STARTED = datetime.now(timezone.utc)

PIPELINE = [
    "Code", "Build", "Unit Test", "SAST", "SCA", "Secret Scan",
    "Docker Build", "Image Scan", "Security Gate", "Push Image", "Deploy to Kubernetes",
]

OPERATIONS = {
    "add": lambda a, b: a + b,
    "subtract": lambda a, b: a - b,
    "multiply": lambda a, b: a * b,
    "divide": lambda a, b: a / b,
}

app = Flask(__name__)


@app.after_request
def security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'self'; style-src 'self' 'unsafe-inline'"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response


@app.route("/")
def home():
    return render_template("index.html", owner=OWNER, roll_no=ROLL_NO, version=APP_VERSION, stages=PIPELINE)


@app.route("/health")
def health():
    uptime = (datetime.now(timezone.utc) - STARTED).total_seconds()
    return jsonify(status="healthy", version=APP_VERSION, uptime_seconds=round(uptime, 1))


@app.route("/api/info")
def info():
    return jsonify(
        app="Session 17 DevSecOps API",
        owner=OWNER,
        roll_no=ROLL_NO,
        version=APP_VERSION,
        python=sys.version.split()[0],
        platform=platform.system(),
        hostname=platform.node(),
    )


@app.route("/api/calculate", methods=["POST"])
def calculate():
    data = request.get_json(silent=True) or {}
    op = data.get("operation", "add")
    if op not in OPERATIONS:
        return jsonify(error=f"unknown operation '{op}'", operations=sorted(OPERATIONS)), 400
    try:
        a, b = float(data["a"]), float(data["b"])
    except KeyError:
        return jsonify(error="fields 'a' and 'b' are required"), 400
    except (TypeError, ValueError):
        return jsonify(error="'a' and 'b' must be numbers"), 400
    if op == "divide" and b == 0:
        return jsonify(error="cannot divide by zero"), 400
    return jsonify(a=a, b=b, operation=op, result=OPERATIONS[op](a, b))


def password_strength(password):
    checks = {
        "length_12_or_more": len(password) >= 12,
        "has_lowercase": bool(re.search(r"[a-z]", password)),
        "has_uppercase": bool(re.search(r"[A-Z]", password)),
        "has_digit": bool(re.search(r"\d", password)),
        "has_symbol": bool(re.search(r"[^A-Za-z0-9]", password)),
    }
    score = sum(checks.values())
    level = "strong" if score == 5 else "medium" if score >= 3 else "weak"
    return {"score": score, "max_score": 5, "strength": level, "checks": checks}


@app.route("/api/password-check", methods=["POST"])
def password_check():
    data = request.get_json(silent=True) or {}
    password = data.get("password")
    if not isinstance(password, str) or not password:
        return jsonify(error="field 'password' is required"), 400
    return jsonify(password_strength(password))


@app.errorhandler(404)
def not_found(_e):
    return jsonify(error="route not found"), 404


if __name__ == "__main__":
    # local run only; the container uses gunicorn. Debug mode stays off (Bandit B201).
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8080")))
