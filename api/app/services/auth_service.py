"""Regras de negócio de autenticação (BE-02).

- register: e-mail único (comparado em minúsculas) → 409 se duplicado;
- login: e-mail/senha → par de tokens; erro genérico para não revelar se o
  e-mail existe;
- refresh: refresh token válido → novo par (access + refresh);
- attach_nostr_identity: associa o npub gerado no app ao usuário (RF-03).
"""

from functools import lru_cache

from jwt import ExpiredSignatureError, InvalidTokenError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.core.nostr import npub_to_hex
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


def attach_nostr_identity(db: Session, user: User, npub: str) -> NostrIdentity:
    """Registra o npub do usuário (S2-02).

    - mesmo npub de novo → idempotente;
    - npub diferente → substitui (ADR-0005: outro dispositivo sem importar a
      chave gera identidade nova);
    - npub de outra conta → 409.

    `pubkey_hex` é sempre derivado do npub aqui, nunca recebido do cliente.
    """
    pubkey_hex = npub_to_hex(npub)
    owner_id = db.scalar(select(NostrIdentity.user_id).where(NostrIdentity.npub == npub))
    if owner_id is not None and owner_id != user.id:
        raise _npub_taken()

    identity = db.scalar(select(NostrIdentity).where(NostrIdentity.user_id == user.id))
    if identity is None:
        identity = NostrIdentity(user_id=user.id, npub=npub, pubkey_hex=pubkey_hex)
        db.add(identity)
    elif identity.npub == npub:
        return identity
    else:
        identity.npub = npub
        identity.pubkey_hex = pubkey_hex
    try:
        db.commit()
    except IntegrityError as exc:  # corrida: o mesmo npub registrado ao mesmo tempo
        db.rollback()
        raise _npub_taken() from exc
    db.refresh(identity)
    return identity


def _npub_taken() -> ApiError:
    return ApiError(
        409, "Esta identidade NOSTR já está ligada a outra conta.", "npub_already_registered"
    )


def to_user_out(db: Session, user: User) -> UserOut:
    """Monta o retorno público, buscando o npub em NostrIdentity (se houver)."""
    npub = db.scalar(select(NostrIdentity.npub).where(NostrIdentity.user_id == user.id))
    return UserOut(id=user.id, email=user.email, npub=npub, created_at=user.created_at)
