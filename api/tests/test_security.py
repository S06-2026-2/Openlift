"""Testes de app.core.security: hash de senha e tokens JWT (BE-01)."""

from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import get_settings
from app.core.security import (
    InvalidTokenError,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)

# ---------------------------------------------------------------------------
# Senhas
# ---------------------------------------------------------------------------


def test_hash_password_differs_from_plain_text() -> None:
    assert hash_password("senha-forte-123") != "senha-forte-123"


def test_hash_password_uses_random_salt() -> None:
    """Mesma senha gera hashes diferentes (salt), mas ambos verificam."""
    h1, h2 = hash_password("abc12345"), hash_password("abc12345")
    assert h1 != h2
    assert verify_password("abc12345", h1) and verify_password("abc12345", h2)


def test_verify_password_correct_and_wrong() -> None:
    password_hash = hash_password("correta-123")
    assert verify_password("correta-123", password_hash) is True
    assert verify_password("errada-123", password_hash) is False


def test_verify_password_invalid_hash_returns_false() -> None:
    assert verify_password("qualquer", "isto-nao-e-um-hash") is False


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------


def test_access_token_roundtrip() -> None:
    payload = decode_token(create_access_token(42))
    assert payload["sub"] == "42"
    assert payload["type"] == "access"


def test_refresh_token_roundtrip() -> None:
    payload = decode_token(create_refresh_token(42), expected_type="refresh")
    assert payload["sub"] == "42"
    assert payload["type"] == "refresh"


def test_access_token_expires_in_configured_minutes() -> None:
    payload = decode_token(create_access_token(1))
    ttl = payload["exp"] - payload["iat"]
    assert ttl == get_settings().jwt_expiration_minutes * 60


def test_refresh_token_lives_longer_than_access() -> None:
    access = decode_token(create_access_token(1))
    refresh = decode_token(create_refresh_token(1), expected_type="refresh")
    assert refresh["exp"] > access["exp"]


def test_tokens_are_unique_per_call() -> None:
    assert create_access_token(1) != create_access_token(1)


def test_refresh_token_rejected_as_access() -> None:
    with pytest.raises(InvalidTokenError):
        decode_token(create_refresh_token(1))  # espera "access" por padrão


def test_access_token_rejected_as_refresh() -> None:
    with pytest.raises(InvalidTokenError):
        decode_token(create_access_token(1), expected_type="refresh")


def test_expired_token_rejected() -> None:
    settings = get_settings()
    past = datetime.now(UTC) - timedelta(hours=1)
    expired = jwt.encode(
        {"sub": "1", "type": "access", "iat": past - timedelta(minutes=5), "exp": past},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    with pytest.raises(jwt.ExpiredSignatureError):
        decode_token(expired)


def test_tampered_token_rejected() -> None:
    token = create_access_token(1)
    header, payload, signature = token.split(".")
    bad_signature = signature[:-2] + ("AA" if signature[-2:] != "AA" else "BB")
    tampered = ".".join([header, payload, bad_signature])
    with pytest.raises(InvalidTokenError):
        decode_token(tampered)


def test_token_signed_with_other_secret_rejected() -> None:
    now = datetime.now(UTC)
    forged = jwt.encode(
        {"sub": "1", "type": "access", "iat": now, "exp": now + timedelta(minutes=5)},
        "outro-segredo-qualquer-com-32-bytes!!",
        algorithm="HS256",
    )
    with pytest.raises(InvalidTokenError):
        decode_token(forged)


def test_alg_none_token_rejected() -> None:
    now = datetime.now(UTC)
    unsigned = jwt.encode(
        {"sub": "1", "type": "access", "iat": now, "exp": now + timedelta(minutes=5)},
        key=None,
        algorithm="none",
    )
    with pytest.raises(InvalidTokenError):
        decode_token(unsigned)


def test_token_missing_required_claims_rejected() -> None:
    settings = get_settings()
    incomplete = jwt.encode({"sub": "1"}, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError):
        decode_token(incomplete)


def test_malformed_token_rejected() -> None:
    with pytest.raises(InvalidTokenError):
        decode_token("nao.e.jwt")
