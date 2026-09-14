"""Model `sets` — uma série dentro de um treino (exercício, reps, carga, RPE).

`exercise_id` ainda não tem uma foreign key de verdade porque o model
`Exercise` (Sprint 3) não existe como tabela ainda — vira FK real assim que
a taxonomia de exercícios for criada.
"""

from decimal import Decimal

from sqlalchemy import ForeignKey, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkoutSet(Base):
    __tablename__ = "sets"

    id: Mapped[int] = mapped_column(primary_key=True)
    workout_id: Mapped[int] = mapped_column(ForeignKey("workouts.id"), nullable=False, index=True)
    # TODO(Sprint 3): trocar para ForeignKey("exercises.id") quando o model Exercise existir.
    exercise_id: Mapped[int] = mapped_column(Integer, nullable=False)
    reps: Mapped[int] = mapped_column(Integer, nullable=False)
    weight_kg: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    rpe: Mapped[Decimal | None] = mapped_column(Numeric(3, 1), nullable=True)
