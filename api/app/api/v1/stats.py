"""Endpoints do dashboard (RF-41, RF-42, RF-54). Rotas finas: a regra fica em
app/services/stats_service.py. Todas exigem login e só agregam os treinos do
próprio usuário.

GET /stats/volume         — volume semanal ou mensal, treinos no mês e sequência
GET /stats/muscle-groups  — volume e frequência por grupo muscular
GET /stats/heatmap        — matriz data × grupo muscular × volume
"""

from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.domain.schemas.stats import GroupBy, HeatmapOut, MuscleGroupStatsOut, VolumeStatsOut
from app.services import stats_service

router = APIRouter()

_RANGE_ERRORS = {
    401: "Não autenticado",
    422: "Período inválido (`invalid_date_range`) ou maior que "
    f"{stats_service.MAX_RANGE_DAYS} dias (`date_range_too_long`)",
}

DateTo = Annotated[
    date | None,
    Query(description="Último dia (inclusivo). Padrão: hoje no servidor; o app manda a data local"),
]


@router.get(
    "/volume",
    response_model=VolumeStatsOut,
    summary="Volume semanal ou mensal",
    description="Volume (Σ carga × repetições, sem aquecimento — RN-03) e número de "
    "treinos de cada semana ISO (`group_by=week`) ou mês (`group_by=month`), do mais "
    "antigo para o mais novo. Períodos sem treino vêm zerados; o último é o que contém "
    "`date_to`. Também traz os treinos do mês de `date_to` e a sequência de dias seguidos "
    "com treino (streak), que continua valendo se ainda não houve treino em `date_to`.",
    responses=error_responses({401: "Não autenticado"}),
)
def get_volume(
    db: DbSession,
    user: CurrentUser,
    group_by: Annotated[GroupBy, Query(description="`week` (semana ISO) ou `month`")] = "week",
    periods: Annotated[int, Query(ge=1, le=52, description="Quantas semanas ou meses")] = 12,
    date_to: DateTo = None,
) -> VolumeStatsOut:
    return stats_service.volume_stats(db, user, group_by, periods, date_to or date.today())


@router.get(
    "/muscle-groups",
    response_model=list[MuscleGroupStatsOut],
    summary="Volume e frequência por grupo muscular",
    description="Para cada grupo muscular: volume, séries válidas e em quantos dias "
    "diferentes foi treinado no período. Todos os grupos aparecem (zerados quando não "
    "treinados), do mais treinado para o menos. Padrão: últimos 28 dias.",
    responses=error_responses(_RANGE_ERRORS),
)
def get_muscle_groups(
    db: DbSession,
    user: CurrentUser,
    date_from: Annotated[date | None, Query(description="Primeiro dia (inclusivo)")] = None,
    date_to: DateTo = None,
) -> list[MuscleGroupStatsOut]:
    end = date_to or date.today()
    start = date_from or end - timedelta(days=27)
    return stats_service.muscle_groups(db, user, start, end)


@router.get(
    "/heatmap",
    response_model=HeatmapOut,
    summary="Mapa de calor de volume",
    description="Volume de cada grupo muscular em cada dia do período (só dias com "
    "volume), mais a lista de todos os grupos para montar as linhas do mapa. "
    f"Período de até {stats_service.MAX_RANGE_DAYS} dias. Padrão: últimas 8 semanas.",
    responses=error_responses(_RANGE_ERRORS),
)
def get_heatmap(
    db: DbSession,
    user: CurrentUser,
    date_from: Annotated[date | None, Query(description="Primeiro dia (inclusivo)")] = None,
    date_to: DateTo = None,
) -> HeatmapOut:
    end = date_to or date.today()
    start = date_from or end - timedelta(days=55)
    return stats_service.heatmap(db, user, start, end)
