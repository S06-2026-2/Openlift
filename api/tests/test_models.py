"""Testes de persistência e integridade relacional dos models de domínio (Sprint 1).

Cobre os models declarativos do SQLAlchemy 2.0:
- User (users): campos obrigatórios, chave primária e unicidade de email
- Workout (workouts): persistência, data e constraint de Foreign Key para users.id
- WorkoutSet (sets): persistência, reps, cargas decimais, RPE e FK para workouts.id
- NostrIdentity (nostr_identities): unicidade de npub, unicidade de user_id (1:1) e FK para users.id
"""

from datetime import date
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.set import WorkoutSet
from app.domain.models.user import User
from app.domain.models.workout import Workout

# ---------------------------------------------------------------------------
# Model: User
# ---------------------------------------------------------------------------


def test_create_user_success(db_session: Session) -> None:
    """Criação de usuário com e-mail e hash persiste corretamente e gera id e timestamp."""
    # Arrange
    user = User(
        email="atleta@openlift.dev",
        hashed_password="argon2id$fakehashedpassword",
    )

    # Act
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    # Assert
    assert user.id is not None
    assert user.id > 0
    assert user.email == "atleta@openlift.dev"
    assert user.hashed_password == "argon2id$fakehashedpassword"
    assert user.created_at is not None


def test_user_duplicate_email_raises_integrity_error(db_session: Session) -> None:
    """Inserção de dois usuários com o mesmo e-mail deve falhar com IntegrityError."""
    # Arrange
    user1 = User(email="duplicado@openlift.dev", hashed_password="hash1")
    user2 = User(email="duplicado@openlift.dev", hashed_password="hash2")

    # Act & Assert
    db_session.add(user1)
    db_session.commit()

    db_session.add(user2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


# ---------------------------------------------------------------------------
# Model: Workout
# ---------------------------------------------------------------------------


def test_create_workout_success(db_session: Session) -> None:
    """Criação de treino associado a um usuário válido deve persistir com sucesso."""
    # Arrange
    user = User(email="treinador@openlift.dev", hashed_password="hash")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    workout = Workout(
        user_id=user.id,
        date=date(2026, 9, 17),
        shared_event_id=None,
    )

    # Act
    db_session.add(workout)
    db_session.commit()
    db_session.refresh(workout)

    # Assert
    assert workout.id is not None
    assert workout.user_id == user.id
    assert workout.date == date(2026, 9, 17)
    assert workout.created_at is not None
    assert workout.shared_event_id is None


def test_workout_foreign_key_violation_raises_integrity_error(db_session: Session) -> None:
    """Criação de treino com user_id inexistente deve violar FK e disparar IntegrityError."""
    # Arrange
    non_existent_user_id = 99999
    workout = Workout(user_id=non_existent_user_id, date=date.today())

    # Act & Assert
    db_session.add(workout)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


# ---------------------------------------------------------------------------
# Model: WorkoutSet
# ---------------------------------------------------------------------------


def test_create_workout_set_success(db_session: Session) -> None:
    """Criação de série em um treino existente deve persistir cargas e RPE com precisão."""
    # Arrange
    user = User(email="powerlifter@openlift.dev", hashed_password="hash")
    db_session.add(user)
    db_session.commit()

    workout = Workout(user_id=user.id, date=date.today())
    db_session.add(workout)
    db_session.commit()

    workout_set = WorkoutSet(
        workout_id=workout.id,
        exercise_id=1,  # Supino reto
        reps=5,
        weight_kg=Decimal("102.50"),
        rpe=Decimal("8.5"),
    )

    # Act
    db_session.add(workout_set)
    db_session.commit()
    db_session.refresh(workout_set)

    # Assert
    assert workout_set.id is not None
    assert workout_set.workout_id == workout.id
    assert workout_set.exercise_id == 1
    assert workout_set.reps == 5
    assert workout_set.weight_kg == Decimal("102.50")
    assert workout_set.rpe == Decimal("8.5")


def test_workout_set_foreign_key_violation_raises_integrity_error(db_session: Session) -> None:
    """Criação de série com workout_id inexistente deve violar FK e disparar IntegrityError."""
    # Arrange
    non_existent_workout_id = 88888
    workout_set = WorkoutSet(
        workout_id=non_existent_workout_id,
        exercise_id=1,
        reps=10,
        weight_kg=Decimal("50.00"),
    )

    # Act & Assert
    db_session.add(workout_set)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


# ---------------------------------------------------------------------------
# Model: NostrIdentity
# ---------------------------------------------------------------------------


def test_create_nostr_identity_success(db_session: Session) -> None:
    """Associação de chave pública NOSTR (npub) a um usuário deve persistir com sucesso."""
    # Arrange
    user = User(email="nostr_user@openlift.dev", hashed_password="hash")
    db_session.add(user)
    db_session.commit()

    npub = "npub1testuser000000000000000000000000000000000000000000000000000"
    identity = NostrIdentity(user_id=user.id, npub=npub)

    # Act
    db_session.add(identity)
    db_session.commit()
    db_session.refresh(identity)

    # Assert
    assert identity.id is not None
    assert identity.user_id == user.id
    assert identity.npub == npub
    assert identity.created_at is not None


def test_nostr_identity_duplicate_npub_raises_integrity_error(db_session: Session) -> None:
    """Tentativa de registrar o mesmo npub para dois usuários distintos deve falhar."""
    # Arrange
    user1 = User(email="u1@openlift.dev", hashed_password="hash")
    user2 = User(email="u2@openlift.dev", hashed_password="hash")
    db_session.add_all([user1, user2])
    db_session.commit()

    shared_npub = "npub1shared000000000000000000000000000000000000000000000000000"
    id1 = NostrIdentity(user_id=user1.id, npub=shared_npub)
    id2 = NostrIdentity(user_id=user2.id, npub=shared_npub)

    # Act & Assert
    db_session.add(id1)
    db_session.commit()

    db_session.add(id2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_nostr_identity_unique_user_id_raises_integrity_error(db_session: Session) -> None:
    """Tentativa de registrar mais de uma identidade NOSTR para o mesmo usuário falha (1:1)."""
    # Arrange
    user = User(email="single_identity@openlift.dev", hashed_password="hash")
    db_session.add(user)
    db_session.commit()

    npub1 = "npub1first000000000000000000000000000000000000000000000000000"
    npub2 = "npub1second00000000000000000000000000000000000000000000000000"
    id1 = NostrIdentity(user_id=user.id, npub=npub1)
    id2 = NostrIdentity(user_id=user.id, npub=npub2)

    # Act & Assert
    db_session.add(id1)
    db_session.commit()

    db_session.add(id2)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()
