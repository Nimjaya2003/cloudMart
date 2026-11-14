import os

import psycopg2
from flask import Flask, jsonify, request
from psycopg2 import errors as pg_errors

app = Flask(__name__)
_table_ready = False
SCHEMA_LOCK_ID = 727001  # makes concurrent start-ups create the table one at a time

SEED_PRODUCTS = [
    ("Trail Hiking Boots", "Waterproof leather hiking boots with ankle support and a grippy sole.", 89.99, 40),
    ("Insulated Water Bottle", "750 ml stainless steel bottle that keeps drinks cold for 24 hours.", 24.50, 120),
    ("Lightweight Rain Jacket", "Packable waterproof jacket with taped seams and an adjustable hood.", 64.00, 60),
    ("Merino Wool Socks", "Breathable hiking socks that stay warm when wet.", 14.99, 200),
    ("LED Headlamp", "300-lumen rechargeable headlamp with a red night mode.", 29.90, 80),
]


def get_conn():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ.get("DB_NAME", "cloudmart"),
        user=os.environ.get("DB_USER", "cloudmart"),
        password=os.environ.get("DB_PASSWORD", ""),
        connect_timeout=3,
    )


def ensure_table():
    global _table_ready
    if _table_ready:
        return
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_xact_lock(%s)", (SCHEMA_LOCK_ID,))
            cur.execute(
                """CREATE TABLE IF NOT EXISTS catalog_products (
                       id SERIAL PRIMARY KEY,
                       name TEXT NOT NULL UNIQUE,
                       description TEXT NOT NULL DEFAULT '',
                       price NUMERIC(10,2) NOT NULL,
                       stock INTEGER NOT NULL DEFAULT 0
                   )"""
            )
            cur.executemany(
                "INSERT INTO catalog_products (name, description, price, stock) "
                "VALUES (%s, %s, %s, %s) ON CONFLICT (name) DO NOTHING",
                SEED_PRODUCTS,
            )
    finally:
        conn.close()
    _table_ready = True


def run_query(sql, params=(), fetch="all"):
    ensure_table()
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(sql, params)
            if fetch == "all":
                return cur.fetchall()
            if fetch == "one":
                return cur.fetchone()
            return None
    finally:
        conn.close()


def to_product(row):
    return {"id": row[0], "name": row[1], "description": row[2], "price": float(row[3]), "stock": row[4]}


@app.errorhandler(psycopg2.Error)
def db_error(e):
    app.logger.error("Database error: %s", e)
    return jsonify(error="database unavailable"), 503


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/catalog/version")
def version():
    return jsonify(version=os.environ.get("APP_VERSION", "dev"))


@app.get("/api/catalog/products")
def list_products():
    rows = run_query("SELECT id, name, description, price, stock FROM catalog_products ORDER BY id")
    return jsonify([to_product(r) for r in rows])


@app.get("/api/catalog/products/<int:product_id>")
def get_product(product_id):
    row = run_query(
        "SELECT id, name, description, price, stock FROM catalog_products WHERE id = %s",
        (product_id,),
        fetch="one",
    )
    if row is None:
        return jsonify(error="product not found"), 404
    return jsonify(to_product(row))


@app.post("/api/catalog/products")
def add_product():
    data = request.get_json(silent=True) or {}
    name, price = data.get("name"), data.get("price")
    description, stock = data.get("description", ""), data.get("stock", 0)
    valid = (
        isinstance(name, str) and name.strip()
        and isinstance(price, (int, float)) and not isinstance(price, bool) and price >= 0
        and isinstance(description, str)
        and isinstance(stock, int) and not isinstance(stock, bool) and stock >= 0
    )
    if not valid:
        return jsonify(error="name, price (>= 0), optional description and stock (>= 0) are required"), 400
    try:
        row = run_query(
            "INSERT INTO catalog_products (name, description, price, stock) "
            "VALUES (%s, %s, %s, %s) RETURNING id",
            (name.strip(), description, price, stock),
            fetch="one",
        )
    except pg_errors.UniqueViolation:
        return jsonify(error="a product with that name already exists"), 409
    return jsonify(id=row[0], name=name.strip(), price=price), 201