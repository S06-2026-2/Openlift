
import json
import logging
import re
from contextvars import ContextVar
from datetime import UTC, datetime
from typing import Any

import structlog

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
    """Remove possíveis chaves privadas de mensagens de log."""
    return PRIVATE_KEY_PATTERN.sub("[REDACTED]", value)


def sanitize_value(value: Any) -> Any:
    """Sanitiza recursivamente valores presentes nos logs."""
    if isinstance(value, str):
        return redact_sensitive_data(value)

    if isinstance(value, dict):
        return {
            str(key): sanitize_value(item)
            for key, item in value.items()
        }

    if isinstance(value, list | tuple):
        return [sanitize_value(item) for item in value]

    return value


class JsonFormatter(logging.Formatter):
    """Formata registros do logging padrão e structlog como JSON."""

    def format(self, record: logging.LogRecord) -> str:
        data: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(
                record.created,
                tz=UTC,
            ).isoformat(),
            "level": record.levelname,
            "logger": record.name,
        }

        message = record.getMessage()

        try:
            parsed = json.loads(message)
        except (json.JSONDecodeError, TypeError):
            parsed = None

        if isinstance(parsed, dict):
            # Evita sobrescrever os metadados do logger.
            for key, value in parsed.items():
                if key not in {"timestamp", "level", "logger"}:
                    data[key] = sanitize_value(value)
        else:
            data["message"] = redact_sensitive_data(message)

        event_id = getattr(record, "event_id", None)

        if event_id is None:
            event_id = event_id_context.get()

        if event_id is not None:
            event_id_value = str(event_id)

            # Preserva apenas IDs explicitamente fornecidos
            # pelo contexto NOSTR, não hexadecimais arbitrários.
            if EVENT_ID_PATTERN.fullmatch(event_id_value):
                data["event_id"] = event_id_value.lower()
            else:
                data["event_id"] = redact_sensitive_data(
                    event_id_value
                )

        if record.exc_info:
            data["exception"] = redact_sensitive_data(
                self.formatException(record.exc_info)
            )

        if record.stack_info:
            data["stack"] = redact_sensitive_data(
                record.stack_info
            )

        return json.dumps(data, ensure_ascii=False)


def configure_logging() -> None:
    """Configura logging JSON para Python e structlog."""
    root = logging.getLogger()

    # Preserva os handlers existentes, inclusive o caplog
    # utilizado pelo pytest.
    if not any(
        isinstance(handler.formatter, JsonFormatter)
        for handler in root.handlers
    ):
        handler = logging.StreamHandler()
        handler.setFormatter(JsonFormatter())
        root.addHandler(handler)

    root.setLevel(logging.INFO)

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=False,
    )
