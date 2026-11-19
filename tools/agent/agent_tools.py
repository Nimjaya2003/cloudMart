
import sys
import math
from pathlib import Path

from gateway_client import call_gateway_tool


# Import our existing Phase 8 retrieval function
KB_DIR = Path(__file__).resolve().parents[1] / "kb"

sys.path.insert(0, str(KB_DIR))

from ask import retrieve


# =============================================
# 1. Create function schemas for Groq
# =============================================

def tool_schema(name, description, properties, required):

    return {
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": {
                "type": "object",
                "properties": properties,
                "required": required,
                "additionalProperties": False
            }
        }
    }


TOOLS = [

    tool_schema(
        "search_knowledge_base",
        "Retrieve CloudMart policies, FAQs, shipping "
        "information, warranties and product guides. "
        "Do not use for live prices or stock.",
        {
            "question": {
                "type": "string",
                "description": (
                    "Question about CloudMart knowledge"
                )
            }
        },
        ["question"]
    ),

    tool_schema(
        "search_products",
        "Search live CloudMart products by keywords "
        "and optional maximum price in USD.",
        {
            "query": {
                "type": "string",
                "description": (
                    "Short product keywords, such as boots"
                )
            },
            "max_price": {
                "type": "number",
                "description": "Maximum price in USD"
            }
        },
        ["query"]
    ),

    tool_schema(
        "get_product",
        "Retrieve current price, description and stock "
        "for a specific product using its product ID.",
        {
            "product_id": {
                "type": "integer"
            }
        },
        ["product_id"]
    ),

    tool_schema(
        "get_order_status",
        "Retrieve the status of the configured synthetic "
        "CloudMart demo order only. Real customer order "
        "access is not supported.",
        {
            "order_id": {
                "type": "integer"
            }
        },
        ["order_id"]
    )
]


# =============================================
# 2. Input validation
# =============================================

def validate_id(value):

    if type(value) is not int:

        raise ValueError("ID must be an integer")

    if not 1 <= value <= 2147483647:

        raise ValueError("Invalid ID")

    return value


def validate_text(value, max_length):

    if not isinstance(value, str):

        raise ValueError("Expected a string")

    value = value.strip()

    if not value or len(value) > max_length:

        raise ValueError("Invalid text length")

    return value


# =============================================
# 3. Knowledge retrieval tool
# =============================================

def search_knowledge_base(question):

    question = validate_text(question, 1000)

    results = retrieve(
        question,
        top_k=3
    )

    documents = []

    for result in results:

        metadata = result["metadata"]

        documents.append({
            "source": metadata["source"],
            "text": metadata["text"],
            "distance": result.get("distance")
        })

    return {
        "success": bool(documents),
        "count": len(documents),
        "documents": documents
    }


# =============================================
# 4. Live product search tool
# =============================================

def search_products(query, max_price=None):

    query = validate_text(query, 200)

    arguments = {
        "query": query
    }

    if max_price is not None:

        if (
            isinstance(max_price, bool)
            or not isinstance(max_price, (int, float))
            or not math.isfinite(max_price)
            or max_price < 0
        ):
            raise ValueError("Invalid maximum price")

        arguments["max_price"] = max_price

    return call_gateway_tool(
        "catalog___search_products",
        arguments
    )


# =============================================
# 5. Individual product tool
# =============================================

def get_product(product_id):

    product_id = validate_id(product_id)

    return call_gateway_tool(
        "catalog___get_product",
        {
            "product_id": product_id
        }
    )


# =============================================
# 6. Order status tool
# =============================================

def get_order_status(order_id):

    order_id = validate_id(order_id)

    return call_gateway_tool(
        "orders___get_order_status",
        {
            "order_id": order_id
        }
    )


# =============================================
# 7. Tool execution router
# =============================================

TOOL_FUNCTIONS = {
    "search_knowledge_base": search_knowledge_base,
    "search_products": search_products,
    "get_product": get_product,
    "get_order_status": get_order_status
}


def execute_tool(name, arguments):

    if name not in TOOL_FUNCTIONS:

        raise ValueError("Unsupported tool")

    if not isinstance(arguments, dict):

        raise ValueError("Invalid tool arguments")

    function = TOOL_FUNCTIONS[name]

    return function(**arguments)
