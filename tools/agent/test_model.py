
import os
import json
import groq

client = groq.Groq(
    api_key=os.environ["GROQ_API_KEY"].strip(),
    timeout=30.0,
    max_retries=0
)

model_id = os.environ["LLM_MODEL_ID"]

print("Testing model:", model_id)

tools = [
    {
        "type": "function",
        "function": {
            "name": "get_product",
            "description": "Retrieve product information",
            "parameters": {
                "type": "object",
                "properties": {
                    "product_id": {
                        "type": "integer"
                    }
                },
                "required": ["product_id"]
            }
        }
    }
]

messages = [
    {
        "role": "user",
        "content": (
            "Use get_product to check "
            "the price of product ID 1."
        )
    }
]

try:

    # First LLM request: ask the model to choose a tool
    response = client.chat.completions.create(
        model=model_id,
        messages=messages,
        tools=tools,
        tool_choice="required",
        reasoning_effort="low",
        max_completion_tokens=1024
    )

    message = response.choices[0].message

    if not message.tool_calls:
        raise RuntimeError("No tool call received")

    # Preserve the model's original tool request
    messages.append({
        "role": "assistant",
        "content": message.content,
        "tool_calls": [
            call.model_dump()
            for call in message.tool_calls
        ]
    })

    for call in message.tool_calls:

        arguments = json.loads(
            call.function.arguments
        )

        print("Requested tool:", call.function.name)
        print("Arguments:", arguments)

        if (
            call.function.name != "get_product"
            or arguments != {"product_id": 1}
        ):
            raise RuntimeError("Unexpected tool request")

        # Synthetic test response
        # No AWS call is performed in this test
        result = {
            "id": 1,
            "name": "Test Product",
            "price": 42.50
        }

        messages.append({
            "role": "tool",
            "tool_call_id": call.id,
            "content": json.dumps(result)
        })

    # Second LLM request: answer using the tool result
    response = client.chat.completions.create(
        model=model_id,
        messages=messages,
        reasoning_effort="low",
        max_completion_tokens=1024
    )

    answer = response.choices[0].message.content

    print("\nFinal answer:", answer)

    if not answer or "42.50" not in answer:
        raise RuntimeError(
            "The model did not use the test price correctly"
        )

    print("\nComplete model test successful!")

except groq.APIStatusError as exc:

    print("API status:", exc.status_code)
    print("Error:", exc.body)

    raise SystemExit(1)
