import os

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)
_table_ready = False


def get_conn():
    # All settings come from environment variables, never hardcoded.
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
            cur.execute(
                """CREATE TABLE IF NOT EXISTS products (
                       id SERIAL PRIMARY KEY,
                       name TEXT NOT NULL,
                       price NUMERIC(10,2) NOT NULL
                   )"""
            )
    finally:
        conn.close()
    _table_ready = True


@app.after_request
def add_cors(resp):
    # Needed only for local testing (frontend on :3000, backend on :8080).
    # Tighten this before production.
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    resp.headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
    return resp


@app.errorhandler(psycopg2.Error)
def db_error(e):
    app.logger.error("Database error: %s", e)
    return jsonify(error="database unavailable"), 503


@app.get("/health")
def health():
    # Deliberately does NOT touch the database (see notes below).
    return jsonify(status="ok"), 200


@app.get("/api/products")
def list_products():
    ensure_table()
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT id, name, price FROM products ORDER BY id")
            rows = cur.fetchall()
    finally:
        conn.close()
    return jsonify([{"id": r[0], "name": r[1], "price": float(r[2])} for r in rows])


@app.post("/api/products")
def add_product():
    data = request.get_json(silent=True) or {}
    name, price = data.get("name"), data.get("price")
    if not name or price is None:
        return jsonify(error="name and price are required"), 400
    ensure_table()
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            # Parameterized query: protects against SQL injection
            cur.execute(
                "INSERT INTO products (name, price) VALUES (%s, %s) RETURNING id",
                (name, price),
            )
            new_id = cur.fetchone()[0]
    finally:
        conn.close()
    return jsonify(id=new_id, name=name, price=price), 201