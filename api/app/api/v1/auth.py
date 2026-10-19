"""Endpoints de autenticação (BE-02). Rotas finas: a regra fica em
app/services/auth_service.py.

POST /auth/register  — cria usuário (e-mail + senha)          → 201 | 409 | 422
POST /auth/login     — autentica e devolve access/refresh     → 200 | 401 | 422
POST /auth/refresh   — troca o refresh token por um novo par  → 200 | 401 | 422

O registro do npub (RF-03) fica em app/api/v1/me.py.
"""

from fastapi import APIRouter, status

from app.api.deps import DbSession
from app.api.responses import error_responses
from app.domain.schemas.auth import LoginRequest, RefreshRequest, RegisterRequest, TokenPair
from app.domain.schemas.user import UserOut
from app.services import auth_service

router = APIRouter()


@router.post(
    "/register",
    response_model=UserOut,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastro de usuário",
    description="Cria a conta com e-mail e senha (mínimo de 8 caracteres). "
    "O e-mail é único, sem diferenciar maiúsculas de minúsculas.",
    responses=error_responses({409: "E-mail já cadastrado"}),
)
def register(payload: RegisterRequest, db: DbSession) -> UserOut:
    user = auth_service.register_user(db, payload.email, payload.password)
    return auth_service.to_user_out(db, user)


@router.post(
    "/login",
    response_model=TokenPair,
    summary="Login e-mail/senha",
    description="Devolve um access token (curta duração, enviado como "
    "`Authorization: Bearer ...`) e um refresh token (usado só em /auth/refresh).",
    responses=error_responses({401: "E-mail ou senha incorretos"}),
)
def login(payload: LoginRequest, db: DbSession) -> TokenPair:
    user = auth_service.authenticate_user(db, payload.email, payload.password)
    return auth_service.issue_tokens(user)


@router.post(
    "/refresh",
    response_model=TokenPair,
    summary="Renovar JWT",
    description="Troca um refresh token válido por um novo par de tokens.",
    responses=error_responses({401: "Refresh token inválido ou expirado"}),
)
def refresh(payload: RefreshRequest, db: DbSession) -> TokenPair:
    return auth_service.refresh_tokens(db, payload.refresh_token)
