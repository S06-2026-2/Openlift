"""BE-03 — Biblioteca de exercícios: seed idempotente, constraints das tabelas
novas (exercises, muscle_groups, shared_events, likes, rankings) e o endpoint
GET /api/v1/exercises."""

from datetime import date
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.domain.models.exercise import EQUIPMENT_VALUES, Exercise
from app.domain.models.like import Like
from app.domain.models.muscle_group import MuscleGroup
from app.domain.models.ranking import RankingEntry
from app.domain.models.set import WorkoutSet
from app.domain.models.shared_event import SharedEvent
from app.domain.models.user import User
from app.domain.models.workout import Workout
from app.infra.db.seed import EQUIPMENT, LIBRARY, seed_exercises

EXERCISES = "/api/v1/exercises"
EVENT_ID = "a" * 64
PUBKEY = "b" * 64


def _count(db: Session, model: type) -> int:
    return db.scalar(select(func.count()).select_from(model)) or 0


# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------


def test_seed_creates_the_ten_groups_and_forty_exercises(db_session: Session) -> None:
    result = seed_exercises(db_session)

    assert result.groups_created == 10
    assert result.exercises_created == 40
    assert _count(db_session, MuscleGroup) == 10
    assert _count(db_session, Exercise) == 40


def test_seed_covers_the_groups_listed_in_the_issue() -> None:
    assert set(LIBRARY) == {
        "Peito",
        "Costas",
        "Ombros",
        "Bíceps",
        "Tríceps",
        "Quadríceps",
        "Posterior",
        "Glúteos",
        "Panturrilha",
        "Abdômen",
    }


def test_seed_is_idempotent(db_session: Session) -> None:
    seed_exercises(db_session)

    second = seed_exercises(db_session)

    assert (second.groups_created, second.exercises_created, second.exercises_updated) == (0, 0, 0)
    assert _count(db_session, MuscleGroup) == 10
    assert _count(db_session, Exercise) == 40


def test_seed_moves_an_exercise_back_to_its_group(db_session: Session) -> None:
    seed_exercises(db_session)
    bench = db_session.scalar(select(Exercise).where(Exercise.name == "Supino reto"))
    legs = db_session.scalar(select(MuscleGroup).where(MuscleGroup.name == "Quadríceps"))
    assert bench is not None and legs is not None
    bench.muscle_group_id = legs.id
    db_session.commit()

    result = seed_exercises(db_session)

    assert result.exercises_updated == 1
    db_session.refresh(bench)
    assert bench.muscle_group.name == "Peito"


def test_seed_gives_every_exercise_a_nip101e_equipment(db_session: Session) -> None:
    seed_exercises(db_session)

    equipment = {e.name: e.equipment for e in db_session.scalars(select(Exercise))}

    assert set(equipment) == set(EQUIPMENT)
    assert set(equipment.values()) <= set(EQUIPMENT_VALUES)
    assert equipment["Supino reto"] == "barbell"
    assert equipment["Rosca alternada"] == "dumbbell"
    assert equipment["Barra fixa"] == "bodyweight"
    # Polia/cabo entra como machine: o NIP-101e não tem valor próprio.
    assert equipment["Tríceps pulley"] == "machine"


def test_every_library_exercise_has_an_equipment() -> None:
    names = {name for group in LIBRARY.values() for name in group}
    assert names == set(EQUIPMENT)


def test_seed_fixes_a_wrong_equipment(db_session: Session) -> None:
    seed_exercises(db_session)
    bench = db_session.scalar(select(Exercise).where(Exercise.name == "Supino reto"))
    assert bench is not None
    bench.equipment = "machine"
    db_session.commit()

    result = seed_exercises(db_session)

    assert result.exercises_updated == 1
    db_session.refresh(bench)
    assert bench.equipment == "barbell"


def test_equipment_outside_the_vocabulary_violates_check(db_session: Session) -> None:
    group = MuscleGroup(name="Peito")
    db_session.add(group)
    db_session.flush()
    db_session.add(Exercise(name="Supino no cabo", muscle_group_id=group.id, equipment="cable"))

    with pytest.raises(IntegrityError):
        db_session.flush()


# ---------------------------------------------------------------------------
# Constraints das tabelas novas
# ---------------------------------------------------------------------------


