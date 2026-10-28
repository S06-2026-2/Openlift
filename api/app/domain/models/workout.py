"""Model `workouts` — sessão de treino de um usuário.

Campos da publicação no NOSTR (alterados só pelos fluxos de publicação, BE-S2-03):
- `visibility` (RF-21): private | published — escolha do usuário por treino;
- `publish_status` (RF-25): local | published | failed — estado da publicação;
- `d_tag`: UUID v4 da tag `d` do kind 1301 (mini-NIP §2.2). Fixado na primeira
  publicação e reutilizado quando o treino é republicado após edição, gerando
  um evento novo com o mesmo `d` (RN-08).

Os eventos publicados (um por publicação) ficam em `shared_events`, ligados ao
treino por `workout_id`: um treino pode ter vários (RN-08), então não existe
coluna `shared_event_id` aqui.
"""

from datetime import date as date_
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.domain.models.set import WorkoutSet


class Workout(Base):
    __tablename__ = "workouts"
    # Histórico é sempre "treinos do usuário X por data": um índice composto
    # atende o filtro por usuário e a ordenação/filtro por data de uma vez.
    __table_args__ = (
        Index("ix_workouts_user_id_date", "user_id", "date"),
        # `d` só precisa ser único por autor (o endereço NOSTR é pubkey + d).
        UniqueConstraint("user_id", "d_tag", name="uq_workouts_user_id_d_tag"),
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
    d_tag: Mapped[str | None] = mapped_column(String(36), nullable=True)

    # Séries na ordem em que foram registradas; somem junto com o treino.
    sets: Mapped[list[WorkoutSet]] = relationship(
        order_by=WorkoutSet.id, cascade="all, delete-orphan"
    )
