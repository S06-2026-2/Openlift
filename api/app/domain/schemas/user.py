"""Schemas Pydantic v2 de usuário (resposta pública, sem hashed_password)."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserOut(BaseModel):
    """Retorno público de um usuário.

    `npub` não existe no model `User` — é montado pelo service a partir do
    `NostrIdentity` associado (ver app/services/auth_service.py, Sprint 2).
    """

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "id": 1,
                    "email": "ana@openlift.dev",
                    "npub": None,
                    "created_at": "2026-10-14T12:00:00Z",
                }
            ]
        },
    )

    id: int
    email: str
    npub: str | None = None
    created_at: datetime
