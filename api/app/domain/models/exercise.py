"""Model `exercises` — biblioteca de exercícios, cada um ligado a um grupo
muscular (taxonomia usada nas agregações de volume e no heatmap).

A biblioteca padrão é populada por app/infra/db/seed.py (idempotente).

`equipment` é o equipamento no vocabulário do NIP-101e, exigido pelo modelo de
exercício (`kind 33401`) que o app publica (ADR-0003, mini-NIP §3). Polia e
cabo entram como `machine`: o rascunho não tem um valor próprio para eles.

TODO(RF-11): exercício customizado por usuário (owner_id nullable + unique
por (owner_id, name)).
"""

from sqlalchemy import CheckConstraint, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.domain.models.muscle_group import MuscleGroup

EQUIPMENT_VALUES = ("barbell", "dumbbell", "bodyweight", "machine", "cardio")


class Exercise(Base):
    __tablename__ = "exercises"
    __table_args__ = (
        CheckConstraint(
            "equipment IN ('barbell', 'dumbbell', 'bodyweight', 'machine', 'cardio')",
            name="ck_exercises_equipment",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    muscle_group_id: Mapped[int] = mapped_column(
        ForeignKey("muscle_groups.id", name="fk_exercises_muscle_group_id_muscle_groups"),
        nullable=False,
        index=True,
    )
    equipment: Mapped[str] = mapped_column(String(16), nullable=False)

    muscle_group: Mapped[MuscleGroup] = relationship(back_populates="exercises")
