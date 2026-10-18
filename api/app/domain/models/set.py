"""Model `sets` — uma série dentro de um treino (exercício, reps, carga, RPE).

`exercise_id` aponta para a biblioteca em `exercises` (FK desde o BE-03).
"""

from decimal import Decimal

from sqlalchemy import ForeignKey, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkoutSet(Base):
    __tablename__ = "sets"

    id: Mapped[int] = mapped_column(primary_key=True)
    workout_id: Mapped[int] = mapped_column(ForeignKey("workouts.id"), nullable=False, index=True)
    exercise_id: Mapped[int] = mapped_column(
        ForeignKey("exercises.id", name="fk_sets_exercise_id_exercises"),
        nullable=False,
        index=True,
    )
    reps: Mapped[int] = mapped_column(Integer, nullable=False)
    weight_kg: Mapped[Decimal] = mapped_column(Numeric(6, 2), nullable=False)
    rpe: Mapped[Decimal | None] = mapped_column(Numeric(3, 1), nullable=True)
