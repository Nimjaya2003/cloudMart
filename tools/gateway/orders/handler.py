
import os
import json
import logging

from urllib.request import urlopen
from urllib.error import HTTPError


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_order_status(order_id):

    # 1. Validate the input
    if type(order_id) is not int:
        raise ValueError("order_id must be an integer")

    if not 1 <= order_id <= 2147483647:
        raise ValueError("Invalid order ID")

    # 2. Read permitted demo identifiers
    allowed_order_id = int(
        os.environ["DEMO_ORDER_ID"]
    )

    allowed_cart_id = os.environ["DEMO_CART_ID"]

    # 3. Reject unauthorized order IDs
    # before making any HTTP request
    if order_id != allowed_order_id:

        logger.warning("Order lookup denied")

        return {
            "success": False,
            "error": "Order not found or access denied"
        }

    # 4. Construct the Orders API route
    base_url = os.environ["CLOUDMART_API_URL"]

    url = (
        base_url.rstrip("/")
        + f"/api/orders/{order_id}"
    )

    # 5. Fetch the live order
    try:

        with urlopen(url, timeout=8) as response:

            order = json.loads(
                response.read().decode("utf-8")
            )

    except HTTPError as exc:

        if exc.code == 404:
            return {
                "success": False,
                "error": "Order not found or access denied"
            }

        raise

    # 6. Validate the response
    if not isinstance(order, dict):
        raise ValueError("Unexpected order response")

    # Verify that the returned order is our demo order
    if (
        order.get("id") != allowed_order_id
        or order.get("cart_id") != allowed_cart_id
    ):

        logger.warning("Demo order validation failed")

        return {
            "success": False,
            "error": "Order not found or access denied"
        }

    # 7. Return only the necessary information
    return {
        "success": True,
        "demo_only": True,
        "order": {
            "order_id": order["id"],
            "status": order["status"]
        }
    }


def lambda_handler(event, context):

    try:

        if not isinstance(event, dict):
            raise ValueError("Invalid event")

        result = get_order_status(
            order_id=event.get("order_id")
        )

        logger.info(
            "Order status request completed: success=%s",
            result["success"]
        )

        return result

    except ValueError:

        return {
            "success": False,
            "error": "Invalid order parameters or configuration"
        }

    except Exception:

        logger.exception("Orders service request failed")

        return {
            "success": False,
            "error": "Orders service is currently unavailable"
        }
