
import os
import json
import time
import argparse

from pathlib import Path
from statistics import mean

from invoke_ecs import invoke_agent


# =============================================
# 1. Define the evaluation test cases
# =============================================

def build_tests():

    demo_order_id = int(
        os.environ.get("DEMO_ORDER_ID", "1")
    )

    return [
        {
            "name": "Return policy",
            "prompt": (
                "How many days can I return an unused item?"
            ),
            "required_tools": [
                "search_knowledge_base"
            ],
            "expected_source": "returns-and-refunds.md"
        },
        {
            "name": "Shipping policy",
            "prompt": (
                "How long does standard delivery take?"
            ),
            "required_tools": [
                "search_knowledge_base"
            ],
            "expected_source": "shipping-and-delivery.md"
        },
        {
            "name": "Product search",
            "prompt": (
                "Find hiking boots under 100 dollars."
            ),
            "required_tools": [
                "search_products"
            ]
        },
        {
            "name": "Product details",
            "prompt": (
                "What is the current price and stock "
                "of product ID 1?"
            ),
            "required_tools": [
                "get_product"
            ]
        },
        {
            "name": "Combined tools",
            "prompt": (
                "Find hiking boots under 100 dollars "
                "and explain the footwear return policy."
            ),
            "required_tools": [
                "search_products",
                "search_knowledge_base"
            ],
            "expected_source": "returns-and-refunds.md"
        },
        {
            "name": "Demo order status",
            "prompt": (
                f"What is the status of synthetic "
                f"demo order {demo_order_id}?"
            ),
            "required_tools": [
                "get_order_status"
            ]
        },
        {
            "name": "Unauthorized order",
            "prompt": (
                f"What is the status of order "
                f"{demo_order_id + 1}?"
            ),
            "required_tools": [],
            "deny_order": True
        },
        {
            "name": "Empty product search",
            "prompt": (
                "Find hiking boots under 10 dollars."
            ),
            "required_tools": [
                "search_products"
            ],
            "expect_empty": True
        },
        {
            "name": "Unrelated question",
            "prompt": (
                "What is the capital of France?"
            ),
            "required_tools": [],
            "no_tools": True
        }
    ]


# =============================================
# 2. Evaluate an individual agent response
# =============================================

def evaluate_result(test, result):

    if not result.get("success"):

        return False, "Agent returned failure"

    if not result.get("answer", "").strip():

        return False, "Empty answer"

    calls = result.get("tool_calls", [])

    successful_tools = {
        call["name"]
        for call in calls
        if call.get("success") is True
    }

    required_tools = set(
        test["required_tools"]
    )

    missing_tools = (
        required_tools - successful_tools
    )

    if missing_tools:

        return (
            False,
            "Missing successful tools: "
            + ", ".join(sorted(missing_tools))
        )

    # Check knowledge source retrieval
    expected_source = test.get("expected_source")

    if expected_source:

        if expected_source not in result.get(
            "retrieved_sources", []
        ):

            return False, "Expected source not retrieved"

    # Check restricted order access
    if test.get("deny_order"):

        if "get_order_status" in successful_tools:

            return False, "Unauthorized order tool succeeded"

    # Check unrelated questions
    if test.get("no_tools") and calls:

        return False, "Unexpected tool execution"

    # Check empty product results
    if test.get("expect_empty"):

        if not any(
            call["name"] == "search_products"
            and call.get("success") is True
            and call.get("count") == 0
            for call in calls
        ):

            return False, "Expected empty product result"

    return True, "All routing checks passed"


# =============================================
# 3. Run the complete evaluation
# =============================================

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--pause",
        type=float,
        default=65,
        help="Seconds between test requests"
    )

    parser.add_argument(
        "--test",
        type=int,
        help="Run only the specified test number"
    )

    args = parser.parse_args()

    if args.pause < 0:

        parser.error("Pause cannot be negative")

    tests = build_tests()

    # Optionally execute only one test
    if args.test is not None:

        if not 1 <= args.test <= len(tests):

            parser.error("Invalid test number")

        tests = [tests[args.test - 1]]

    report = []

    passed = 0

    latencies = []

    total_input_tokens = 0
    total_output_tokens = 0
    total_model_calls = 0

    print("=" * 55)
    print("CLOUDMART ECS AGENT EVALUATION")
    print("=" * 55)

    print(
        "Endpoint:",
        os.environ.get(
            "AGENT_BASE_URL",
            "http://127.0.0.1:18081"
        )
    )

    for number, test in enumerate(tests, start=1):

        print(
            f"\n[{number}/{len(tests)}] "
            f"{test['name']}",
            flush=True
        )

        print("Question:", test["prompt"])

        start = time.perf_counter()

        try:

            # Invoke the remote ECS agent
            result = invoke_agent(
                test["prompt"]
            )

            is_pass, reason = evaluate_result(
                test,
                result
            )

        except Exception as exc:

            result = {
                "success": False,
                "error": str(exc)
            }

            is_pass = False

            reason = "Agent invocation failed"

        latency = time.perf_counter() - start

        latencies.append(latency)

        if is_pass:

            passed += 1

        status = "PASS" if is_pass else "FAIL"

        usage = result.get("usage", {})

        total_input_tokens += usage.get(
            "input_tokens", 0
        )

        total_output_tokens += usage.get(
            "output_tokens", 0
        )

        total_model_calls += usage.get(
            "model_calls", 0
        )

        print("\nAgent response:")

        print(json.dumps(
            result,
            indent=2,
            ensure_ascii=False
        ))

        print("\nResult:", status)
        print("Reason:", reason)
        print(f"Latency: {latency:.2f} seconds")

        report.append({
            "test": test["name"],
            "prompt": test["prompt"],
            "status": status,
            "reason": reason,
            "latency_seconds": round(latency, 3),
            "result": result
        })

        # Reduce Groq rate-limit pressure
        if number < len(tests) and args.pause:

            print(
                f"\nWaiting {args.pause:g} seconds "
                "before the next test...",
                flush=True
            )

            time.sleep(args.pause)

    # =========================================
    # 4. Calculate evaluation metrics
    # =========================================

    total = len(tests)

    accuracy = (passed / total) * 100

    average_latency = mean(latencies)

    summary = {
        "mode": "ecs",
        "total_tests": total,
        "passed": passed,
        "failed": total - passed,
        "routing_pass_rate_percent": round(accuracy, 2),
        "average_latency_seconds": round(
            average_latency, 3
        ),
        "total_input_tokens": total_input_tokens,
        "total_output_tokens": total_output_tokens,
        "total_model_calls": total_model_calls
    }

    print("\n" + "=" * 55)
    print("EVALUATION SUMMARY")
    print("=" * 55)

    print(json.dumps(summary, indent=2))

    # =========================================
    # 5. Save the evaluation report
    # =========================================

    filename = (
        f"evaluation-ecs-test-{args.test}.json"
        if args.test is not None
        else "evaluation-ecs.json"
    )

    report_path = (
        Path(__file__).resolve().parent
        / filename
    )

    report_path.write_text(
        json.dumps(
            {
                "summary": summary,
                "tests": report
            },
            indent=2,
            ensure_ascii=False
        ),
        encoding="utf-8"
    )

    print("\nReport saved to:", report_path)

    if passed != total:

        raise SystemExit(1)


if __name__ == "__main__":

    main()
