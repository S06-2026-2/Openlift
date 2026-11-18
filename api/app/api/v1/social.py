"""Endpoints de métricas sociais que não cabem puramente no NOSTR.

GET /social/likes   — contagem cacheada de curtidas por event_id (BE-10)

Não existe `POST /social/shared-events`: o registro do evento publicado já é
feito por `POST /workouts/{id}/publication` (BE-S2-03), que grava em
`shared_events` com as regras de `pubkey` e RN-08.
"""

import re
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.core.errors import ApiError
from app.domain.schemas.social import LikeCountOut
from app.services import social_service

# TODO(BE-15): get_ranking() — usa app/services/ranking_service.py

router = APIRouter()

MAX_EVENT_IDS = 100
_EVENT_ID = re.compile(r"^[0-9a-f]{64}$")


@router.get(
    "/likes",
    response_model=list[LikeCountOut],
    summary="Curtidas dos treinos publicados",
    description="Para cada `event_id` (repita o parâmetro: `?event_ids=a&event_ids=b`), "
    "quantas pessoas curtiram e se o usuário logado curtiu. A contagem vem do cache "
    "`likes`, atualizado pelo worker a cada ciclo a partir de eventos `kind 7` assinados "
    "(ADR-0004), então um like recém-publicado pode levar um ciclo para aparecer. "
    f"Até {MAX_EVENT_IDS} ids por requisição; repetidos são ignorados e a ordem é mantida. "
    "Sem `event_ids`, a resposta é `[]`.",
    responses=error_responses(
        {
            401: "Autenticação necessária",
            422: f"`event_id` que não é hex de 64 caracteres (`invalid_event_id`) ou mais de "
            f"{MAX_EVENT_IDS} ids (`too_many_event_ids`)",
        }
    ),
)
def get_like_counts(
    db: DbSession,
    user: CurrentUser,
    event_ids: Annotated[
        list[str],
        Query(description="`id` dos eventos `kind 1301`, em hex minúsculo de 64 caracteres"),
    ] = [],  # noqa: B006 — o FastAPI copia o valor padrão por requisição
) -> list[LikeCountOut]:
    unique = list(dict.fromkeys(event_ids))
    if len(unique) > MAX_EVENT_IDS:
        raise ApiError(
            422, f"Envie no máximo {MAX_EVENT_IDS} event_ids por vez.", "too_many_event_ids"
        )
    if any(not _EVENT_ID.match(event_id) for event_id in unique):
        raise ApiError(
            422, "Todo event_id precisa ser hex minúsculo de 64 caracteres.", "invalid_event_id"
        )
    return social_service.like_counts(db, user, unique)
