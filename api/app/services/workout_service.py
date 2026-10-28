"""Regras de negócio de treinos e séries (BE-04).

Isolamento: todo acesso filtra por `user.id`. Treino de outro usuário
responde 404 — o mesmo que um treino inexistente, para não vazar existência.

RN-01: treino publicado precisa ter ao menos uma série. A regra envolve duas
tabelas (workouts.visibility e a contagem em sets), então fica aqui e não num
CHECK do banco; toda operação que pode deixar um treino `published` sem
séries é recusada com 422 antes de mudar qualquer coisa.

Publicação (BE-S2-03): o app monta, assina e publica o kind 1301; o backend só
registra o resultado. Quem altera `visibility`/`publish_status`/`d_tag` são
estas rotas (`publish_workout` e `report_publication_failure`), nunca o PATCH.
- a `pubkey` informada precisa ser a do npub registrado do chamador;
- idempotente por `event_id`: repetir o aviso não duplica nada;
- RN-08: republicar após edição é um `event_id` novo com o MESMO `d_tag`; o
  evento anterior continua em `shared_events`.
"""

from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date

from sqlalchemy import Select, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.errors import ApiError
from app.core.nostr import KIND_WORKOUT_RECORD
from app.domain.models.exercise import Exercise
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.set import WorkoutSet
from app.domain.models.shared_event import SharedEvent
from app.domain.models.user import User
from app.domain.models.workout import Workout
from app.domain.schemas.workout import (
    MAX_SETS_PER_WORKOUT,
    PublicationFailureIn,
    PublicationIn,
    SetIn,
    SetUpdate,
    WorkoutIn,
    WorkoutUpdate,
)


@dataclass(frozen=True)
class WorkoutFilters:
    date_from: date | None = None
    date_to: date | None = None
    exercise_id: int | None = None
    muscle_group_id: int | None = None


def _workout_not_found() -> ApiError:
    return ApiError(404, "Treino não encontrado.", "workout_not_found")


def _set_not_found() -> ApiError:
    return ApiError(404, "Série não encontrada.", "set_not_found")


def _ensure_publishable(visibility: str, set_count: int) -> None:
    """RN-01: recusa o estado final "publicado e sem séries"."""
    if visibility == "published" and set_count == 0:
        raise ApiError(
            422,
            "Treino publicado precisa ter ao menos uma série.",
            "published_workout_without_sets",
        )


def _ensure_exercises_exist(db: Session, exercise_ids: Iterable[int]) -> None:
    wanted = set(exercise_ids)
    if not wanted:
        return
    found = set(db.scalars(select(Exercise.id).where(Exercise.id.in_(wanted))))
    missing = sorted(wanted - found)
    if missing:
        ids = ", ".join(str(i) for i in missing)
        raise ApiError(422, f"Exercício não encontrado: {ids}.", "unknown_exercise")


def _new_set(data: SetIn) -> WorkoutSet:
    return WorkoutSet(
        exercise_id=data.exercise_id,
        reps=data.reps,
        weight_kg=data.weight_kg,
        rpe=data.rpe,
        set_type=data.set_type,
    )


def _owned_query(user: User) -> Select[tuple[Workout]]:
    return select(Workout).where(Workout.user_id == user.id)


# ---------------------------------------------------------------------------
# Treinos
# ---------------------------------------------------------------------------


def create_workout(db: Session, user: User, payload: WorkoutIn) -> Workout:
    _ensure_publishable(payload.visibility, len(payload.sets))
    _ensure_exercises_exist(db, (s.exercise_id for s in payload.sets))
    workout = Workout(
        user_id=user.id,
        date=payload.date,
        visibility=payload.visibility,
        sets=[_new_set(s) for s in payload.sets],
    )
    db.add(workout)
    db.commit()
    db.refresh(workout)
    return workout


