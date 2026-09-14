"""Schemas Pydantic v2 de autenticação e registro de identidade NOSTR.

Rascunho do contrato (Sprint 1) — a lógica que usa estes schemas
(hash de senha, emissão de JWT, persistência) é implementada no Sprint 2,
em app/services/auth_service.py e app/api/v1/auth.py.
"""

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, description="Mínimo de 8 caracteres")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class NostrIdentityIn(BaseModel):
    """Corpo de POST /me/nostr-identity.

    Só a chave PÚBLICA (npub), gerada e guardada localmente pelo app — o
    nsec nunca chega ao backend (ver implementation.md, seção de arquitetura).
    """

    npub: str = Field(min_length=1, description="Chave pública NOSTR (npub) gerada no dispositivo")


# TODO(Sprint 4): class RefreshRequest(BaseModel) — refresh_token: str
