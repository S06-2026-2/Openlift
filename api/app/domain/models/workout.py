"""Model `workouts` — sessão de treino de um usuário.

Sprint 4 adiciona `shared_event_id`, referência ao evento NOSTR (kind 1)
publicado quando o usuário compartilha o treino.
"""

from datetime import date as date_
from datetime import datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Workout(Base):
    __tablename__ = "workouts"
    # Histórico é sempre "treinos do usuário X por data": um índice composto
    # atende o filtro por usuário e a ordenação/filtro por data de uma vez.
    __table_args__ = (Index("ix_workouts_user_id_date", "user_id", "date"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    date: Mapped[date_] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # TODO(Sprint 4): referência ao evento NOSTR publicado (kind 1), quando o
    # treino é compartilhado. Fica nullable pois nem todo treino é compartilhado.
    shared_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
