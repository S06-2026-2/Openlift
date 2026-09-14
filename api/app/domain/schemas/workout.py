"""Schemas Pydantic v2 de treino e série.

Rascunho do contrato (Sprint 1) — CRUD de verdade (persistência, regras de
dono do recurso) é implementado no Sprint 2, em app/services/workout_service.py
e app/api/v1/workouts.py.
"""

from datetime import date as date_
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class SetIn(BaseModel):
    # TODO(Sprint 3): validar exercise_id contra a tabela `exercises` quando ela existir.
    exercise_id: int
    reps: int = Field(gt=0)
    weight_kg: Decimal = Field(ge=0)
    rpe: Decimal | None = Field(
        default=None, ge=0, le=10, description="Percepção de esforço (0-10)"
    )


class SetOut(SetIn):
    model_config = ConfigDict(from_attributes=True)

    id: int


class WorkoutIn(BaseModel):
    date: date_
    sets: list[SetIn] = Field(default_factory=list)


class WorkoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date_
    created_at: datetime
    sets: list[SetOut] = Field(default_factory=list)
    shared_event_id: str | None = Field(
        default=None, description="Preenchido quando o treino é compartilhado no NOSTR (Sprint 4)"
    )


# TODO(Sprint 3): class WorkoutFilters — date_from, date_to, exercise_id, muscle_group_id