def _workout(db: Session) -> Workout:
    user = User(email="lifter@openlift.dev", hashed_password="hash")
    db.add(user)
    db.flush()
    workout = Workout(user_id=user.id, date=date(2026, 10, 14))
    db.add(workout)
    db.commit()
    return workout


def test_set_with_unknown_exercise_violates_fk(db_session: Session) -> None:
    workout = _workout(db_session)
    db_session.add(
        WorkoutSet(workout_id=workout.id, exercise_id=999, reps=8, weight_kg=Decimal("80"))
    )

    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_exercise_name_is_unique(db_session: Session) -> None:
    group = MuscleGroup(name="Peito")
    db_session.add(group)
    db_session.flush()
    db_session.add_all(
        [
            Exercise(name="Supino reto", muscle_group_id=group.id, equipment="barbell"),
            Exercise(name="Supino reto", muscle_group_id=group.id, equipment="barbell"),
        ]
    )

    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_like_is_unique_per_event_and_liker(db_session: Session) -> None:
    """RN-06: o mesmo pubkey curtindo o mesmo evento conta uma vez só."""
    db_session.add(Like(event_id=EVENT_ID, liker_pubkey=PUBKEY))
    db_session.commit()
    db_session.add(Like(event_id=EVENT_ID, liker_pubkey=PUBKEY))

    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()

    db_session.add(Like(event_id=EVENT_ID, liker_pubkey="c" * 64))
    db_session.commit()
    assert _count(db_session, Like) == 2


def test_shared_event_id_is_unique(db_session: Session) -> None:
    db_session.add_all(
        [SharedEvent(event_id=EVENT_ID, kind=1301), SharedEvent(event_id=EVENT_ID, kind=1301)]
    )

    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_deleting_workout_keeps_the_shared_event(db_session: Session) -> None:
    workout = _workout(db_session)
    shared = SharedEvent(workout_id=workout.id, event_id=EVENT_ID, kind=1301)
    db_session.add(shared)
    db_session.commit()

    db_session.delete(workout)
    db_session.commit()
    db_session.expire_all()

    kept = db_session.scalar(select(SharedEvent).where(SharedEvent.event_id == EVENT_ID))
    assert kept is not None
    assert kept.workout_id is None


def test_ranking_is_removed_with_its_shared_event(db_session: Session) -> None:
    shared = SharedEvent(event_id=EVENT_ID, kind=1301)
    db_session.add(shared)
    db_session.flush()
    db_session.add(RankingEntry(shared_event_id=shared.id, score=3.5))
    db_session.commit()

    db_session.delete(shared)
    db_session.commit()

    assert _count(db_session, RankingEntry) == 0


# ---------------------------------------------------------------------------
# GET /api/v1/exercises
# ---------------------------------------------------------------------------


def test_exercises_require_authentication(client: TestClient) -> None:
    response = client.get(EXERCISES)

    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"


def test_exercises_list_with_muscle_group(
    client: TestClient, db_session: Session, auth_headers: dict[str, str]
) -> None:
    seed_exercises(db_session)

    response = client.get(EXERCISES, headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 40
    bench = next(e for e in body if e["name"] == "Supino reto")
    assert bench["muscle_group"]["name"] == "Peito"
    assert isinstance(bench["muscle_group"]["id"], int)
    assert bench["equipment"] == "barbell"
    assert {e["equipment"] for e in body} <= set(EQUIPMENT_VALUES)
    # Ordenado por grupo e depois por nome.
    keys = [(e["muscle_group"]["name"], e["name"]) for e in body]
    assert keys == sorted(keys)


def test_exercises_filter_by_muscle_group(
    client: TestClient, db_session: Session, auth_headers: dict[str, str]
) -> None:
    seed_exercises(db_session)
    chest = db_session.scalar(select(MuscleGroup).where(MuscleGroup.name == "Peito"))
    assert chest is not None

    response = client.get(EXERCISES, params={"muscle_group_id": chest.id}, headers=auth_headers)

    names = {e["name"] for e in response.json()}
    assert names == set(LIBRARY["Peito"])


def test_exercises_invalid_filter_returns_422(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.get(EXERCISES, params={"muscle_group_id": 0}, headers=auth_headers)

    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"
