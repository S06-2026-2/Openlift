"""Formato padrão de erro da API: ``{"detail": "...", "code": "..."}``.

- ``detail``: frase em português, pronta para mostrar ao usuário;
- ``code``: identificador estável para o cliente decidir o que fazer
  (ex.: ``email_already_registered``, ``invalid_credentials``).

Erros de validação (422) também trazem ``errors`` com o campo e o motivo.
Nenhum handler devolve stack trace: falha inesperada vira 500 genérico e o
detalhe vai só para o log do servidor.
"""

import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger("openlift.api")

_DEFAULTS: dict[int, tuple[str, str]] = {
    400: ("bad_request", "Requisição inválida."),
    401: ("not_authenticated", "Autenticação necessária."),
    403: ("forbidden", "Você não tem permissão para fazer isso."),
    404: ("not_found", "Recurso não encontrado."),
    405: ("method_not_allowed", "Método não permitido para esta rota."),
    409: ("conflict", "O recurso já existe."),
    422: ("validation_error", "Dados inválidos."),
    429: ("rate_limited", "Muitas requisições. Tente novamente em instantes."),
}


class ApiError(StarletteHTTPException):
    """Erro de negócio com código estável. Use no lugar de HTTPException."""

    def __init__(
        self,
        status_code: int,
        detail: str,
        code: str,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(status_code=status_code, detail=detail, headers=headers)
        self.code = code


def error_body(status_code: int, detail: str | None = None, code: str | None = None) -> dict:
    default_code, default_detail = _DEFAULTS.get(status_code, ("http_error", "Erro na requisição."))
    return {"detail": detail or default_detail, "code": code or default_code}


async def _http_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, StarletteHTTPException)
    code = getattr(exc, "code", None)
    # Mensagens padrão do framework ("Not Found", ...) são trocadas pelas nossas.
    detail = exc.detail if code is not None and isinstance(exc.detail, str) else None
    return JSONResponse(
        status_code=exc.status_code,
        content=error_body(exc.status_code, detail, code),
        headers=getattr(exc, "headers", None),
    )


async def _validation_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    assert isinstance(exc, RequestValidationError)
    errors: list[dict[str, Any]] = [
        {
            "field": ".".join(str(part) for part in err.get("loc", ()) if part != "body"),
            "message": err.get("msg", ""),
        }
        for err in exc.errors()
    ]
    body = error_body(422, "Dados inválidos. Confira os campos enviados.", "validation_error")
    body["errors"] = errors
    return JSONResponse(status_code=422, content=jsonable_encoder(body))


async def _unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Erro não tratado em %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=error_body(500, "Erro interno do servidor.", "internal_error"),
    )


def register_exception_handlers(app: FastAPI) -> None:
    app.add_exception_handler(StarletteHTTPException, _http_exception_handler)
    app.add_exception_handler(RequestValidationError, _validation_exception_handler)
    app.add_exception_handler(Exception, _unhandled_exception_handler)
