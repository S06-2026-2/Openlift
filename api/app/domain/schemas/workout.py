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


_HEX64 = r"^[0-9a-f]{64}$"
_UUID_V4 = r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
_EVENT_ID_EXAMPLE = "b" * 64
_PUBKEY_EXAMPLE = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"


class PublicationIn(BaseModel):
    """Aviso de que o app publicou o treino (kind 1301) em ao menos um relay.

    O app monta, assina e publica o evento; o backend só registra o resultado.
    O corpo é fechado (`extra="forbid"`): nada além destes campos é aceito, em
    especial nenhum material de chave privada (RNF-01, ADR-0006).
    """

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "event_id": _EVENT_ID_EXAMPLE,
                    "pubkey": _PUBKEY_EXAMPLE,
                    "d_tag": "7c9e6679-7425-4f1b-9a2e-6a1f0c8d5b34",
                }
            ]
        },
    )

    event_id: str = Field(pattern=_HEX64, description="`id` do evento (NIP-01): 64 hex minúsculos")
    pubkey: str = Field(
        pattern=_HEX64,
        description="`pubkey` do evento (64 hex minúsculos); precisa ser a do `npub` do usuário",
    )
    d_tag: str = Field(
        pattern=_UUID_V4,
        description="Tag `d` do evento: UUID v4 minúsculo, o mesmo em toda "
        "republicação do treino (RN-08)",
    )


class PublicationFailureIn(BaseModel):
    """Aviso de que a tentativa de publicar o treino falhou em todos os relays."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [{"event_id": _EVENT_ID_EXAMPLE, "pubkey": _PUBKEY_EXAMPLE}]
        },
    )

    event_id: str = Field(
        pattern=_HEX64, description="`id` do evento que não chegou a nenhum relay"
    )
    pubkey: str = Field(
        pattern=_HEX64, description="`pubkey` do evento; precisa ser a do `npub` do usuário"
    )


class WorkoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date_
    created_at: datetime
    visibility: Visibility = "private"
    publish_status: PublishStatus = Field(
        default="local", description="local | published | failed (RF-25; definido pelo servidor)"
    )
    d_tag: str | None = Field(
        default=None,
        description="Tag `d` (UUID v4) do evento kind 1301; fixa por treino, reutilizada "
        "ao republicar após edição (RN-08). Nulo até a primeira publicação",
    )
    sets: list[SetOut] = Field(default_factory=list)


class WorkoutPage(BaseModel):
    """Página do histórico (mais novo primeiro)."""

    items: list[WorkoutOut]
    total: int = Field(description="Total de treinos que batem com o filtro")
    limit: int
    offset: int
