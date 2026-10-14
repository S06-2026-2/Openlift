"""Schemas Pydantic v2 da biblioteca de exercícios (BE-03)."""

from pydantic import BaseModel, ConfigDict


class MuscleGroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str


class ExerciseOut(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {"id": 1, "name": "Supino reto", "muscle_group": {"id": 1, "name": "Peito"}}
            ]
        },
    )

    id: int
    name: str
    muscle_group: MuscleGroupOut
