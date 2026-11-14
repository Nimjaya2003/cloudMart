import json
import os
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3
import psycopg2
import requests
from botocore.exceptions import BotoCoreError, ClientError
from flask import Flask, jsonify, request

app = Flask(__name__)
_tables_ready = False
SCHEMA_LOCK_ID = 727002

# In AWS these names are resolved by Cloud Map DNS; locally by Docker Compose
CATALOG_URL = os.environ.get("CATALOG_URL", "http://catalog:8080")
CART_URL = os.environ.get("CART_URL", "http://cart:8080")
CART_ID_RE = re.compile(r"^[A-Za-z0-9-]{8,64}$")

# Where to announce orders. Unset on a laptop, so local runs simply skip the announcement.
TOPIC_ARN = os.environ.get("ORDER_EVENTS_TOPIC_ARN")
_sns = None


class UpstreamError(Exception):
    def __init__(self, service, status=None):
        super().__init__(f"{service} failed (status {status})")
        self.service = service
        self.status = status


def get_conn():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "cloudmart"),
        user=os.environ.get("DB_USER", "cloudmart"),
        password=os.environ.get("DB_PASSWORD", ""),
        connect_timeout=3,
    )


def ensure_tables():
    global _tables_ready
    if _tables_ready:
        return
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_xact_lock(%s)", (SCHEMA_LOCK_ID,))
            cur.execute(
                """CREATE TABLE IF NOT EXISTS orders (
                       id SERIAL PRIMARY KEY,
                       cart_id TEXT NOT NULL,
                       total NUMERIC(10,2) NOT NULL,
                       status TEXT NOT NULL DEFAULT 'PLACED',
                       created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                   )"""
            )
            cur.execute(
                """CREATE TABLE IF NOT EXISTS order_items (
                       id SERIAL PRIMARY KEY,
                       order_id INTEGER NOT NULL REFERENCES orders(id),
                       product_id INTEGER NOT NULL,
                       name TEXT NOT NULL,
                       unit_price NUMERIC(10,2) NOT NULL,
                       qty INTEGER NOT NULL
                   )"""
            )
    finally:
        conn.close()
    _tables_ready = True


def call(method, url, service):
    try:
        resp = requests.request(method, url, timeout=3)
    except requests.RequestException as exc:
        raise UpstreamError(service) from exc
    if not resp.ok:
        raise UpstreamError(service, resp.status_code)
    return resp


def publish_order_placed(order_id, cart_id, total, items):
    """Announce a saved order. A failure here is logged, never returned: the order already exists."""
    global _sns
    if not TOPIC_ARN:
        app.logger.info("ORDER_EVENTS_TOPIC_ARN not set, skipping event for order %s", order_id)
        return
    event = {
        "event_type": "OrderPlaced",
        "event_id": str(uuid.uuid4()),  # unique ID, so consumers can detect duplicates
        "occurred_at": datetime.now(timezone.utc).isoformat(),
        "order": {"id": order_id, "cart_id": cart_id, "total": total, "items": items},
    }
    try:
        if _sns is None:
            _sns = boto3.client("sns", region_name=os.environ.get("AWS_REGION", "ap-south-1"))
        _sns.publish(
            TopicArn=TOPIC_ARN,
            Message=json.dumps(event),
            MessageAttributes={"event_type": {"DataType": "String", "StringValue": "OrderPlaced"}},
        )
    except (BotoCoreError, ClientError):
        app.logger.exception("could not publish OrderPlaced for order %s", order_id)


@app.errorhandler(UpstreamError)
def upstream_error(exc):
    app.logger.error("%s", exc)
    return jsonify(error=f"{exc.service} service is unavailable or rejected the request"), 502


@app.errorhandler(psycopg2.Error)
def db_error(e):
    app.logger.error("Database error: %s", e)
    return jsonify(error="database unavailable"), 503


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/orders/version")
def version():
    return jsonify(version=os.environ.get("APP_VERSION", "dev"))


@app.post("/api/orders")
def place_order():
    data = request.get_json(silent=True) or {}
    cart_id = data.get("cart_id")
    if not isinstance(cart_id, str) or not CART_ID_RE.match(cart_id):
        return jsonify(error="a valid cart_id is required"), 400

    # 1. What is in the cart? (ask the cart service)
    cart = call("GET", f"{CART_URL}/api/cart/{cart_id}", "cart").json()
    if not cart["items"]:
        return jsonify(error="cart is empty"), 400

    # 2. What do these products cost right now? (ask the catalog service, never trust the browser)
    lines = []
    total = Decimal("0")
    for item in cart["items"]:
        url = f"{CATALOG_URL}/api/catalog/products/{int(item['product_id'])}"
        product = call("GET", url, "catalog").json()
        unit_price = Decimal(str(product["price"]))
        qty = int(item["qty"])
        total += unit_price * qty
        lines.append((product["id"], product["name"], unit_price, qty))

    # 3. Save the order, copying name and price so later catalog changes cannot rewrite history
    ensure_tables()
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO orders (cart_id, total) VALUES (%s, %s) RETURNING id",
                (cart_id, total),
            )
            order_id = cur.fetchone()[0]
            cur.executemany(
                "INSERT INTO order_items (order_id, product_id, name, unit_price, qty) "
                "VALUES (%s, %s, %s, %s, %s)",
                [(order_id, *line) for line in lines],
            )
    finally:
        conn.close()

    items = [
        {"product_id": pid, "name": name, "unit_price": float(price), "qty": qty}
        for pid, name, price, qty in lines
    ]

    # 4. Empty the cart (best effort)
    try:
        requests.delete(f"{CART_URL}/api/cart/{cart_id}", timeout=3)
    except requests.RequestException:
        app.logger.warning("could not clear cart %s", cart_id)

    # 5. Announce the order to everyone who cares (email today, anything else tomorrow)
    publish_order_placed(order_id, cart_id, float(total), items)

    return jsonify(id=order_id, status="PLACED", total=float(total), items=items), 201


@app.get("/api/orders/<int:order_id>")
def get_order(order_id):
    ensure_tables()
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT id, cart_id, total, status, created_at FROM orders WHERE id = %s", (order_id,))
            order = cur.fetchone()
            if order is None:
                return jsonify(error="order not found"), 404
            cur.execute(
                "SELECT product_id, name, unit_price, qty FROM order_items WHERE order_id = %s ORDER BY id",
                (order_id,),
            )
            items = cur.fetchall()
    finally:
        conn.close()
    return jsonify(
        id=order[0],
        cart_id=order[1],
        total=float(order[2]),
        status=order[3],
        created_at=order[4].isoformat(),
        items=[{"product_id": i[0], "name": i[1], "unit_price": float(i[2]), "qty": i[3]} for i in items],
    )