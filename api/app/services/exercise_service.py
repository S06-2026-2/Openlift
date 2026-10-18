"""Leitura da biblioteca de exercícios (BE-03)."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.domain.models.exercise import Exercise
from app.domain.models.muscle_group import MuscleGroup


def list_exercises(db: Session, muscle_group_id: int | None = None) -> Sequence[Exercise]:
    """Exercícios com o grupo já carregado, ordenados por grupo e nome."""
    query = (
        select(Exercise)
        .join(Exercise.muscle_group)
        .options(joinedload(Exercise.muscle_group))
        .order_by(MuscleGroup.name, Exercise.name)
    )
    if muscle_group_id is not None:
        query = query.where(Exercise.muscle_group_id == muscle_group_id)
    return db.scalars(query).all()
