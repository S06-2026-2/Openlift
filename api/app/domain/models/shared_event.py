"""Model `shared_events` — referência entre um registro local (treino) e o
evento NOSTR publicado para representá-lo (kind 1301 para treino, conforme
ADR-003; kind 30023 para artigo).

Permite que `likes` e `rankings` apontem para algo que o backend entende,
sem duplicar o conteúdo do evento (que já vive nos relays — ADR-004).
"""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class SharedEvent(Base):
    __tablename__ = "shared_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    # Nulo para artigos (não vêm de um treino) ou se o treino for excluído.
    workout_id: Mapped[int | None] = mapped_column(
        ForeignKey(
            "workouts.id",
            name="fk_shared_events_workout_id_workouts",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )
    # id do evento NOSTR: hash SHA-256 em hex (64 caracteres).
    event_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    kind: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
