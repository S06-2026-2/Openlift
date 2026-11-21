"""Perfis da rede social (ADR-0012). Rotas finas: a regra fica em
app/services/profile_service.py. Todas exigem login.

GET /profiles/availability?username=  — o nome está livre?
GET /profiles/search?q=               — busca por nome de usuário
GET /profiles?pubkeys=                — perfis de várias chaves públicas
GET /profiles/{username}              — perfil de uma pessoa

O próprio perfil é criado e editado em /me/profile (app/api/v1/me.py).
"""

import re
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.core.errors import ApiError
from app.domain.schemas.profile import (
    USERNAME_PATTERN,
    USERNAME_RULE,
    ProfileOut,
    UsernameAvailabilityOut,
    normalize_username,
)
from app.services import profile_service

router = APIRouter()

MAX_PUBKEYS = 100
_PUBKEY = re.compile(r"^[0-9a-f]{64}$")


@router.get(
    "/availability",
    response_model=UsernameAvailabilityOut,
    summary="Nome de usuário disponível?",
    description=f"Normaliza o nome (minúsculas, sem `@`) e diz se está livre. {USERNAME_RULE} "
    "O nome que já é do próprio usuário conta como disponível.",
    responses=error_responses(
        {401: "Não autenticado", 422: "Nome fora do formato (`invalid_username`)"}
    ),
)
def get_availability(
    db: DbSession,
    user: CurrentUser,
    username: Annotated[str, Query(max_length=40, description="Nome desejado")],
) -> UsernameAvailabilityOut:
    name = normalize_username(username)
    if not USERNAME_PATTERN.match(name):
        raise ApiError(422, USERNAME_RULE, "invalid_username")
    return UsernameAvailabilityOut(
        username=name, available=profile_service.is_available(db, user, name)
    )


@router.get(
    "/search",
    response_model=list[ProfileOut],
    summary="Buscar pessoas",
    description="Perfis cujo nome de usuário começa com `q` ou cujo nome de exibição contém "
    f"`q` (sem diferenciar maiúsculas), em ordem alfabética. Até "
    f"{profile_service.MAX_SEARCH_RESULTS} resultados.",
    responses=error_responses({401: "Não autenticado"}),
)
def search_profiles(
    db: DbSession,
    user: CurrentUser,
    q: Annotated[str, Query(min_length=1, max_length=40, description="Texto buscado")],
) -> list[ProfileOut]:
    return profile_service.search(db, q)


@router.get(
    "",
    response_model=list[ProfileOut],
    summary="Perfis por chave pública",
    description="Perfis das `pubkeys` pedidas (repita o parâmetro), para mostrar nome e foto "
    f"de quem aparece no feed. Chave sem perfil fica de fora. Até {MAX_PUBKEYS} por vez.",
    responses=error_responses(
        {
            401: "Não autenticado",
            422: "`pubkey` fora do formato (`invalid_pubkey`) ou mais de "
            f"{MAX_PUBKEYS} (`too_many_pubkeys`)",
        }
    ),
)
def get_profiles(
    db: DbSession,
    user: CurrentUser,
    pubkeys: Annotated[
        list[str], Query(description="Chaves públicas em hex minúsculo de 64 caracteres")
    ] = [],  # noqa: B006 — o FastAPI copia o valor padrão por requisição
) -> list[ProfileOut]:
    unique = list(dict.fromkeys(pubkeys))
    if len(unique) > MAX_PUBKEYS:
        raise ApiError(422, f"Envie no máximo {MAX_PUBKEYS} pubkeys por vez.", "too_many_pubkeys")
    if any(not _PUBKEY.match(pubkey) for pubkey in unique):
        raise ApiError(
            422, "Toda pubkey precisa ser hex minúsculo de 64 caracteres.", "invalid_pubkey"
        )
    return profile_service.by_pubkeys(db, unique)


@router.get(
    "/{username}",
    response_model=ProfileOut,
    summary="Perfil de uma pessoa",
    description="Perfil público pelo nome de usuário (com ou sem `@`).",
    responses=error_responses(
        {401: "Não autenticado", 404: "Ninguém com esse nome (`profile_not_found`)"},
        validation=False,
    ),
)
def get_profile(username: str, db: DbSession, user: CurrentUser) -> ProfileOut:
    return profile_service.by_username(db, username)
