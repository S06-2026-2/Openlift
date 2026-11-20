"""Regras de negócio do dashboard: volume semanal, volume e frequência por
grupo muscular e a matriz do heatmap (RF-41, RF-42, RF-54).

Consulta direta ao Postgres, sem cache (ADR-0011). Volume = Σ carga ×
repetições, sem séries de aquecimento (RN-03). Tudo filtra pelo usuário
logado: estatística é dado privado (ADR-0004).

O agrupamento por semana é feito em Python, não em SQL: as funções de data
diferem entre Postgres e o SQLite dos testes, e o volume de um usuário cabe
folgado em memória.
"""

from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import ApiError
from app.domain.models.exercise import Exercise
from app.domain.models.muscle_group import MuscleGroup
from app.domain.models.set import WorkoutSet
from app.domain.models.user import User
from app.domain.models.workout import Workout
from app.domain.schemas.stats import (
    HeatmapCellOut,
    HeatmapOut,
    MuscleGroupRef,
    MuscleGroupStatsOut,
    VolumeStatsOut,
    WeekVolumeOut,
)

MAX_RANGE_DAYS = 366


@dataclass(frozen=True)
class _DailyGroup:
    day: date
    group_id: int
    group_name: str
    volume: Decimal
    sets: int


def week_start(day: date) -> date:
    """Segunda-feira da semana ISO de `day`."""
    return day - timedelta(days=day.weekday())


def check_range(date_from: date, date_to: date) -> None:
    if date_from > date_to:
        raise ApiError(422, "A data inicial precisa ser antes da final.", "invalid_date_range")
    if (date_to - date_from).days + 1 > MAX_RANGE_DAYS:
        raise ApiError(
            422,
            f"O período pode ter no máximo {MAX_RANGE_DAYS} dias.",
            "date_range_too_long",
        )


def _daily_groups(db: Session, user: User, date_from: date, date_to: date) -> list[_DailyGroup]:
    volume = func.sum(WorkoutSet.weight_kg * WorkoutSet.reps)
    rows = db.execute(
        select(
            Workout.date,
            MuscleGroup.id,
            MuscleGroup.name,
            volume,
            func.count(WorkoutSet.id),
        )
        .join(WorkoutSet, WorkoutSet.workout_id == Workout.id)
        .join(Exercise, Exercise.id == WorkoutSet.exercise_id)
        .join(MuscleGroup, MuscleGroup.id == Exercise.muscle_group_id)
        .where(
            Workout.user_id == user.id,
            Workout.date >= date_from,
            Workout.date <= date_to,
            WorkoutSet.set_type != "warmup",
        )
        .group_by(Workout.date, MuscleGroup.id, MuscleGroup.name)
    ).all()
    return [
        _DailyGroup(day, group_id, name, Decimal(total or 0), count)
        for day, group_id, name, total, count in rows
    ]


def _as_float(value: Decimal) -> float:
    return float(round(value, 2))


def volume_by_week(db: Session, user: User, weeks: int, date_to: date) -> VolumeStatsOut:
    first_week = week_start(date_to) - timedelta(weeks=weeks - 1)

    volume: dict[date, Decimal] = defaultdict(Decimal)
    for row in _daily_groups(db, user, first_week, date_to):
        volume[week_start(row.day)] += row.volume

    workouts: dict[date, int] = defaultdict(int)
    for day, count in db.execute(
        select(Workout.date, func.count(Workout.id))
        .where(Workout.user_id == user.id, Workout.date >= first_week, Workout.date <= date_to)
        .group_by(Workout.date)
    ).all():
        workouts[week_start(day)] += count

    items = [
        WeekVolumeOut(
            week_start=start,
            volume=_as_float(volume[start]),
            workouts=workouts[start],
        )
        for start in (first_week + timedelta(weeks=i) for i in range(weeks))
    ]
    return VolumeStatsOut(
        weeks=items,
        total_volume=_as_float(sum(volume.values(), Decimal(0))),
        total_workouts=sum(workouts.values()),
    )


def _all_groups(db: Session) -> list[MuscleGroup]:
    return list(db.scalars(select(MuscleGroup).order_by(MuscleGroup.name)))


def muscle_groups(
    db: Session, user: User, date_from: date, date_to: date
) -> list[MuscleGroupStatsOut]:
    check_range(date_from, date_to)
    volume: dict[int, Decimal] = defaultdict(Decimal)
    sets: dict[int, int] = defaultdict(int)
    days: dict[int, set[date]] = defaultdict(set)
    for row in _daily_groups(db, user, date_from, date_to):
        volume[row.group_id] += row.volume
        sets[row.group_id] += row.sets
        days[row.group_id].add(row.day)

    items = [
        MuscleGroupStatsOut(
            muscle_group_id=group.id,
            muscle_group=group.name,
            volume=_as_float(volume[group.id]),
            sets=sets[group.id],
            sessions=len(days[group.id]),
        )
        for group in _all_groups(db)
    ]
    # Mais treinado primeiro; empate (inclusive os zerados) em ordem alfabética.
    return sorted(items, key=lambda item: -item.volume)


def heatmap(db: Session, user: User, date_from: date, date_to: date) -> HeatmapOut:
    check_range(date_from, date_to)
    cells = [
        HeatmapCellOut(
            date=row.day,
            muscle_group_id=row.group_id,
            muscle_group=row.group_name,
            volume=_as_float(row.volume),
        )
        for row in _daily_groups(db, user, date_from, date_to)
        if row.volume > 0
    ]
    cells.sort(key=lambda cell: (cell.date, cell.muscle_group))
    return HeatmapOut(
        date_from=date_from,
        date_to=date_to,
        muscle_groups=[MuscleGroupRef(id=g.id, name=g.name) for g in _all_groups(db)],
        cells=cells,
    )
