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

def test_publish_is_skipped_without_a_topic(monkeypatch):
    import app as orders_app

    monkeypatch.setattr(orders_app, "TOPIC_ARN", None)
    assert orders_app.publish_order_placed(1, "cart-0001-abcd", 1.0, []) is None