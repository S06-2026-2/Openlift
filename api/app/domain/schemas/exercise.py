"""Schemas Pydantic v2 da biblioteca de exercícios (BE-03)."""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

# Vocabulário do NIP-101e para o modelo de exercício (kind 33401).
Equipment = Literal["barbell", "dumbbell", "bodyweight", "machine", "cardio"]


class MuscleGroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class ExerciseOut(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "id": 1,
                    "name": "Supino reto",
                    "muscle_group": {"id": 1, "name": "Peito"},
                    "equipment": "barbell",
                }
            ]
        },
    )

    id: int
    name: str
    muscle_group: MuscleGroupOut
    equipment: Equipment = Field(
        description="Equipamento no vocabulário do NIP-101e, usado no evento kind 33401 "
        "(polia/cabo = `machine`)"
    )
