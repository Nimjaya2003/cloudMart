import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns = boto3.client("sns")
TOPIC_ARN = os.environ["NOTIFICATION_TOPIC_ARN"]


def build_message(event):
    order = event["order"]
    lines = [f"  {i['qty']} x {i['name']} @ ${i['unit_price']:.2f}" for i in order["items"]]
    body = "\n".join(
        [f"Order #{order['id']} was placed.", "", *lines, "", f"Total: ${order['total']:.2f}"]
    )
    return f"CloudMart order #{order['id']} confirmed", body


def handler(event, context):
    """Triggered by SQS with up to 5 messages. Returns the ones that failed so only those are retried."""
    failures = []
    for record in event["Records"]:
        try:
            payload = json.loads(record["body"])
            if payload.get("event_type") != "OrderPlaced":
                logger.warning("Ignoring unknown event type in message %s", record["messageId"])
                continue
            subject, body = build_message(payload)
            sns.publish(TopicArn=TOPIC_ARN, Subject=subject, Message=body)
            logger.info("Sent notification for order %s", payload["order"]["id"])
        except Exception:
            logger.exception("Failed to process message %s", record["messageId"])
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}