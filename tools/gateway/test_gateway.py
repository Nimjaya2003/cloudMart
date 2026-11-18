
import os
import json
import boto3

from urllib.request import Request, urlopen
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


REGION = "ap-south-1"

GATEWAY_URL = os.environ["GATEWAY_URL"]


def mcp_request(method, params=None):

    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method
    }

    if params is not None:
        payload["params"] = params

    body = json.dumps(payload).encode("utf-8")

    session = boto3.Session()

    credentials = session.get_credentials()

    if credentials is None:
        raise RuntimeError("AWS credentials not found")

    request = AWSRequest(
        method="POST",
        url=GATEWAY_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
    )

    SigV4Auth(
        credentials.get_frozen_credentials(),
        "bedrock-agentcore",
        REGION
    ).add_auth(request)

    http_request = Request(
        GATEWAY_URL,
        data=body,
        headers=dict(request.headers.items()),
        method="POST"
    )

    with urlopen(http_request, timeout=30) as response:

        result = json.loads(
            response.read().decode("utf-8")
        )

    if "error" in result:
        raise RuntimeError(result["error"])

    return result



def call_tool(tool_name, arguments):

    print("\nCalling:", tool_name)
    print("Arguments:", arguments)

    response = mcp_request(
        "tools/call",
        {
            "name": tool_name,
            "arguments": arguments
        }
    )

    result = response["result"]

    if result.get("isError", False):
        raise RuntimeError(
            f"MCP execution failed: {result}"
        )

    # Gateway wraps the Lambda response in a text block
    for content in result.get("content", []):

        if content.get("type") == "text":

            parsed = json.loads(content["text"])

            print(json.dumps(parsed, indent=2))

            return parsed

    raise RuntimeError("No tool response received")


def main():

    print("Discovering Gateway tools...\n")

    response = mcp_request("tools/list")

    tools = response["result"]["tools"]

    tool_names = {
        tool["name"]
        for tool in tools
    }

    for tool in tools:
        print("Tool:", tool["name"])
        print("Description:", tool.get("description"))
        print()

    # Verify that all required tools exist
    required_tools = {
        "catalog___search_products",
        "catalog___get_product",
        "orders___get_order_status"
    }

    missing = required_tools - tool_names

    if missing:
        raise RuntimeError(
            f"Missing Gateway tools: {missing}"
        )

    demo_order_id = int(
        os.environ["DEMO_ORDER_ID"]
    )

    # Test 1: Product search
    search = call_tool(
        "catalog___search_products",
        {
            "query": "boots",
            "max_price": 100
        }
    )

    assert search["success"] is True
    assert search["count"] > 0

    # Test 2: Product details
    product = call_tool(
        "catalog___get_product",
        {
            "product_id": 1
        }
    )

    assert product["success"] is True
    assert product["product"]["id"] == 1

    # Test 3: Permitted demo order
    order = call_tool(
        "orders___get_order_status",
        {
            "order_id": demo_order_id
        }
    )

    assert order["success"] is True
    assert order["order"]["order_id"] == demo_order_id
    assert order["demo_only"] is True

    # Test 4: Unauthorized order
    denied = call_tool(
        "orders___get_order_status",
        {
            "order_id": demo_order_id + 1
        }
    )

    assert denied["success"] is False

    # Test 5: Search with no matches
    empty = call_tool(
        "catalog___search_products",
        {
            "query": "boots",
            "max_price": 10
        }
    )

    assert empty["success"] is True
    assert empty["count"] == 0

    print("\n" + "=" * 50)
    print("CLOUDMART GATEWAY EVALUATION")
    print("=" * 50)
    print("Tools discovered: 3/3")
    print("Tests passed: 5/5")
    print("All Gateway tests completed successfully")


if __name__ == "__main__":
    main()


