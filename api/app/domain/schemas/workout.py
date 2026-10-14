"""Schemas Pydantic v2 de treino e série (BE-04).

Regras (RN-07): carga 0–1000 kg, repetições 1–500, RPE opcional 1–10 e tipo
∈ {warmup, normal, failure}. Fora disso a API responde 422.
"""

from datetime import date as date_
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.config import JsonDict

SetType = Literal["warmup", "normal", "failure"]
Visibility = Literal["private", "published"]
PublishStatus = Literal["local", "published", "failed"]

MAX_REPS = 500
MAX_WEIGHT_KG = 1000
MAX_SETS_PER_WORKOUT = 200

_SET_EXAMPLE: JsonDict = {
    "exercise_id": 1,
    "reps": 8,
    "weight_kg": 80,
    "rpe": 8,
    "set_type": "normal",
}


class SetIn(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [_SET_EXAMPLE]})

    exercise_id: int = Field(ge=1, description="Exercício da biblioteca (GET /exercises)")
    reps: int = Field(gt=0, le=MAX_REPS, description="Repetições (1 a 500)")
    weight_kg: Decimal = Field(
        ge=0, le=MAX_WEIGHT_KG, max_digits=6, decimal_places=2, description="Carga em kg (0 a 1000)"
    )
    rpe: Decimal | None = Field(
        default=None, ge=1, le=10, max_digits=3, decimal_places=1, description="Esforço (1 a 10)"
    )
    set_type: SetType = Field(default="normal", description="warmup | normal | failure")


class SetUpdate(BaseModel):
    """PATCH de uma série: só os campos enviados mudam (`rpe: null` limpa o RPE)."""

    model_config = ConfigDict(json_schema_extra={"examples": [{"reps": 10, "weight_kg": 82.5}]})

    exercise_id: int | None = Field(default=None, ge=1)
    reps: int | None = Field(default=None, gt=0, le=MAX_REPS)
    weight_kg: Decimal | None = Field(
        default=None, ge=0, le=MAX_WEIGHT_KG, max_digits=6, decimal_places=2
    )
    rpe: Decimal | None = Field(default=None, ge=1, le=10, max_digits=3, decimal_places=1)
    set_type: SetType | None = None


class SetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    exercise_id: int
    reps: int
    weight_kg: Decimal
    rpe: Decimal | None = None
    set_type: SetType = "normal"


class WorkoutIn(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [{"date": "2026-10-14", "visibility": "private", "sets": [_SET_EXAMPLE]}]
        }
    )

    date: date_
    sets: list[SetIn] = Field(default_factory=list, max_length=MAX_SETS_PER_WORKOUT)
    visibility: Visibility = "private"


class WorkoutUpdate(BaseModel):
    """PATCH de um treino: só os campos enviados mudam.

    `sets`, se enviado, **substitui** todas as séries do treino (é o que o app
    faz ao salvar a tela de edição). Para mexer numa série só, use
    /workouts/{id}/sets/{set_id}.
    """

    model_config = ConfigDict(
        json_schema_extra={"examples": [{"date": "2026-10-15", "sets": [_SET_EXAMPLE]}]}
    )

    date: date_ | None = None
    visibility: Visibility | None = None
    sets: list[SetIn] | None = Field(default=None, max_length=MAX_SETS_PER_WORKOUT)


class WorkoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date_
    created_at: datetime
    visibility: Visibility = "private"
    publish_status: PublishStatus = Field(
        default="local", description="local | published | failed (RF-25; definido pelo servidor)"
    )
    shared_event_id: str | None = Field(
        default=None, description="Evento NOSTR publicado (kind 1301), quando compartilhado"
    )
    sets: list[SetOut] = Field(default_factory=list)


class WorkoutPage(BaseModel):
    """Página do histórico (mais novo primeiro)."""

    items: list[WorkoutOut]
    total: int = Field(description="Total de treinos que batem com o filtro")
    limit: int
    offset: int
