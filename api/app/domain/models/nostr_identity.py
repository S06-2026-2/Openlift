"""Model `nostr_identities` — mapeamento invisível user_id <-> npub.

O backend guarda apenas a chave PÚBLICA (npub). A chave privada (nsec) nunca
trafega até aqui: é gerada e assinada localmente no app Flutter.
"""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class NostrIdentity(Base):
    __tablename__ = "nostr_identities"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, nullable=False)
    npub: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
