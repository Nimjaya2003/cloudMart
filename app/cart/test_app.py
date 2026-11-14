from app import app


def test_health():
    resp = app.test_client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_version():
    resp = app.test_client().get("/api/cart/version")
    assert resp.status_code == 200
    assert "version" in resp.get_json()


def test_rejects_bad_cart_id():
    resp = app.test_client().get("/api/cart/bad!id")
    assert resp.status_code == 400


def test_rejects_bad_quantity():
    resp = app.test_client().post("/api/cart/abcdef123456/items", json={"product_id": "1", "qty": 0})
    assert resp.status_code == 400