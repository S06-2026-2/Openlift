"""Exemplo da skill criar-endpoint-fastapi — recurso fictício "notas do treino".

NÃO é código do app: mostra, num arquivo só, as quatro peças que no projeto
ficam separadas. Copie o padrão, não o recurso.

    api/app/domain/schemas/note.py     -> NoteIn, NoteOut
    api/app/services/note_service.py   -> create_note, list_notes
    api/app/api/v1/notes.py            -> rotas finas
    api/tests/test_notes.py            -> testes
"""

from typing import Annotated

from fastapi import APIRouter, Query, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.core.errors import ApiError
from app.domain.models.user import User
from app.domain.models.workout import Workout

# --- 1. Schema (api/app/domain/schemas/note.py) ------------------------------


class NoteIn(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [{"text": "Senti o ombro."}]})

    text: str = Field(min_length=1, max_length=500)


class NoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    workout_id: int
    text: str


# --- 2. Service (api/app/services/note_service.py) ---------------------------


def _get_own_workout(db: Session, user: User, workout_id: int) -> Workout:
    """Treino do próprio usuário; de outra pessoa responde 404 (não vaza existência)."""
    workout = db.scalar(select(Workout).where(Workout.id == workout_id, Workout.user_id == user.id))
    if workout is None:
        raise ApiError(404, "Treino não encontrado.", "workout_not_found")
    return workout


def create_note(db: Session, user: User, workout_id: int, payload: NoteIn) -> NoteOut:
    workout = _get_own_workout(db, user, workout_id)
    # ... cria e persiste a nota ligada a `workout` ...
    return NoteOut(id=1, workout_id=workout.id, text=payload.text)


# --- 3. Rota fina (api/app/api/v1/notes.py) ----------------------------------

router = APIRouter()

_NOT_FOUND = {401: "Não autenticado", 404: "Treino não encontrado (ou de outro usuário)"}


@router.post(
    "/{workout_id}/notes",
    response_model=NoteOut,
    status_code=status.HTTP_201_CREATED,
    summary="Adicionar nota ao treino",
    responses=error_responses(_NOT_FOUND),
)
def add_note(workout_id: int, payload: NoteIn, db: DbSession, user: CurrentUser) -> NoteOut:
    return create_note(db, user, workout_id, payload)


@router.get(
    "/{workout_id}/notes",
    response_model=list[NoteOut],
    summary="Notas do treino",
    responses=error_responses(_NOT_FOUND),
)
def list_notes(
    workout_id: int,
    db: DbSession,
    user: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=100, description="Itens por página")] = 50,
) -> list[NoteOut]:
    _get_own_workout(db, user, workout_id)
    return []


# --- 4. Testes (api/tests/test_notes.py) -------------------------------------
#
# def test_add_note_returns_201(client, auth_headers, workout):
#     response = client.post(
#         f"/api/v1/workouts/{workout.id}/notes", json={"text": "ok"}, headers=auth_headers
#     )
#     assert response.status_code == 201
#     assert response.json()["text"] == "ok"
#
# def test_add_note_without_token_returns_401(client, workout):
#     response = client.post(f"/api/v1/workouts/{workout.id}/notes", json={"text": "ok"})
#     assert response.status_code == 401
#     assert response.json()["code"] == "not_authenticated"
#
# def test_add_note_on_other_users_workout_returns_404(client, other_user_headers, workout):
#     response = client.post(
#         f"/api/v1/workouts/{workout.id}/notes", json={"text": "ok"}, headers=other_user_headers
#     )
#     assert response.status_code == 404
#     assert response.json()["code"] == "workout_not_found"
#
# def test_add_note_empty_text_returns_422(client, auth_headers, workout):
#     response = client.post(
#         f"/api/v1/workouts/{workout.id}/notes", json={"text": ""}, headers=auth_headers
#     )
#     assert response.status_code == 422
#     assert response.json()["errors"][0]["field"] == "text"
