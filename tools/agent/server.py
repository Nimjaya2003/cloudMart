
import logging

from flask import Flask, request, jsonify

from agent import run_agent


app = Flask(__name__)

app.config["MAX_CONTENT_LENGTH"] = 16384

logger = logging.getLogger(__name__)


# =============================================
# 1. Runtime health check
# =============================================

@app.get("/ping")
def ping():

    return jsonify({
        "status": "Healthy"
    }), 200


# =============================================
# 2. Agent invocation endpoint
# =============================================

@app.post("/invocations")
def invocations():

    data = request.get_json(silent=True)

    if not isinstance(data, dict):

        return jsonify({
            "success": False,
            "error": "Invalid JSON request"
        }), 400

    prompt = data.get("prompt")

    if (
        not isinstance(prompt, str)
        or not prompt.strip()
        or len(prompt) > 2000
    ):

        return jsonify({
            "success": False,
            "error": "A valid prompt is required"
        }), 400

    try:

        result = run_agent(prompt)

        return jsonify(result), 200

    except Exception as exc:

        logger.error(
            "Agent invocation failed: %s",
            type(exc).__name__
        )

        return jsonify({
            "success": False,
            "answer": (
                "The CloudMart assistant is "
                "currently unavailable."
            )
        }), 200


# =============================================
# 3. Local development server
# =============================================

if __name__ == "__main__":

    app.run(
        host="127.0.0.1",
        port=8080,
        debug=False
    )