def list_workouts(
    db: Session,
    user: User,
    filters: WorkoutFilters,
    *,
    limit: int,
    offset: int,
) -> tuple[Sequence[Workout], int]:
    if filters.date_from and filters.date_to and filters.date_from > filters.date_to:
        raise ApiError(
            422, "A data inicial precisa ser anterior à data final.", "invalid_date_range"
        )

    query = _owned_query(user)
    if filters.date_from is not None:
        query = query.where(Workout.date >= filters.date_from)
    if filters.date_to is not None:
        query = query.where(Workout.date <= filters.date_to)
    if filters.exercise_id is not None:
        query = query.where(
            Workout.id.in_(
                select(WorkoutSet.workout_id).where(WorkoutSet.exercise_id == filters.exercise_id)
            )
        )
    if filters.muscle_group_id is not None:
        query = query.where(
            Workout.id.in_(
                select(WorkoutSet.workout_id)
                .join(Exercise, Exercise.id == WorkoutSet.exercise_id)
                .where(Exercise.muscle_group_id == filters.muscle_group_id)
            )
        )

    total = db.scalar(select(func.count()).select_from(query.subquery())) or 0
    items = db.scalars(
        query.options(selectinload(Workout.sets))
        .order_by(Workout.date.desc(), Workout.id.desc())
        .limit(limit)
        .offset(offset)
    ).all()
    return items, total


def get_workout(db: Session, user: User, workout_id: int) -> Workout:
    workout = db.scalar(
        _owned_query(user).where(Workout.id == workout_id).options(selectinload(Workout.sets))
    )
    if workout is None:
        raise _workout_not_found()
    return workout


def update_workout(db: Session, user: User, workout_id: int, payload: WorkoutUpdate) -> Workout:
    workout = get_workout(db, user, workout_id)
    if payload.visibility is not None or payload.sets is not None:
        _ensure_publishable(
            payload.visibility or workout.visibility,
            len(payload.sets) if payload.sets is not None else len(workout.sets),
        )
    if payload.date is not None:
        workout.date = payload.date
    if payload.visibility is not None:
        workout.visibility = payload.visibility
    if payload.sets is not None:
        _ensure_exercises_exist(db, (s.exercise_id for s in payload.sets))
        workout.sets.clear()  # delete-orphan apaga as séries antigas
        db.flush()
        workout.sets.extend(_new_set(s) for s in payload.sets)
    db.commit()
    db.refresh(workout)
    return workout


def delete_workout(db: Session, user: User, workout_id: int) -> None:
    workout = get_workout(db, user, workout_id)
    db.delete(workout)
    db.commit()


# ---------------------------------------------------------------------------
# Publicação (BE-S2-03)
# ---------------------------------------------------------------------------


def _ensure_caller_pubkey(db: Session, user: User, pubkey: str) -> None:
    """A `pubkey` do evento tem de ser a do npub registrado do chamador.

    Sem isso, qualquer usuário logado poderia registrar como publicado um evento
    de outra identidade. O hex vem sempre de `nostr_identities`, nunca do cliente.
    """
    own = db.scalar(select(NostrIdentity.pubkey_hex).where(NostrIdentity.user_id == user.id))
    if own is None:
        raise ApiError(
            409,
            "Registre sua identidade NOSTR antes de publicar treinos.",
            "nostr_identity_required",
        )
    if own != pubkey:
        raise ApiError(403, "A chave pública do evento não é a da sua conta.", "pubkey_mismatch")


def _find_shared_event(db: Session, event_id: str) -> SharedEvent | None:
    return db.scalar(select(SharedEvent).where(SharedEvent.event_id == event_id))


