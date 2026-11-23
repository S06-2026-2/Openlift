"""Log de cada requisição HTTP (OPS-08, RNF-14).

Uma linha por requisição em `openlift.http`, com método, caminho (sem query
string: lá podem vir ids e nomes), status e duração. Nunca registra corpo nem
cabeçalhos (o `Authorization` leva o JWT).
"""

import logging
import time
from collections.abc import Awaitable, Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger("openlift.http")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        start = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            logger.exception(
                "Requisição falhou",
                extra={"method": request.method, "path": request.url.path},
            )
            raise
        logger.info(
            "%s %s %d",
            request.method,
            request.url.path,
            response.status_code,
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round((time.perf_counter() - start) * 1000, 2),
            },
        )
        return response
