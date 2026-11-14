import os
import re

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import BotoCoreError, ClientError
from flask import Flask, jsonify, request

app = Flask(__name__)

CART_ID_RE = re.compile(r"^[A-Za-z0-9-]{8,64}$")
_table = None


def ensure_local_table(ddb, name):
    """Only used with DynamoDB Local on a laptop. On AWS, Terraform creates the table."""
    try:
        ddb.create_table(
            TableName=name,
            KeySchema=[
                {"AttributeName": "cart_id", "KeyType": "HASH"},
                {"AttributeName": "product_id", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "cart_id", "AttributeType": "S"},
                {"AttributeName": "product_id", "AttributeType": "S"},
            ],
            BillingMode="PAY_PER_REQUEST",
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] != "ResourceInUseException":
            raise


def get_table():
    global _table
    if _table is None:
        kwargs = {"region_name": os.environ.get("AWS_REGION", "ap-south-1")}
        endpoint = os.environ.get("DYNAMODB_ENDPOINT")
        if endpoint:
            kwargs["endpoint_url"] = endpoint
        ddb = boto3.resource("dynamodb", **kwargs)
        name = os.environ.get("CART_TABLE", "cloudmart-dev-carts")
        if endpoint:
            ensure_local_table(ddb, name)
        _table = ddb.Table(name)
    return _table


def bad_cart_id(cart_id):
    if CART_ID_RE.match(cart_id):
        return None
    return jsonify(error="invalid cart id"), 400


@app.errorhandler(ClientError)
@app.errorhandler(BotoCoreError)
def aws_error(exc):
    app.logger.error("DynamoDB error: %s", exc)
    return jsonify(error="cart storage unavailable"), 503


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/api/cart/version")
def version():
    return jsonify(version=os.environ.get("APP_VERSION", "dev"))


@app.get("/api/cart/<cart_id>")
def get_cart(cart_id):
    err = bad_cart_id(cart_id)
    if err:
        return err
    resp = get_table().query(KeyConditionExpression=Key("cart_id").eq(cart_id))
    items = [{"product_id": i["product_id"], "qty": int(i["qty"])} for i in resp["Items"]]
    return jsonify(cart_id=cart_id, items=items)


@app.post("/api/cart/<cart_id>/items")
def add_item(cart_id):
    err = bad_cart_id(cart_id)
    if err:
        return err
    data = request.get_json(silent=True) or {}
    product_id = str(data.get("product_id", ""))
    qty = data.get("qty", 1)
    if (
        not product_id.isdigit()
        or not isinstance(qty, int)
        or isinstance(qty, bool)
        or not 1 <= qty <= 99
    ):
        return jsonify(error="product_id must be numeric and qty between 1 and 99"), 400
    # ADD is an atomic increment: it creates the line if it does not exist yet
    get_table().update_item(
        Key={"cart_id": cart_id, "product_id": product_id},
        UpdateExpression="ADD qty :q",
        ExpressionAttributeValues={":q": qty},
    )
    return jsonify(cart_id=cart_id, product_id=product_id, added=qty), 201


@app.delete("/api/cart/<cart_id>/items/<product_id>")
def remove_item(cart_id, product_id):
    err = bad_cart_id(cart_id)
    if err:
        return err
    get_table().delete_item(Key={"cart_id": cart_id, "product_id": product_id})
    return "", 204


@app.delete("/api/cart/<cart_id>")
def clear_cart(cart_id):
    err = bad_cart_id(cart_id)
    if err:
        return err
    table = get_table()
    resp = table.query(
        KeyConditionExpression=Key("cart_id").eq(cart_id),
        ProjectionExpression="cart_id, product_id",
    )
    with table.batch_writer() as batch:
        for item in resp["Items"]:
            batch.delete_item(Key={"cart_id": item["cart_id"], "product_id": item["product_id"]})
    return "", 204