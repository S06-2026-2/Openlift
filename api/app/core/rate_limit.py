"""Rate limiting nos endpoints públicos (OPS-05, RNF-03).

Janela deslizante em memória (biblioteca `limits`, a mesma que o slowapi
usa), aplicada como dependência nos routers de `/auth`, `/social`,
`/profiles` e `/media` (app/api/v1/router.py). Passou do limite → 429 no
formato `{detail, code}`, com `Retry-After`.

A chave é o IP do cliente. Em staging a API fica atrás de proxy (Railway e
nginx do site), então vale o primeiro IP de `X-Forwarded-For`; sem o
cabeçalho, o IP da conexão. Limitação conhecida: o cabeçalho pode ser
forjado por quem chama a API direto, e cada processo tem a própria memória
(um único processo no staging).
"""

import math
import time
from collections.abc import Callable

from fastapi import Request
from limits import parse
from limits.storage import MemoryStorage
from limits.strategies import MovingWindowRateLimiter

from app.core.config import get_settings
from app.core.errors import ApiError

_storage = MemoryStorage()
_limiter = MovingWindowRateLimiter(_storage)


def reset() -> None:
    """Zera os contadores (testes)."""
    _storage.reset()


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for", "")
    first = forwarded.split(",")[0].strip()
    if first:
        return first
    return request.client.host if request.client else "desconhecido"


def rate_limit(group: str, setting: str) -> Callable[[Request], None]:
    """Dependência que limita `group` com o texto de limite da configuração
    `setting` (ex.: `"10/minute"`), lido a cada requisição."""

    def dependency(request: Request) -> None:
        settings = get_settings()
        if not settings.rate_limit_enabled:
            return
        item = parse(getattr(settings, setting))
        key = client_ip(request)
        if _limiter.hit(item, group, key):
            return
        reset_at, _ = _limiter.get_window_stats(item, group, key)
        retry_after = max(1, math.ceil(reset_at - time.time()))
        raise ApiError(
            429,
            "Muitas requisições em pouco tempo. Espere um pouco e tente de novo.",
            "rate_limited",
            {"Retry-After": str(retry_after)},
        )

    return dependency
