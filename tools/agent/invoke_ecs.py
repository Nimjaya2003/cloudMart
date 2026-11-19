
import os
import json
import argparse

from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


# =============================================
# 1. Invoke the ECS-hosted intelligent agent
# =============================================

def invoke_agent(prompt):

    if not isinstance(prompt, str):

        raise ValueError("Prompt must be a string")

    prompt = prompt.strip()

    if not prompt or len(prompt) > 2000:

        raise ValueError("Invalid prompt length")

    # Default development endpoint through SSM
    base_url = os.environ.get(
        "AGENT_BASE_URL",
        "http://127.0.0.1:18081"
    ).rstrip("/")

    url = base_url + "/invocations"

    payload = json.dumps({
        "prompt": prompt
    }).encode("utf-8")

    request = Request(
        url=url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json"
        },
        method="POST"
    )

    with urlopen(
        request,
        timeout=300
    ) as response:

        result = json.loads(
            response.read().decode("utf-8")
        )

    if not isinstance(result, dict):

        raise RuntimeError(
            "Unexpected agent response"
        )

    return result


# =============================================
# 2. Command-line invocation
# =============================================

def main():

    parser = argparse.ArgumentParser()

    parser.add_argument("prompt")

    args = parser.parse_args()

    try:

        result = invoke_agent(args.prompt)

        print(json.dumps(
            result,
            indent=2,
            ensure_ascii=False
        ))

        if not result.get("success"):

            raise SystemExit(1)

    except HTTPError as exc:

        print("HTTP error:", exc.code)

        raise SystemExit(1)

    except URLError as exc:

        print("Connection error:", exc.reason)

        print(
            "Check whether the SSM port-forwarding "
            "session is running."
        )

        raise SystemExit(1)


if __name__ == "__main__":

    main()
