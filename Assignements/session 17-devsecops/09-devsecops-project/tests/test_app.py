import pytest

from app.app import app, password_strength


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_home_page_has_my_name(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Kiran N" in response.data and b"10446" in response.data
    assert b"Security Gate" in response.data


def test_health(client):
    data = client.get("/health").get_json()
    assert data["status"] == "healthy"
    assert "uptime_seconds" in data


def test_info(client):
    data = client.get("/api/info").get_json()
    assert data["owner"] == "Kiran N"
    assert data["roll_no"] == "10446"
    assert "python" in data


def test_security_headers(client):
    headers = client.get("/health").headers
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert headers["X-Frame-Options"] == "DENY"
    assert "Content-Security-Policy" in headers


@pytest.mark.parametrize("op, expected", [("add", 9), ("subtract", 3), ("multiply", 18), ("divide", 2)])
def test_calculate(client, op, expected):
    response = client.post("/api/calculate", json={"a": 6, "b": 3, "operation": op})
    assert response.status_code == 200
    assert response.get_json()["result"] == expected


def test_calculate_divide_by_zero(client):
    response = client.post("/api/calculate", json={"a": 6, "b": 0, "operation": "divide"})
    assert response.status_code == 400


def test_calculate_bad_input(client):
    assert client.post("/api/calculate", json={"a": 6}).status_code == 400
    assert client.post("/api/calculate", json={"a": "six", "b": 3}).status_code == 400
    assert client.post("/api/calculate", json={"a": 6, "b": 3, "operation": "power"}).status_code == 400
    assert client.post("/api/calculate", data="not json").status_code == 400


def test_password_strength_levels():
    assert password_strength("abc")["strength"] == "weak"
    assert password_strength("abcdefgh1234")["strength"] == "medium"
    assert password_strength("Kiran-N-10446!")["strength"] == "strong"


def test_password_check_endpoint(client):
    response = client.post("/api/password-check", json={"password": "Kiran-N-10446!"})
    assert response.status_code == 200
    assert response.get_json()["score"] == 5
    assert "password" not in response.get_json()
    assert client.post("/api/password-check", json={}).status_code == 400


def test_unknown_route(client):
    assert client.get("/nothing").status_code == 404
