import json
import logging

from app.core.logging import (
    JsonFormatter,
    event_id_context,
    redact_sensitive_data,
)


def make_log(message: str) -> dict:
    record = logging.LogRecord(
        name="openlift.test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg=message,
        args=(),
        exc_info=None,
    )

    return json.loads(JsonFormatter().format(record))


def test_json_logging():
    result = make_log("Application started")

    assert result["level"] == "INFO"
    assert result["logger"] == "openlift.test"
    assert result["message"] == "Application started"
    assert "timestamp" in result


def test_event_id():
    token = event_id_context.set("event-123")

    try:
        result = make_log("NOSTR event processed")
        assert result["event_id"] == "event-123"
    finally:
        event_id_context.reset(token)


def test_no_event_id():
    result = make_log("Application started")

    assert "event_id" not in result


def test_nsec_redaction():
    secret = "nsec1" + "q" * 58

    result = make_log(f"Private key: {secret}")

    assert secret not in json.dumps(result)
    assert "[REDACTED]" in result["message"]


def test_hex_private_key_redaction():
    secret = "a" * 64

    result = make_log(f"Private key: {secret}")

    assert secret not in json.dumps(result)
    assert "[REDACTED]" in result["message"]


def test_redaction_function():
    secret = "b" * 64

    result = redact_sensitive_data(
        f"Received key {secret}"
    )

    assert secret not in result

def test_nostr_event_id_is_preserved():
    public_event_id = "a" * 64

    token = event_id_context.set(public_event_id)

    try:
        result = make_log("Processando reação NOSTR")
        assert result["event_id"] == public_event_id
    finally:
        event_id_context.reset(token)


def test_sensitive_hex_in_message_is_redacted():
    private_key = "b" * 64

    result = make_log(f"Secret: {private_key}")

    assert private_key not in result["message"]
    assert "[REDACTED]" in result["message"]