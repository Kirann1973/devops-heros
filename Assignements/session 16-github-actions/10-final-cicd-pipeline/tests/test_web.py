import json
import os
import sys
import threading
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest
from app.web import Handler, calculate


@pytest.fixture(scope="module")
def base_url():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()


def get(url):
    try:
        with urllib.request.urlopen(url) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def test_calculate_add():
    assert calculate("add", "10", "5") == (200, {"op": "add", "a": 10.0, "b": 5.0, "result": 15.0})


def test_calculate_divide_by_zero():
    assert calculate("divide", "1", "0") == (400, {"error": "Cannot divide by zero"})


def test_calculate_bad_input():
    assert calculate("add", "ten", "5")[0] == 400
    assert calculate("power", "2", "3")[0] == 404


def test_health(base_url):
    code, body = get(base_url + "/health")
    assert code == 200 and json.loads(body)["status"] == "ok"


def test_home_page_has_my_name(base_url):
    code, body = get(base_url + "/")
    assert code == 200 and "Kiran N - Roll No 10446" in body


def test_api_multiply(base_url):
    code, body = get(base_url + "/api/multiply?a=10&b=5")
    assert code == 200 and json.loads(body)["result"] == 50


def test_unknown_path(base_url):
    assert get(base_url + "/nothing")[0] == 404
