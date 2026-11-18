"""Structured JSON logging for OpenLift."""

import json
import logging
import re
from contextvars import ContextVar
from datetime import datetime, timezone

event_id_context: ContextVar[str | None] = ContextVar(
    "event_id",
    default=None,
)

PRIVATE_KEY_PATTERN = re.compile(
    r"(?<![A-Za-z0-9])nsec1[023456789acdefghjklmnpqrstuvwxyz]+"
    r"|(?<![A-Za-z0-9])[a-fA-F0-9]{64}(?![A-Za-z0-9])",
    re.IGNORECASE,
)

EVENT_ID_PATTERN = re.compile(r"^[0-9a-fA-F]{64}$")

def redact_sensitive_data(value: str) -> str:
    return PRIVATE_KEY_PATTERN.sub("[REDACTED]", value)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        data = {
            "timestamp": datetime.fromtimestamp(
                record.created,
                tz=timezone.utc,
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": redact_sensitive_data(
                record.getMessage()
            ),
        }

        event_id = getattr(record, "event_id", None)

        if event_id is None:
            event_id = event_id_context.get()

        if event_id is not None:
            event_id_value = str(event_id)

            if EVENT_ID_PATTERN.fullmatch(event_id_value):
                data["event_id"] = event_id_value.lower()
            else:
                data["event_id"] = redact_sensitive_data(
                    event_id_value
                )

        if record.exc_info:
            exception = self.formatException(record.exc_info)
            data["exception"] = redact_sensitive_data(
                exception
            )

        if record.stack_info:
            data["stack"] = redact_sensitive_data(
                record.stack_info
            )

        return json.dumps(data, ensure_ascii=False)


def configure_logging() -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())

    root = logging.getLogger()

    for existing in root.handlers[:]:
        root.removeHandler(existing)

    root.addHandler(handler)
    root.setLevel(logging.INFO)
