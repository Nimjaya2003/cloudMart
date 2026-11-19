
import os
import json
import uuid
import boto3

from urllib.request import Request, urlopen
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


REGION = "ap-south-1"

AWS_SESSION = boto3.Session()

ALLOWED_TOOLS = {
    "catalog___search_products",
    "catalog___get_product",
    "orders___get_order_status"
}


def mcp_request(method, params=None):

    gateway_url = os.environ["GATEWAY_URL"]

    payload = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": method
    }

    if params is not None:
        payload["params"] = params

    body = json.dumps(payload).encode("utf-8")

    credentials = AWS_SESSION.get_credentials()

    if credentials is None:
        raise RuntimeError(
            "AWS credentials not found"
        )

    request = AWSRequest(
        method="POST",
        url=gateway_url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
    )

    # Sign the HTTP request using AWS IAM credentials
    SigV4Auth(
        credentials.get_frozen_credentials(),
        "bedrock-agentcore",
        REGION
    ).add_auth(request)

    http_request = Request(
        gateway_url,
        data=body,
        headers=dict(request.headers.items()),
        method="POST"
    )

    with urlopen(http_request, timeout=30) as response:

        result = json.loads(
            response.read().decode("utf-8")
        )

    if "error" in result:
        raise RuntimeError("Gateway request failed")

    return result


def call_gateway_tool(tool_name, arguments):

    # Only our three known Gateway tools are permitted
    if tool_name not in ALLOWED_TOOLS:
        raise ValueError("Unsupported Gateway tool")

    response = mcp_request(
        "tools/call",
        {
            "name": tool_name,
            "arguments": arguments
        }
    )

    result = response["result"]

    if result.get("isError", False):
        raise RuntimeError("MCP execution failed")

    for content in result.get("content", []):

        if content.get("type") == "text":

            parsed = json.loads(content["text"])

            if not isinstance(parsed, dict):
                raise RuntimeError(
                    "Unexpected Gateway result"
                )

            return parsed

    raise RuntimeError(
        "No Gateway tool result found"
    )
