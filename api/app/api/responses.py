"""Documentação dos erros de cada rota no OpenAPI (formato {detail, code})."""

from typing import Any

from app.domain.schemas.error import ErrorOut

Responses = dict[int | str, dict[str, Any]]


def error_responses(by_status: dict[int, str], *, validation: bool = True) -> Responses:
    """Ex.: ``responses=error_responses({404: "Treino não encontrado"})``.

    Inclui o 422 por padrão (rotas que recebem corpo ou query params).
    """
    responses: Responses = {
        code: {"model": ErrorOut, "description": text} for code, text in by_status.items()
    }
    if validation:
        responses[422] = {"model": ErrorOut, "description": "Dados inválidos"}
    return responses
