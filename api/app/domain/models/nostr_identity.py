"""Model `nostr_identities` — mapeamento invisível user_id <-> npub.

O backend guarda apenas a chave PÚBLICA, em dois formatos:
- `npub`: NIP-19 (bech32), como o app envia e devolve ao usuário;
- `pubkey_hex`: a mesma chave em hex (64 caracteres minúsculos), que é o que
  aparece nos eventos NOSTR (`event.pubkey`, `likes.liker_pubkey`). É sempre
  derivado do `npub` por app/core/nostr.py.

A chave privada (nsec) nunca trafega até aqui: é gerada e assinada
localmente no app Flutter.
"""

from datetime import datetime

from sqlalchemy import CHAR, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class NostrIdentity(Base):
    __tablename__ = "nostr_identities"
    __table_args__ = (UniqueConstraint("pubkey_hex", name="uq_nostr_identities_pubkey_hex"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", name="fk_nostr_identities_user_id_users"),
        unique=True,
        nullable=False,
    )
    npub: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    pubkey_hex: Mapped[str] = mapped_column(CHAR(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
