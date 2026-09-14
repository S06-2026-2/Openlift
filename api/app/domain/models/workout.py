"""Model `workouts` — sessão de treino de um usuário.

Sprint 4 adiciona `shared_event_id`, referência ao evento NOSTR (kind 1)
publicado quando o usuário compartilha o treino.
"""

from datetime import date as date_
from datetime import datetime

from sqlalchemy import Date, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Workout(Base):
    __tablename__ = "workouts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    date: Mapped[date_] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # TODO(Sprint 4): referência ao evento NOSTR publicado (kind 1), quando o
    # treino é compartilhado. Fica nullable pois nem todo treino é compartilhado.
    shared_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
