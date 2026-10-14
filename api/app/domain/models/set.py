"""Model `sets` — uma série dentro de um treino (exercício, reps, carga, RPE,
tipo).

- `exercise_id` aponta para a biblioteca em `exercises` (FK desde o BE-03);
- `set_type` (RF-13): warmup | normal | failure. Aquecimento não conta para
  volume nem PR (RN-02/RN-03).
"""

from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkoutSet(Base):
    __tablename__ = "sets"
    __table_args__ = (
        CheckConstraint("set_type IN ('warmup', 'normal', 'failure')", name="ck_sets_set_type"),
    )

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
    set_type: Mapped[str] = mapped_column(
        String(16), nullable=False, default="normal", server_default="normal"
    )
