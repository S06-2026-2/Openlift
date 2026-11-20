"""Endpoints do usuário logado. Rotas finas: a regra fica em
app/services/auth_service.py.

GET  /me                — usuário logado, com o npub (se houver)  → 200 | 401
POST /me/nostr-identity — registra o npub gerado no app (RF-03) → 200 | 401 | 409 | 422
GET  /me/profile        — perfil da rede social (ADR-0012)   → 200 | 401 | 404
PUT  /me/profile        — cria ou edita o perfil             → 200 | 401 | 409 | 422
"""

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.domain.schemas.nostr_identity import NostrIdentityIn
from app.domain.schemas.profile import USERNAME_RULE, ProfileIn, ProfileOut
from app.domain.schemas.user import UserOut
from app.services import auth_service, profile_service

router = APIRouter()


@router.get(
    "",
    response_model=UserOut,
    summary="Usuário logado",
    description="Devolve o usuário dono do access token, com o `npub` registrado "
    "(ou `null`, se ainda não houver identidade NOSTR).",
    responses=error_responses({401: "Autenticação necessária"}, validation=False),
)
def get_me(user: CurrentUser, db: DbSession) -> UserOut:
    return auth_service.to_user_out(db, user)


@router.post(
    "/nostr-identity",
    response_model=UserOut,
    summary="Registrar identidade NOSTR",
    description="Associa ao usuário a chave **pública** (`npub`, NIP-19) gerada no "
    "dispositivo. O corpo aceita somente `npub`: qualquer outro campo, inclusive "
    "chave privada, é recusado (422). Repetir o mesmo `npub` é idempotente; um "
    "`npub` novo substitui o anterior (outro dispositivo, ADR-0005).",
    responses=error_responses(
        {401: "Autenticação necessária", 409: "npub já ligado a outra conta"}
    ),
)
def register_nostr_identity(payload: NostrIdentityIn, user: CurrentUser, db: DbSession) -> UserOut:
    auth_service.attach_nostr_identity(db, user, payload.npub)
    return auth_service.to_user_out(db, user)


@router.get(
    "/profile",
    response_model=ProfileOut,
    summary="Meu perfil",
    description="Perfil da rede social do usuário logado. 404 (`profile_not_found`) "
    "enquanto ele não escolheu um nome de usuário: o app usa isso para abrir o cadastro.",
    responses=error_responses(
        {401: "Autenticação necessária", 404: "Ainda sem perfil"}, validation=False
    ),
)
def get_my_profile(user: CurrentUser, db: DbSession) -> ProfileOut:
    return profile_service.get_own(db, user)


@router.put(
    "/profile",
    response_model=ProfileOut,
    summary="Criar ou editar meu perfil",
    description=f"Escolhe o nome de usuário ({USERNAME_RULE}) e, opcionalmente, nome de "
    "exibição (até 50), bio (até 160) e URL da foto. O nome é guardado em minúsculas e "
    "não pode repetir. Exige a identidade NOSTR registrada: o nome vira NIP-05 dela. "
    "Depois de salvar, o app publica o mesmo perfil como `kind 0`.",
    responses=error_responses(
        {
            401: "Autenticação necessária",
            409: "Nome já em uso (`username_taken`) ou identidade NOSTR não registrada "
            "(`nostr_identity_required`)",
        }
    ),
)
def save_my_profile(payload: ProfileIn, user: CurrentUser, db: DbSession) -> ProfileOut:
    return profile_service.save_own(db, user, payload)
