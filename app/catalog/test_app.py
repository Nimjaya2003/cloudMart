from app import app


def test_health():
    resp = app.test_client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_version():
    resp = app.test_client().get("/api/catalog/version")
    assert resp.status_code == 200
    assert "version" in resp.get_json()


def test_create_product_requires_fields():
    resp = app.test_client().post("/api/catalog/products", json={"name": ""})
    assert resp.status_code == 400