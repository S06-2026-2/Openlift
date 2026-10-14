"""Regras de negócio de autenticação (BE-02).

- register: e-mail único (comparado em minúsculas) → 409 se duplicado;
- login: e-mail/senha → par de tokens; erro genérico para não revelar se o
  e-mail existe;
- refresh: refresh token válido → novo par (access + refresh).

TODO(NOSTR): attach_nostr_identity(db, user, npub) -> NostrIdentity (RF-03).
"""

from functools import lru_cache

from jwt import ExpiredSignatureError, InvalidTokenError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.user import User
from app.domain.schemas.auth import TokenPair
from app.domain.schemas.user import UserOut


def _invalid_credentials() -> ApiError:
    return ApiError(401, "E-mail ou senha incorretos.", "invalid_credentials")


def _normalize_email(email: str) -> str:
    return email.strip().lower()


@lru_cache(maxsize=1)
def _dummy_hash() -> str:
    # Hash "isca": login com e-mail inexistente também paga o custo do bcrypt,
    # então o tempo de resposta não revela quais e-mails estão cadastrados.
    return hash_password("openlift-dummy-password")


def register_user(db: Session, email: str, password: str) -> User:
    normalized = _normalize_email(email)
    if db.scalar(select(User.id).where(User.email == normalized)) is not None:
        raise ApiError(409, "Este e-mail já está cadastrado.", "email_already_registered")

    user = User(email=normalized, hashed_password=hash_password(password))
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:  # corrida: dois cadastros simultâneos do mesmo e-mail
        db.rollback()
        raise ApiError(409, "Este e-mail já está cadastrado.", "email_already_registered") from exc
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    user = db.scalar(select(User).where(User.email == _normalize_email(email)))
    if user is None:
        verify_password(password, _dummy_hash())
        raise _invalid_credentials()
    if not verify_password(password, user.hashed_password):
        raise _invalid_credentials()
    return user


def issue_tokens(user: User) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


def refresh_tokens(db: Session, refresh_token: str) -> TokenPair:
    try:
        payload = decode_token(refresh_token, expected_type="refresh")
    except ExpiredSignatureError as exc:
        raise ApiError(401, "Sua sessão expirou. Entre novamente.", "token_expired") from exc
    except InvalidTokenError as exc:
        raise ApiError(401, "Token de atualização inválido.", "invalid_token") from exc

    user = get_user_by_subject(db, payload.get("sub"))
    if user is None:
        raise ApiError(401, "Token de atualização inválido.", "invalid_token")
    return issue_tokens(user)


def get_user_by_subject(db: Session, subject: object) -> User | None:
    """Resolve o `sub` do JWT (id do usuário em texto) para o User."""
    try:
        user_id = int(str(subject))
    except ValueError:
        return None
    return db.get(User, user_id)


def to_user_out(db: Session, user: User) -> UserOut:
    """Monta o retorno público, buscando o npub em NostrIdentity (se houver)."""
    npub = db.scalar(select(NostrIdentity.npub).where(NostrIdentity.user_id == user.id))
    return UserOut(id=user.id, email=user.email, npub=npub, created_at=user.created_at)
