from app import app


def test_health():
    client = app.test_client()
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_add_product_requires_fields():
    client = app.test_client()
    resp = client.post("/api/products", json={"name": ""})
    assert resp.status_code == 400