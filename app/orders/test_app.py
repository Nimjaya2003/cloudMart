from app import app


def test_health():
    resp = app.test_client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_version():
    resp = app.test_client().get("/api/orders/version")
    assert resp.status_code == 200
    assert "version" in resp.get_json()


def test_order_requires_cart_id():
    resp = app.test_client().post("/api/orders", json={})
    assert resp.status_code == 400