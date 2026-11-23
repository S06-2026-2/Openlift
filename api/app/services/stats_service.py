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
    GroupBy,
    HeatmapCellOut,
    HeatmapOut,
    MuscleGroupRef,
    MuscleGroupStatsOut,
    PeriodVolumeOut,
    VolumeStatsOut,
)

MAX_RANGE_DAYS = 366
# Até onde a sequência (streak) olha para trás.
MAX_STREAK_DAYS = 366


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


def month_start(day: date) -> date:
    return day.replace(day=1)


def _shift_months(day: date, months: int) -> date:
    """Dia 1 do mês `months` meses antes (negativo) ou depois de `day`."""
    index = day.year * 12 + (day.month - 1) + months
    return date(index // 12, index % 12 + 1, 1)


def period_starts(group_by: GroupBy, periods: int, date_to: date) -> list[date]:
    """Início de cada período, do mais antigo ao que contém `date_to`."""
    if group_by == "month":
        last = month_start(date_to)
        return [_shift_months(last, i - periods + 1) for i in range(periods)]
    last = week_start(date_to)
    return [last - timedelta(weeks=periods - 1 - i) for i in range(periods)]


def _period_of(group_by: GroupBy, day: date) -> date:
    return month_start(day) if group_by == "month" else week_start(day)


def streak_days(days_with_workout: set[date], date_to: date) -> int:
    """Dias seguidos com treino até `date_to`. Se ainda não treinou em
    `date_to`, a sequência de ontem continua valendo (o dia não acabou)."""
    day = date_to if date_to in days_with_workout else date_to - timedelta(days=1)
    streak = 0
    while day in days_with_workout and streak < MAX_STREAK_DAYS:
        streak += 1
        day -= timedelta(days=1)
    return streak


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


def _workouts_per_day(db: Session, user: User, date_from: date, date_to: date) -> dict[date, int]:
    return {
        day: count
        for day, count in db.execute(
            select(Workout.date, func.count(Workout.id))
            .where(Workout.user_id == user.id, Workout.date >= date_from, Workout.date <= date_to)
            .group_by(Workout.date)
        ).all()
    }


def volume_stats(
    db: Session, user: User, group_by: GroupBy, periods: int, date_to: date
) -> VolumeStatsOut:
    starts = period_starts(group_by, periods, date_to)
    first = starts[0]

    volume: dict[date, Decimal] = defaultdict(Decimal)
    for row in _daily_groups(db, user, first, date_to):
        volume[_period_of(group_by, row.day)] += row.volume

    # Uma consulta cobre os períodos, o mês corrente e a janela da sequência.
    lookback = min(first, month_start(date_to), date_to - timedelta(days=MAX_STREAK_DAYS))
    per_day = _workouts_per_day(db, user, lookback, date_to)

    workouts: dict[date, int] = defaultdict(int)
    for day, count in per_day.items():
        if day >= first:
            workouts[_period_of(group_by, day)] += count

    return VolumeStatsOut(
        group_by=group_by,
        periods=[
            PeriodVolumeOut(
                period_start=start,
                volume=_as_float(volume[start]),
                workouts=workouts[start],
            )
            for start in starts
        ],
        total_volume=_as_float(sum(volume.values(), Decimal(0))),
        total_workouts=sum(workouts.values()),
        workouts_this_month=sum(
            count for day, count in per_day.items() if day >= month_start(date_to)
        ),
        streak_days=streak_days(set(per_day), date_to),
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
