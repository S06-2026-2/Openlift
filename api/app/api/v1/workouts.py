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
POST   /workouts/{id}/publication        — registra o treino publicado como kind 1301 (BE-S2-03)
POST   /workouts/{id}/publication-failure — registra que a publicação falhou (BE-S2-03)
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.domain.schemas.workout import (
    PublicationFailureIn,
    PublicationIn,
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
    "repetições até 500, RPE de 1 a 10. Treino `published` precisa de ao menos "
    "uma série (RN-01; senão 422 `published_workout_without_sets`).",
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
    description="Só os campos enviados mudam. `sets`, se enviado, substitui todas as séries. "
    "Não é possível deixar um treino `published` sem séries (RN-01; 422 "
    "`published_workout_without_sets`).",
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
    description="A última série de um treino `published` não pode ser removida "
    "(RN-01; 422 `published_workout_without_sets`). Torne o treino privado antes.",
    responses=error_responses(
        {**_SET_NOT_FOUND, 422: "Última série de um treino publicado (RN-01)"}, validation=False
    ),
)
def delete_set(workout_id: int, set_id: int, db: DbSession, user: CurrentUser) -> Response:
    workout_service.delete_set(db, user, workout_id, set_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


_PUBLICATION_ERRORS = {
    **_NOT_FOUND,
    403: "`pubkey` diferente da identidade NOSTR do usuário (`pubkey_mismatch`)",
    409: "Sem identidade NOSTR registrada, `event_id` já usado em outro treino ou `d_tag` "
    "já usado por outro treino",
}


@router.post(
    "/{workout_id}/publication",
    response_model=WorkoutOut,
    summary="Registrar treino publicado",
    description="O app monta, assina e publica o evento `kind 1301`; esta rota só registra o "
    "resultado: `publish_status` vira `published`, o `d_tag` fica gravado e o `event_id` "
    "entra em `shared_events`. A `pubkey` precisa ser a do `npub` registrado em "
    "`/me/nostr-identity` (403 `pubkey_mismatch`; 409 `nostr_identity_required` se não "
    "houver). Treino sem séries é recusado (RN-01; 422 `published_workout_without_sets`). "
    "**Idempotente por `event_id`**: repetir o mesmo evento não muda nada. **RN-08:** "
    "editar e publicar de novo envia um `event_id` novo com o **mesmo** `d_tag` (senão "
    "422 `d_tag_mismatch`); o evento anterior continua registrado.",
    responses=error_responses(
        {
            **_PUBLICATION_ERRORS,
            422: "Treino sem séries (RN-01), `d_tag` diferente do "
            "já gravado (RN-08) ou dados inválidos",
        }
    ),
)
def publish_workout(
    workout_id: int, payload: PublicationIn, db: DbSession, user: CurrentUser
) -> WorkoutOut:
    workout = workout_service.publish_workout(db, user, workout_id, payload)
    return WorkoutOut.model_validate(workout)


@router.post(
    "/{workout_id}/publication-failure",
    response_model=WorkoutOut,
    summary="Registrar falha de publicação",
    description="O app avisa que não conseguiu publicar o evento em nenhum relay: "
    "`publish_status` vira `failed` (RF-25) e o app pode tentar de novo. Mesmas regras "
    "de `pubkey` da publicação. Idempotente: repetir o aviso mantém `failed`. Um "
    "`event_id` que já foi registrado como publicado não pode falhar (409 "
    "`event_already_published`).",
    responses=error_responses(
        {
            **_PUBLICATION_ERRORS,
            409: "Sem identidade NOSTR registrada ou `event_id` já " "registrado como publicado",
        }
    ),
)
def report_publication_failure(
    workout_id: int, payload: PublicationFailureIn, db: DbSession, user: CurrentUser
) -> WorkoutOut:
    workout = workout_service.report_publication_failure(db, user, workout_id, payload)
    return WorkoutOut.model_validate(workout)
