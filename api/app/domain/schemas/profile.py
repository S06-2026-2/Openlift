"""Schemas Pydantic v2 do perfil da rede social (ADR-0012)."""

import re
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

USERNAME_PATTERN = re.compile(r"^[a-z0-9_.]{3,20}$")
USERNAME_RULE = "De 3 a 20 caracteres: letras sem acento, números, _ e ponto."

_EXAMPLE: dict[str, Any] = {
    "username": "ana.treina",
    "display_name": "Ana",
    "bio": "Powerlifting e corrida aos domingos.",
    "avatar_url": "https://api.openlift.dev/media/3f2c9a1e.webp",
    "npub": "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6",
    "pubkey": "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
    "nip05": "ana.treina@api.openlift.dev",
}


def normalize_username(value: str) -> str:
    """Tira espaços e `@` do começo e passa para minúsculas."""
    return value.strip().lstrip("@").lower()


def _blank_to_none(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


class ProfileIn(BaseModel):
    """Criação ou edição do próprio perfil."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {k: _EXAMPLE[k] for k in ("username", "display_name", "bio", "avatar_url")}
            ]
        },
    )

    username: str = Field(description=USERNAME_RULE)
    display_name: str | None = Field(default=None, max_length=50)
    bio: str | None = Field(default=None, max_length=160)
    avatar_url: str | None = Field(
        default=None, max_length=500, description="URL http(s) da foto, de preferência de /media"
    )

    @field_validator("username")
    @classmethod
    def _username(cls, value: str) -> str:
        username = normalize_username(value)
        if not USERNAME_PATTERN.match(username):
            raise ValueError(USERNAME_RULE)
        return username

    @field_validator("display_name", "bio")
    @classmethod
    def _optional_text(cls, value: str | None) -> str | None:
        return _blank_to_none(value)

    @field_validator("avatar_url")
    @classmethod
    def _avatar(cls, value: str | None) -> str | None:
        url = _blank_to_none(value)
        if url is not None and not url.startswith(("https://", "http://")):
            raise ValueError("A foto precisa ser uma URL http(s).")
        return url


class ProfileOut(BaseModel):
    """Perfil público: o que qualquer pessoa logada pode ver."""

    model_config = ConfigDict(json_schema_extra={"examples": [_EXAMPLE]})

    username: str
    display_name: str | None
    bio: str | None
    avatar_url: str | None
    npub: str = Field(description="ID público da pessoa na rede (NIP-19)")
    pubkey: str = Field(description="Mesma chave em hex, como aparece nos eventos")
    nip05: str = Field(description="Nome verificado no formato NIP-05 (usuario@dominio)")


class UsernameAvailabilityOut(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={"examples": [{"username": "ana.treina", "available": False}]}
    )

    username: str = Field(description="Nome já normalizado (minúsculas)")
    available: bool = Field(description="`true` também quando o nome já é do próprio usuário")
