"""Bedrock client factory.

AWS credentials are temporary and expire hourly, so .env is re-read EVERY time a client is
created. Never cache credentials or the client at import/startup time.
"""
import os
from pathlib import Path

import boto3
from dotenv import dotenv_values

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
MODEL_ID = "global.anthropic.claude-sonnet-5-5"
REGION = "us-east-1"  # the only allowed region


def make_client():
    """Fresh bedrock-runtime client using the credentials currently in .env."""
    env = dotenv_values(ENV_PATH)  # fresh read each call; does not touch os.environ
    return boto3.client(
        "bedrock-runtime",
        region_name=REGION,
        aws_access_key_id=env.get("AWS_ACCESS_KEY_ID") or os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=env.get("AWS_SECRET_ACCESS_KEY") or os.getenv("AWS_SECRET_ACCESS_KEY"),
        aws_session_token=env.get("AWS_SESSION_TOKEN") or os.getenv("AWS_SESSION_TOKEN"),
    )


def converse(messages: list[dict], **kwargs):
    """One Converse call with a freshly created client."""
    return make_client().converse(modelId=MODEL_ID, messages=messages, **kwargs)


if __name__ == "__main__":
    # Connectivity check: prints only the reply text or the error message (never credentials).
    try:
        r = converse([{"role": "user", "content": [{"text": "say hi"}]}], inferenceConfig={"maxTokens": 30})
        print(r["output"]["message"]["content"][0]["text"])
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: {type(e).__name__}: {e}")
