"""Model `likes` — cache local das reações NIP-25 (kind 7) lidas dos relays
pelo worker de sincronização. Existe para permitir contagens rápidas via SQL
em vez de varrer relays a cada requisição.

ADR-004: a origem é sempre um evento assinado; esta tabela é reconstruível
por replay. RN-06: like é idempotente — o par (event_id, liker_pubkey) é
único, então reprocessar o mesmo kind 7 não conta duas vezes.
"""

from datetime import datetime

from sqlalchemy import DateTime, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Like(Base):
    __tablename__ = "likes"
    __table_args__ = (UniqueConstraint("event_id", "liker_pubkey", name="uq_likes_event_liker"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    # Evento curtido e chave pública de quem curtiu (ambos hex de 64 caracteres).
    event_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    liker_pubkey: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
