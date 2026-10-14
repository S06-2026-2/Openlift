"""Model `workouts` — sessão de treino de um usuário.

Campos reservados para a publicação no NOSTR (ainda sem lógica):
- `visibility` (RF-21): private | published — escolha do usuário por treino;
- `publish_status` (RF-25): local | published | failed — estado da publicação;
- `shared_event_id`: id do evento publicado (kind 1301, ADR-003).
"""

from datetime import date as date_
from datetime import datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.domain.models.set import WorkoutSet


class Workout(Base):
    __tablename__ = "workouts"
    # Histórico é sempre "treinos do usuário X por data": um índice composto
    # atende o filtro por usuário e a ordenação/filtro por data de uma vez.
    __table_args__ = (
        Index("ix_workouts_user_id_date", "user_id", "date"),
        CheckConstraint("visibility IN ('private', 'published')", name="ck_workouts_visibility"),
        CheckConstraint(
            "publish_status IN ('local', 'published', 'failed')", name="ck_workouts_publish_status"
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    date: Mapped[date_] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    visibility: Mapped[str] = mapped_column(
        String(16), nullable=False, default="private", server_default="private"
    )
    publish_status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="local", server_default="local"
    )
    shared_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Séries na ordem em que foram registradas; somem junto com o treino.
    sets: Mapped[list[WorkoutSet]] = relationship(
        order_by=WorkoutSet.id, cascade="all, delete-orphan"
    )
