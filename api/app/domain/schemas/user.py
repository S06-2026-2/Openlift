"""Schemas Pydantic v2 de usuário (resposta pública, sem hashed_password)."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserOut(BaseModel):
    """Retorno público de um usuário.

    `npub` não existe no model `User` — é montado pelo service a partir do
    `NostrIdentity` associado (ver app/services/auth_service.py, Sprint 2).
    """

    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    npub: str | None = None
    created_at: datetime
