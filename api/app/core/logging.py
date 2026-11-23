"""Logs estruturados em JSON (OPS-08, RNF-14), com redação de chave (RNF-01).

Uma linha JSON por registro, em stdout, com `timestamp`, `level`, `logger`,
`message` e os campos passados em `extra=` (ex.: `event_id`, `relay`,
`reason`, `method`, `path`, `status_code`, `duration_ms`). É o que deixa os
logs da API e do worker correlacionáveis por `event_id`.

Defesa em profundidade para o RNF-01: o backend nunca recebe chave privada,
mas qualquer `nsec1...` ou hex de 64 caracteres que apareça numa mensagem,
num campo extra ou num traceback vira `[REDACTED]`. A exceção são os campos
cujo nome diz que o valor é público (`event_id`, `pubkey`...), mantidos só se
forem exatamente um hex de 64.

Ideia aproveitada da branch `feat/structured-logging`, sem a dependência
`structlog`: só a biblioteca padrão.
"""

import json
import logging
import re
import sys
from datetime import UTC, datetime
from typing import Any

PRIVATE_KEY_PATTERN = re.compile(
    r"(?<![0-9A-Za-z])nsec1[02-9ac-hj-np-z]+|(?<![0-9A-Fa-f])[0-9A-Fa-f]{64}(?![0-9A-Fa-f])"
)
_HEX64 = re.compile(r"^[0-9a-f]{64}$")
REDACTED = "[REDACTED]"

# Campos extras cujo valor hex de 64 é público por definição (NIP-01).
PUBLIC_HEX_FIELDS = frozenset({"event_id", "pubkey", "target_event_id"})

# Atributos que todo LogRecord tem; o resto veio de `extra=`.
_STANDARD_ATTRS = frozenset(vars(logging.LogRecord("", 0, "", 0, "", None, None))) | {
    "message",
    "asctime",
    "taskName",
}


def redact(value: str) -> str:
    return PRIVATE_KEY_PATTERN.sub(REDACTED, value)


def sanitize(value: Any) -> Any:
    if isinstance(value, str):
        return redact(value)
    if isinstance(value, dict):
        return {str(k): sanitize(v) for k, v in value.items()}
    if isinstance(value, list | tuple | set):
        return [sanitize(v) for v in value]
    if isinstance(value, bool | int | float) or value is None:
        return value
    return redact(str(value))


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        data: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": redact(record.getMessage()),
        }
        for key, value in vars(record).items():
            if key in _STANDARD_ATTRS or key in data or key.startswith("_"):
                continue
            if key in PUBLIC_HEX_FIELDS and isinstance(value, str) and _HEX64.match(value):
                data[key] = value
            else:
                data[key] = sanitize(value)
        if record.exc_info:
            data["exception"] = redact(self.formatException(record.exc_info))
        if record.stack_info:
            data["stack"] = redact(record.stack_info)
        return json.dumps(data, ensure_ascii=False, default=str)


def configure_logging(level: str = "INFO") -> None:
    """Liga o JSON em stdout no logger raiz. Idempotente: chamar de novo só
    ajusta o nível, sem duplicar handler (e sem tirar o `caplog` do pytest)."""
    root = logging.getLogger()
    if not any(isinstance(h.formatter, JsonFormatter) for h in root.handlers):
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        root.addHandler(handler)
    root.setLevel(level.upper())
    # O uvicorn tem handlers próprios com texto; deixa tudo sair pelo raiz.
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        uvicorn_logger = logging.getLogger(name)
        uvicorn_logger.handlers.clear()
        uvicorn_logger.propagate = True
    # O middleware já registra cada requisição com duração; evita linha dupla.
    logging.getLogger("uvicorn.access").disabled = True
