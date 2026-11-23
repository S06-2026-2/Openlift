"""Schemas Pydantic v2 de estatísticas do dashboard (RF-41, RF-42, RF-54).

Volume segue a RN-03: Σ (carga × repetições), sem séries de aquecimento.
"""

from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

GroupBy = Literal["week", "month"]


class PeriodVolumeOut(BaseModel):
    """Volume de uma semana ISO (segunda a domingo) ou de um mês."""

    period_start: date = Field(description="Segunda-feira da semana ou dia 1 do mês")
    volume: float = Field(ge=0, description="Σ carga × repetições (kg), sem aquecimento")
    workouts: int = Field(ge=0, description="Treinos registrados no período")


class VolumeStatsOut(BaseModel):
    """Volume das últimas N semanas ou meses, do mais antigo para o mais novo.

    Períodos sem treino aparecem com zero, para o gráfico não pular nenhum.
    Os campos de resumo contam até `date_to`.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "group_by": "week",
                    "periods": [
                        {"period_start": "2026-11-09", "volume": 5400.0, "workouts": 3},
                        {"period_start": "2026-11-16", "volume": 2100.5, "workouts": 1},
                    ],
                    "total_volume": 7500.5,
                    "total_workouts": 4,
                    "workouts_this_month": 6,
                    "streak_days": 2,
                }
            ]
        }
    )

    group_by: GroupBy
    periods: list[PeriodVolumeOut]
    total_volume: float = Field(ge=0)
    total_workouts: int = Field(ge=0)
    workouts_this_month: int = Field(ge=0, description="Treinos do mês de `date_to`, até ele")
    streak_days: int = Field(
        ge=0,
        description="Dias seguidos com treino terminando em `date_to` (ou na véspera, se ainda "
        "não treinou hoje)",
    )


class MuscleGroupStatsOut(BaseModel):
    """Volume e frequência de um grupo muscular no período."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "muscle_group_id": 1,
                    "muscle_group": "Peito",
                    "volume": 3200.0,
                    "sets": 12,
                    "sessions": 3,
                }
            ]
        }
    )

    muscle_group_id: int
    muscle_group: str
    volume: float = Field(ge=0, description="Σ carga × repetições (kg), sem aquecimento")
    sets: int = Field(ge=0, description="Séries válidas (sem aquecimento)")
    sessions: int = Field(ge=0, description="Dias diferentes em que o grupo foi treinado")


class MuscleGroupRef(BaseModel):
    id: int
    name: str


class HeatmapCellOut(BaseModel):
    """Volume de um grupo muscular em um dia. Só dias com volume aparecem."""

    date: date
    muscle_group_id: int
    muscle_group: str
    volume: float = Field(gt=0)


class HeatmapOut(BaseModel):
    """Matriz data × grupo muscular × volume do período pedido."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "date_from": "2026-10-26",
                    "date_to": "2026-11-19",
                    "muscle_groups": [{"id": 1, "name": "Peito"}],
                    "cells": [
                        {
                            "date": "2026-11-17",
                            "muscle_group_id": 1,
                            "muscle_group": "Peito",
                            "volume": 1800.0,
                        }
                    ],
                }
            ]
        }
    )

    date_from: date
    date_to: date
    muscle_groups: list[MuscleGroupRef] = Field(
        description="Todos os grupos musculares, em ordem alfabética (linhas do mapa)"
    )
    cells: list[HeatmapCellOut]
