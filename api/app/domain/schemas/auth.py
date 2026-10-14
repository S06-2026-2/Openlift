"""Schemas Pydantic v2 de autenticação e registro de identidade NOSTR.

Usados por app/api/v1/auth.py (BE-02). Os exemplos aparecem no Swagger (/docs).
"""

from pydantic import BaseModel, ConfigDict, EmailStr, Field
from pydantic.config import JsonDict

_CREDENTIALS_EXAMPLE: JsonDict = {"email": "ana@openlift.dev", "password": "senha-segura-123"}


class RegisterRequest(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [_CREDENTIALS_EXAMPLE]})

    email: EmailStr
    password: str = Field(min_length=8, max_length=128, description="Mínimo de 8 caracteres")


class LoginRequest(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [_CREDENTIALS_EXAMPLE]})

    email: EmailStr
    password: str = Field(max_length=128)


class RefreshRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={"examples": [{"refresh_token": "eyJhbGciOiJIUzI1NiIs..."}]}
    )

    refresh_token: str = Field(min_length=1, description="Refresh token recebido no login")


class TokenPair(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "access_token": "eyJhbGciOiJIUzI1NiIs...",
                    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
                    "token_type": "bearer",
                }
            ]
        }
    )

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class NostrIdentityIn(BaseModel):
    """Corpo de POST /me/nostr-identity.

    Só a chave PÚBLICA (npub), gerada e guardada localmente pelo app — o
    nsec nunca chega ao backend (ver implementation.md, seção de arquitetura).
    """

    npub: str = Field(min_length=1, description="Chave pública NOSTR (npub) gerada no dispositivo")
