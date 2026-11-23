"""Heartbeat do worker e o status que o `/health` mostra (OPS-08).

- O worker chama `record_heartbeat` ao fim de cada ciclo, com sucesso ou não.
- A API chama `worker_status` no `/health`:
  - `ok`: último ciclo bem-sucedido há no máximo 3 intervalos;
  - `stale`: o worker rodou alguma vez, mas não tem sucesso recente (parou,
    ou todos os ciclos recentes falharam);
  - `unknown`: nunca houve heartbeat (worker não está rodando neste ambiente).

O status do worker não derruba o `/health`: a API continua servindo sem ele.
"""

from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from app.domain.models.worker_heartbeat import WorkerHeartbeat

SYNC_WORKER = "nostr-sync"
STALE_AFTER_INTERVALS = 3


def _aware(value: datetime | None) -> datetime | None:
    # SQLite devolve datetime sem fuso; o Postgres, com fuso. Tudo em UTC.
    if value is None or value.tzinfo is not None:
        return value
    return value.replace(tzinfo=UTC)


def record_heartbeat(
    db: Session, *, name: str = SYNC_WORKER, error: str | None = None, now: datetime | None = None
) -> None:
    now = now or datetime.now(UTC)
    beat = db.get(WorkerHeartbeat, name)
    if beat is None:
        beat = WorkerHeartbeat(name=name, last_run_at=now)
        db.add(beat)
    beat.last_run_at = now
    beat.last_error = error
    if error is None:
        beat.last_success_at = now
    db.commit()


def worker_status(
    db: Session, interval_seconds: int, *, name: str = SYNC_WORKER, now: datetime | None = None
) -> dict:
    now = now or datetime.now(UTC)
    beat = db.get(WorkerHeartbeat, name)
    if beat is None:
        return {"status": "unknown", "last_run_at": None, "last_success_at": None}
    last_success = _aware(beat.last_success_at)
    limit = timedelta(seconds=interval_seconds * STALE_AFTER_INTERVALS)
    healthy = last_success is not None and now - last_success <= limit
    return {
        "status": "ok" if healthy else "stale",
        "last_run_at": _aware(beat.last_run_at),
        "last_success_at": last_success,
        "last_error": beat.last_error,
    }
