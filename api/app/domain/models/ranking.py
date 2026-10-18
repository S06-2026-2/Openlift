"""Model `rankings` — pontuação calculada para os treinos/artigos
compartilhados (ex.: curtidas recentes com decaimento por tempo).

Como `likes`, é reconstruível a partir dos eventos (ADR-004); uma linha por
evento compartilhado.
"""

from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class RankingEntry(Base):
    __tablename__ = "rankings"

    id: Mapped[int] = mapped_column(primary_key=True)
    shared_event_id: Mapped[int] = mapped_column(
        ForeignKey(
            "shared_events.id",
            name="fk_rankings_shared_event_id_shared_events",
            ondelete="CASCADE",
        ),
        unique=True,
        nullable=False,
    )
    score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
