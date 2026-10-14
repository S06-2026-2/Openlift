"""CRUD de treinos e séries (BE-04). Rotas finas: a regra fica em
app/services/workout_service.py. Todas exigem login e só enxergam os treinos
do próprio usuário (treino de outra pessoa → 404).

POST   /workouts                        — cria treino (com séries)
GET    /workouts                        — histórico paginado, com filtros
GET    /workouts/{id}                   — detalha um treino
PATCH  /workouts/{id}                   — edita data/visibilidade/séries
DELETE /workouts/{id}                   — remove o treino e suas séries
POST   /workouts/{id}/sets              — adiciona uma série
PATCH  /workouts/{id}/sets/{set_id}     — edita uma série
DELETE /workouts/{id}/sets/{set_id}     — remove uma série
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.domain.schemas.workout import (
    SetIn,
    SetOut,
    SetUpdate,
    WorkoutIn,
    WorkoutOut,
    WorkoutPage,
    WorkoutUpdate,
)
from app.services import workout_service
from app.services.workout_service import WorkoutFilters

router = APIRouter()

_NOT_FOUND = {401: "Não autenticado", 404: "Treino não encontrado (ou de outro usuário)"}
_SET_NOT_FOUND = {**_NOT_FOUND, 404: "Treino ou série não encontrados"}


@router.post(
    "",
    response_model=WorkoutOut,
    status_code=status.HTTP_201_CREATED,
    summary="Criar treino",
    description="Cria um treino com suas séries. Limites: carga até 1000 kg, "
    "repetições até 500, RPE de 1 a 10.",
    responses=error_responses({401: "Não autenticado"}),
)
def create_workout(payload: WorkoutIn, db: DbSession, user: CurrentUser) -> WorkoutOut:
    workout = workout_service.create_workout(db, user, payload)
    return WorkoutOut.model_validate(workout)


@router.get(
    "",
    response_model=WorkoutPage,
    summary="Histórico de treinos",
    description="Treinos do usuário, do mais novo para o mais antigo. Filtros "
    "combináveis por período (inclusivo), exercício e grupo muscular.",
    responses=error_responses({401: "Não autenticado"}),
)
def list_workouts(
    db: DbSession,
    user: CurrentUser,
    date_from: Annotated[date | None, Query(description="Data inicial (inclusiva)")] = None,
    date_to: Annotated[date | None, Query(description="Data final (inclusiva)")] = None,
    exercise_id: Annotated[int | None, Query(ge=1, description="Contém este exercício")] = None,
    muscle_group_id: Annotated[int | None, Query(ge=1, description="Contém este grupo")] = None,
    limit: Annotated[int, Query(ge=1, le=100, description="Itens por página")] = 50,
    offset: Annotated[int, Query(ge=0, description="Quantos itens pular")] = 0,
) -> WorkoutPage:
    filters = WorkoutFilters(date_from, date_to, exercise_id, muscle_group_id)
    items, total = workout_service.list_workouts(db, user, filters, limit=limit, offset=offset)
    return WorkoutPage(
        items=[WorkoutOut.model_validate(w) for w in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/{workout_id}",
    response_model=WorkoutOut,
    summary="Detalhar treino",
    responses=error_responses(_NOT_FOUND, validation=False),
)
def get_workout(workout_id: int, db: DbSession, user: CurrentUser) -> WorkoutOut:
    return WorkoutOut.model_validate(workout_service.get_workout(db, user, workout_id))


@router.patch(
    "/{workout_id}",
    response_model=WorkoutOut,
    summary="Editar treino",
    description="Só os campos enviados mudam. `sets`, se enviado, substitui todas as séries.",
    responses=error_responses(_NOT_FOUND),
)
def update_workout(
    workout_id: int, payload: WorkoutUpdate, db: DbSession, user: CurrentUser
) -> WorkoutOut:
    workout = workout_service.update_workout(db, user, workout_id, payload)
    return WorkoutOut.model_validate(workout)


@router.delete(
    "/{workout_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Excluir treino",
    responses=error_responses(_NOT_FOUND, validation=False),
)
def delete_workout(workout_id: int, db: DbSession, user: CurrentUser) -> Response:
    workout_service.delete_workout(db, user, workout_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{workout_id}/sets",
    response_model=SetOut,
    status_code=status.HTTP_201_CREATED,
    summary="Adicionar série",
    responses=error_responses(_NOT_FOUND),
)
def add_set(workout_id: int, payload: SetIn, db: DbSession, user: CurrentUser) -> SetOut:
    return SetOut.model_validate(workout_service.add_set(db, user, workout_id, payload))


@router.patch(
    "/{workout_id}/sets/{set_id}",
    response_model=SetOut,
    summary="Editar série",
    description="Só os campos enviados mudam; `rpe: null` limpa o RPE.",
    responses=error_responses(_SET_NOT_FOUND),
)
def update_set(
    workout_id: int, set_id: int, payload: SetUpdate, db: DbSession, user: CurrentUser
) -> SetOut:
    workout_set = workout_service.update_set(db, user, workout_id, set_id, payload)
    return SetOut.model_validate(workout_set)


@router.delete(
    "/{workout_id}/sets/{set_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remover série",
    responses=error_responses(_SET_NOT_FOUND, validation=False),
)
def delete_set(workout_id: int, set_id: int, db: DbSession, user: CurrentUser) -> Response:
    workout_service.delete_set(db, user, workout_id, set_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
