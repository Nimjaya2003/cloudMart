
import os
import json
import math
import logging

from urllib.request import urlopen
from urllib.error import HTTPError

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def fetch_products():

    base_url = os.environ["CLOUDMART_API_URL"]

    url = (
        base_url.rstrip("/")
        + "/api/catalog/products"
    )

    with urlopen(url, timeout=8) as response:
        data = json.loads(response.read().decode("utf-8"))

    if isinstance(data, dict):
        data = data.get("products")

    if not isinstance(data, list):
        raise ValueError("Unexpected catalog response")

    return data




def search_products(query, max_price=None):

    if not isinstance(query, str):
        raise ValueError("query must be a string")

    query = query.strip().lower()

    if not query or len(query) > 200:
        raise ValueError("Invalid search query")

    if max_price is not None:

        if isinstance(max_price, bool):
            raise ValueError("Invalid maximum price")

        max_price = float(max_price)

        if not math.isfinite(max_price) or max_price < 0:
            raise ValueError("Invalid maximum price")

    products = fetch_products()

    matches = []

    for product in products:

        searchable_text = " ".join([
            str(product.get("name", "")),
            str(product.get("description", "")),
            str(product.get("category", ""))
        ]).lower()

        # Match every word in the search query
        if not all(
            word in searchable_text
            for word in query.split()
        ):
            continue

        price = float(product["price"])

        if max_price is not None and price > max_price:
            continue

        # Return only public catalog fields
        matches.append({
            field: product[field]
            for field in [
                "id",
                "name",
                "description",
                "category",
                "price",
                "stock"
            ]
            if field in product
        })

    return {
        "success": True,
        "count": min(len(matches), 20),
        "products": matches[:20]
    }


def get_product(product_id):

    # Validate the product ID
    if type(product_id) is not int:
        raise ValueError("product_id must be an integer")

    if not 1 <= product_id <= 2147483647:
        raise ValueError("Invalid product ID")

    base_url = os.environ["CLOUDMART_API_URL"]

    url = (
        base_url.rstrip("/")
        + f"/api/catalog/products/{product_id}"
    )

    try:
        with urlopen(url, timeout=8) as response:
            product = json.loads(
                response.read().decode("utf-8")
            )

    except HTTPError as exc:

        if exc.code == 404:
            return {
                "success": False,
                "error": "Product not found"
            }

        raise

    if not isinstance(product, dict):
        raise ValueError("Unexpected catalog response")

    if product.get("id") != product_id:
        raise ValueError("Unexpected product ID")

    # Return only public product fields
    result = {
        field: product[field]
        for field in [
            "id",
            "name",
            "description",
            "category",
            "price",
            "stock"
        ]
        if field in product
    }

    return {
        "success": True,
        "product": result
    }




def lambda_handler(event, context):

    try:

        if not isinstance(event, dict):
            raise ValueError("Invalid event")

        # Identify the tool requested by AgentCore Gateway
        client_context = getattr(
            context, "client_context", None
        )

        custom = getattr(
            client_context, "custom", None
        ) or {}

        full_name = custom.get(
            "bedrockAgentCoreToolName", ""
        )

        if full_name:
            tool_name = full_name.rsplit("___", 1)[-1]

        # Fallback for direct Lambda testing
        elif "product_id" in event and "query" not in event:
            tool_name = "get_product"

        elif "query" in event and "product_id" not in event:
            tool_name = "search_products"

        else:
            raise ValueError("Cannot determine tool")

        logger.info("Executing tool: %s", tool_name)

        if tool_name == "search_products":

            return search_products(
                query=event.get("query", ""),
                max_price=event.get("max_price")
            )

        elif tool_name == "get_product":

            return get_product(
                product_id=event.get("product_id")
            )

        else:
            return {
                "success": False,
                "error": "Unsupported catalog tool"
            }

    except ValueError:

        return {
            "success": False,
            "error": "Invalid parameters or catalog data"
        }

    except Exception:

        logger.exception("Catalog request failed")

        return {
            "success": False,
            "error": "Catalog service is currently unavailable"
        }
