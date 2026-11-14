"""Validates a contact form submission and emails it to the site owner through SES."""
import base64, json, logging, os, re

import boto3
from botocore.exceptions import BotoCoreError, ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SES = boto3.client("sesv2")
SENDER = os.environ["SENDER_ADDRESS"]
RECIPIENT = os.environ["RECIPIENT_ADDRESS"]
SITE_NAME = os.environ.get("SITE_NAME", "website")

EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,190}\.[A-Za-z]{2,24}$")
TOPICS = {"Freelance project", "Job opportunity", "AWS cost or security check", "Something else"}
LIMITS = {"name": 100, "email": 200, "company": 120, "message": 4000}


def _response(status, body):
    return {"statusCode": status,
            "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
            "body": json.dumps(body)}


def _one_line(value):
    # remove line breaks so nobody can inject extra email headers
    return re.sub(r"[\r\n\t\x00-\x1f\x7f]+", " ", value).strip()


def _parse(event):
    raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8", errors="replace")
    if len(raw) > 10_000:
        raise ValueError("too large")
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("not an object")
    return data


def handler(event, context):
    request_id = getattr(context, "aws_request_id", "-")
    try:
        data = _parse(event)
    except (ValueError, json.JSONDecodeError):
        return _response(400, {"ok": False, "error": "Send the form as JSON."})

    # Honeypot: a hidden field only bots fill in. Pretend success so they don't retry.
    if str(data.get("website", "")).strip():
        return _response(200, {"ok": True})

    fields = {k: str(data.get(k, "")).strip() for k in ("name", "email", "company", "message")}
    errors = []
    if not fields["name"]:
        errors.append("name")
    if not EMAIL_RE.match(fields["email"]):
        errors.append("email")
    if len(fields["message"]) < 20:
        errors.append("message")
    errors += [k for k, limit in LIMITS.items() if len(fields[k]) > limit]
    if errors:
        return _response(400, {"ok": False, "fields": sorted(set(errors))})

    topic = str(data.get("topic", "")).strip()
    topic = topic if topic in TOPICS else "Something else"
    name = _one_line(fields["name"])
    body = (f"New message from {SITE_NAME}\n\n"
            f"Name:    {name}\nEmail:   {fields['email']}\n"
            f"Company: {_one_line(fields['company']) or 'not given'}\nTopic:   {topic}\n\n"
            f"{fields['message']}\n\nRequest ID: {request_id}\n")
    try:
        SES.send_email(
            FromEmailAddress=SENDER,
            Destination={"ToAddresses": [RECIPIENT]},
            ReplyToAddresses=[fields["email"]],  # hit Reply to answer the visitor
            Content={"Simple": {
                "Subject": {"Data": f"[{SITE_NAME}] {topic} from {name}"[:200]},
                "Body": {"Text": {"Data": body}}}},
        )
    except (ClientError, BotoCoreError):
        logger.exception("send failed request=%s", request_id)
        return _response(502, {"ok": False, "error": "Couldn't deliver the message."})

    logger.info("sent request=%s topic=%s", request_id, topic)
    return _response(200, {"ok": True})
