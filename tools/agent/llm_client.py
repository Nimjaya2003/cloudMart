
import os
import boto3

from functools import lru_cache
from groq import Groq
from botocore.config import Config


REGION = "ap-south-1"


def get_api_key():

    secret_arn = os.environ.get(
        "GROQ_SECRET_ARN"
    )

    # AWS deployment: retrieve the key from Secrets Manager
    if secret_arn:

        secrets = boto3.client(
            "secretsmanager",
            region_name=REGION,
            config=Config(
                connect_timeout=5,
                read_timeout=10
            )
        )

        response = secrets.get_secret_value(
            SecretId=secret_arn
        )

        api_key = response["SecretString"].strip()

    # Local development: use the environment variable
    else:

        api_key = os.environ.get(
            "GROQ_API_KEY", ""
        ).strip()

    if not api_key:
        raise RuntimeError(
            "Groq API key is not configured"
        )

    return api_key


@lru_cache(maxsize=1)
def get_llm_client():

    return Groq(
        api_key=get_api_key(),
        timeout=30.0,
        max_retries=0
    )


def call_model(messages, tools):

    client = get_llm_client()

    return client.chat.completions.create(
        model=os.environ.get(
            "LLM_MODEL_ID",
            "openai/gpt-oss-20b"
        ),
        messages=messages,
        tools=tools,
        tool_choice="auto",
        reasoning_effort="low",
        max_completion_tokens=1024,
        temperature=0.1
    )
