"""Autenticação: hash de senha (passlib) e emissão/validação de JWT (PyJWT).

Importante: este módulo NUNCA lida com chaves NOSTR (nsec) — apenas com a
sessão tradicional (e-mail/senha) do OpenLift. A chave NOSTR é gerada e
assinada no dispositivo do usuário (ver app/features/auth no Flutter).
"""

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

import jwt
from jwt import InvalidTokenError
from passlib.context import CryptContext

from app.core.config import get_settings

__all__ = [
    "InvalidTokenError",
    "create_access_token",
    "create_refresh_token",
    "decode_token",
    "hash_password",
    "verify_password",
]

TokenType = Literal["access", "refresh"]

# bcrypt é lento de propósito (dificulta força bruta); o salt é gerado e
# embutido no próprio hash automaticamente.
_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------------------------------------------------------------------------
# Senhas
# ---------------------------------------------------------------------------


def hash_password(password: str) -> str:
    """Gera o hash bcrypt (com salt) de uma senha em texto puro."""
    return _pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """Confere a senha contra o hash. Retorna False (nunca levanta) se o hash for inválido."""
    try:
        return _pwd_context.verify(password, password_hash)
    except (ValueError, TypeError):
        return False


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------


def _create_token(user_id: int | str, token_type: TokenType, expires_delta: timedelta) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": str(user_id),  # a spec JWT exige 'sub' como string
        "type": token_type,  # impede usar um refresh token como access token (e vice-versa)
        "iat": now,
        "exp": now + expires_delta,
        "jti": uuid.uuid4().hex,  # id único: permite revogação futura e evita tokens idênticos
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int | str) -> str:
    """Token de curta duração (JWT_EXPIRATION_MINUTES) enviado em cada requisição."""
    minutes = get_settings().jwt_expiration_minutes
    return _create_token(user_id, "access", timedelta(minutes=minutes))


def create_refresh_token(user_id: int | str) -> str:
    """Token de longa duração (JWT_REFRESH_EXPIRATION_DAYS), usado só para renovar o access."""
    days = get_settings().jwt_refresh_expiration_days
    return _create_token(user_id, "refresh", timedelta(days=days))


def decode_token(token: str, expected_type: TokenType = "access") -> dict[str, Any]:
    """Valida assinatura, expiração e tipo do token e devolve o payload.

    Levanta `InvalidTokenError` (ou subclasses, ex.: ExpiredSignatureError)
    se o token estiver expirado, adulterado, malformado ou for do tipo errado.
    """
    settings = get_settings()
    payload: dict[str, Any] = jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],  # lista fixa: bloqueia ataque "alg: none"
        options={"require": ["sub", "exp", "iat", "type"]},
    )
    if payload.get("type") != expected_type:
        raise InvalidTokenError(f"Tipo de token inválido: esperado '{expected_type}'")
    return payload
