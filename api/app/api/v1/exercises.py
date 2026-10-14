"""Biblioteca de exercícios (BE-03, RF-10).

GET /exercises[?muscle_group_id=N] — exercícios com grupo muscular (login exigido)
"""

from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.domain.schemas.exercise import ExerciseOut
from app.services import exercise_service

router = APIRouter()


@router.get(
    "",
    response_model=list[ExerciseOut],
    summary="Biblioteca de exercícios",
    description="Lista os exercícios com o grupo muscular, ordenados por grupo e nome. "
    "Use `muscle_group_id` para filtrar um grupo.",
    responses=error_responses({401: "Não autenticado"}),
)
def list_exercises(
    db: DbSession,
    _user: CurrentUser,
    muscle_group_id: Annotated[int | None, Query(ge=1, description="Filtra por grupo")] = None,
) -> list[ExerciseOut]:
    exercises = exercise_service.list_exercises(db, muscle_group_id)
    return [ExerciseOut.model_validate(e) for e in exercises]