def publish_workout(db: Session, user: User, workout_id: int, payload: PublicationIn) -> Workout:
    """Registra que o app publicou o treino como evento kind 1301.

    Idempotente por `event_id`: o mesmo evento já registrado neste treino devolve
    o estado atual sem mudar nada. Um `event_id` novo num treino já publicado é
    uma republicação (RN-08): cria outra linha em `shared_events` e exige o
    mesmo `d_tag`.
    """
    workout = get_workout(db, user, workout_id)
    _ensure_caller_pubkey(db, user, payload.pubkey)

    registered = _find_shared_event(db, payload.event_id)
    if registered is not None:
        if registered.workout_id == workout.id:
            return workout
        raise ApiError(
            409, "Este evento já está registrado em outro treino.", "event_id_already_registered"
        )

    _ensure_publishable("published", len(workout.sets))  # RN-01

    if workout.d_tag is None:
        taken = db.scalar(
            select(Workout.id).where(Workout.user_id == user.id, Workout.d_tag == payload.d_tag)
        )
        if taken is not None:
            raise ApiError(409, "Este identificador já é de outro treino.", "d_tag_already_used")
        workout.d_tag = payload.d_tag
    elif workout.d_tag != payload.d_tag:
        raise ApiError(
            422,
            "Republicar um treino exige o mesmo identificador `d` do evento anterior.",
            "d_tag_mismatch",
        )

    workout.visibility = "published"
    workout.publish_status = "published"
    db.add(SharedEvent(workout_id=workout.id, event_id=payload.event_id, kind=KIND_WORKOUT_RECORD))
    try:
        db.commit()
    except IntegrityError as exc:  # corrida: o mesmo aviso (ou o mesmo d) chegou em paralelo
        db.rollback()
        winner = _find_shared_event(db, payload.event_id)
        if winner is not None and winner.workout_id == workout_id:
            return get_workout(db, user, workout_id)
        raise ApiError(
            409, "Conflito ao registrar a publicação. Tente novamente.", "publication_conflict"
        ) from exc
    db.refresh(workout)
    return workout


def report_publication_failure(
    db: Session, user: User, workout_id: int, payload: PublicationFailureIn
) -> Workout:
    """Marca o treino como `failed` (RF-25) depois de uma tentativa sem relay.

    Idempotente: repetir o aviso mantém `failed`. Um `event_id` que já foi
    registrado como publicado não pode ser dado como falho (409). O treino segue
    com `visibility` e `d_tag` como estavam: o app pode tentar de novo.
    """
    workout = get_workout(db, user, workout_id)
    _ensure_caller_pubkey(db, user, payload.pubkey)

    if _find_shared_event(db, payload.event_id) is not None:
        raise ApiError(
            409, "Este evento já foi registrado como publicado.", "event_already_published"
        )

    if workout.publish_status != "failed":
        workout.publish_status = "failed"
        db.commit()
        db.refresh(workout)
    return workout


# ---------------------------------------------------------------------------
# Séries
# ---------------------------------------------------------------------------


def _get_set(workout: Workout, set_id: int) -> WorkoutSet:
    for workout_set in workout.sets:
        if workout_set.id == set_id:
            return workout_set
    raise _set_not_found()


def add_set(db: Session, user: User, workout_id: int, payload: SetIn) -> WorkoutSet:
    workout = get_workout(db, user, workout_id)
    if len(workout.sets) >= MAX_SETS_PER_WORKOUT:
        raise ApiError(
            422, f"Limite de {MAX_SETS_PER_WORKOUT} séries por treino atingido.", "too_many_sets"
        )
    _ensure_exercises_exist(db, [payload.exercise_id])
    workout_set = _new_set(payload)
    workout.sets.append(workout_set)
    db.commit()
    db.refresh(workout_set)
    return workout_set


def update_set(
    db: Session, user: User, workout_id: int, set_id: int, payload: SetUpdate
) -> WorkoutSet:
    workout = get_workout(db, user, workout_id)
    workout_set = _get_set(workout, set_id)
    changes = payload.model_dump(exclude_unset=True)

    for field in ("exercise_id", "reps", "weight_kg", "set_type"):
        if field in changes and changes[field] is None:
            raise ApiError(422, f"O campo '{field}' não pode ser nulo.", "validation_error")
    if "exercise_id" in changes:
        _ensure_exercises_exist(db, [changes["exercise_id"]])

    for field, value in changes.items():
        setattr(workout_set, field, value)
    db.commit()
    db.refresh(workout_set)
    return workout_set


def delete_set(db: Session, user: User, workout_id: int, set_id: int) -> None:
    workout = get_workout(db, user, workout_id)
    workout_set = _get_set(workout, set_id)
    _ensure_publishable(workout.visibility, len(workout.sets) - 1)
    workout.sets.remove(workout_set)
    db.commit()
