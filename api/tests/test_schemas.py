"""Testes dos schemas Pydantic v2 de validação e serialização (Sprint 1).

Cobre as regras de negócio e validações declaradas nos contratos de dados:
- Auth: formato de e-mail (EmailStr), tamanho mínimo de senha, tokens e npub
- Workout: limites numéricos de repetições (gt=0), carga (ge=0) e RPE (0 a 10)
- User: projeção pública de usuário (UserOut)
"""

from datetime import date, datetime, timezone
from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.domain.schemas.auth import LoginRequest, NostrIdentityIn, RegisterRequest, TokenPair
from app.domain.schemas.user import UserOut
from app.domain.schemas.workout import SetIn, SetOut, WorkoutIn, WorkoutOut


# ---------------------------------------------------------------------------
# Schemas: Auth
# ---------------------------------------------------------------------------


def test_register_request_valid() -> None:
    """RegisterRequest com e-mail válido e senha de pelo menos 8 caracteres deve passar."""
    # Act
    req = RegisterRequest(email="valid@openlift.dev", password="password123")

    # Assert
    assert req.email == "valid@openlift.dev"
    assert req.password == "password123"


def test_register_request_invalid_email_raises_validation_error() -> None:
    """RegisterRequest com formato de e-mail inválido deve disparar ValidationError."""
    with pytest.raises(ValidationError):
        RegisterRequest.model_validate({"email": "not-an-email", "password": "validpassword123"})


def test_register_request_short_password_raises_validation_error() -> None:
    """RegisterRequest com senha menor que 8 caracteres deve disparar ValidationError."""
    with pytest.raises(ValidationError):
        RegisterRequest.model_validate({"email": "valid@openlift.dev", "password": "short"})


def test_login_request_valid() -> None:
    """LoginRequest com e-mail e senha preenchidos deve validar corretamente."""
    # Act
    req = LoginRequest(email="atleta@openlift.dev", password="qualquer_senha")

    # Assert
    assert req.email == "atleta@openlift.dev"
    assert req.password == "qualquer_senha"


def test_login_request_invalid_email_raises_validation_error() -> None:
    """LoginRequest com e-mail mal formatado deve disparar ValidationError."""
    with pytest.raises(ValidationError):
        LoginRequest.model_validate({"email": "invalid-format", "password": "qualquer_senha"})


def test_token_pair_default_token_type() -> None:
    """TokenPair deve ter o valor padrão 'bearer' para token_type."""
    # Act
    tokens = TokenPair(access_token="acc123", refresh_token="ref456")

    # Assert
    assert tokens.access_token == "acc123"
    assert tokens.refresh_token == "ref456"
    assert tokens.token_type == "bearer"


def test_nostr_identity_in_valid() -> None:
    """NostrIdentityIn com npub não-vazio deve validar com sucesso."""
    # Act
    payload = NostrIdentityIn(npub="npub1abc123xyz")

    # Assert
    assert payload.npub == "npub1abc123xyz"


def test_nostr_identity_in_empty_npub_raises_validation_error() -> None:
    """NostrIdentityIn com string vazia deve falhar por violar min_length=1."""
    with pytest.raises(ValidationError):
        NostrIdentityIn.model_validate({"npub": ""})


# ---------------------------------------------------------------------------
# Schemas: Workout & Sets
# ---------------------------------------------------------------------------


def test_set_in_valid() -> None:
    """SetIn com valores positivos e RPE válido deve passar."""
    # Act
    set_data = SetIn(
        exercise_id=1,
        reps=8,
        weight_kg=Decimal("80.0"),
        rpe=Decimal("7.5"),
    )

    # Assert
    assert set_data.exercise_id == 1
    assert set_data.reps == 8
    assert set_data.weight_kg == Decimal("80.0")
    assert set_data.rpe == Decimal("7.5")


def test_set_in_reps_zero_or_negative_raises_validation_error() -> None:
    """SetIn com reps <= 0 deve disparar ValidationError (Field gt=0)."""
    with pytest.raises(ValidationError):
        SetIn.model_validate({"exercise_id": 1, "reps": 0, "weight_kg": Decimal("50.0")})

    with pytest.raises(ValidationError):
        SetIn.model_validate({"exercise_id": 1, "reps": -5, "weight_kg": Decimal("50.0")})


def test_set_in_negative_weight_raises_validation_error() -> None:
    """SetIn com peso negativo deve disparar ValidationError (Field ge=0)."""
    with pytest.raises(ValidationError):
        SetIn.model_validate({"exercise_id": 1, "reps": 10, "weight_kg": Decimal("-1.0")})


def test_set_in_rpe_out_of_bounds_raises_validation_error() -> None:
    """SetIn com RPE fora do intervalo [0, 10] deve disparar ValidationError."""
    with pytest.raises(ValidationError):
        SetIn.model_validate(
            {"exercise_id": 1, "reps": 10, "weight_kg": Decimal("50.0"), "rpe": Decimal("10.5")}
        )

    with pytest.raises(ValidationError):
        SetIn.model_validate(
            {"exercise_id": 1, "reps": 10, "weight_kg": Decimal("50.0"), "rpe": Decimal("-0.5")}
        )


def test_workout_in_with_nested_sets() -> None:
    """WorkoutIn deve conter data e lista aninhada opcional de séries."""
    # Act
    workout = WorkoutIn(
        date=date(2026, 9, 17),
        sets=[
            SetIn(exercise_id=1, reps=10, weight_kg=Decimal("60.0")),
            SetIn(exercise_id=2, reps=12, weight_kg=Decimal("20.0")),
        ],
    )

    # Assert
    assert workout.date == date(2026, 9, 17)
    assert len(workout.sets) == 2
    assert workout.sets[0].exercise_id == 1
    assert workout.sets[1].exercise_id == 2


def test_workout_out_serialization() -> None:
    """WorkoutOut deve serializar corretamente os atributos de resposta."""
    now = datetime.now(timezone.utc)
    workout_out = WorkoutOut(
        id=1,
        date=date(2026, 9, 17),
        created_at=now,
        sets=[
            SetOut(id=10, exercise_id=1, reps=10, weight_kg=Decimal("70.0"), rpe=Decimal("8.0"))
        ],
        shared_event_id=None,
    )

    assert workout_out.id == 1
    assert len(workout_out.sets) == 1
    assert workout_out.sets[0].id == 10
    assert workout_out.shared_event_id is None


# ---------------------------------------------------------------------------
# Schemas: User
# ---------------------------------------------------------------------------


def test_user_out_serialization() -> None:
    """UserOut deve expor id, email, created_at e npub sem expor senha."""
    now = datetime.now(timezone.utc)
    user_out = UserOut(
        id=42,
        email="public_user@openlift.dev",
        npub="npub1test",
        created_at=now,
    )

    data = user_out.model_dump()
    assert data["id"] == 42
    assert data["email"] == "public_user@openlift.dev"
    assert data["npub"] == "npub1test"
    assert "password" not in data
    assert "hashed_password" not in data
