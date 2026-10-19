"""Endpoints do usuário logado. Rotas finas: a regra fica em
app/services/auth_service.py.

POST /me/nostr-identity — registra o npub gerado no app (RF-03) → 200 | 401 | 409 | 422
"""

from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.domain.schemas.nostr_identity import NostrIdentityIn
from app.domain.schemas.user import UserOut
from app.services import auth_service

router = APIRouter()


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
