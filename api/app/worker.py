"""Processo do worker de sincronização NOSTR (ADR-0011).

    python -m app.worker

Roda `run_sync_cycle` logo ao subir e depois a cada
`NOSTR_SYNC_INTERVAL_SECONDS`. Um ciclo por vez (`max_instances=1`); ciclos
atrasados se juntam num só (`coalesce`). Mesma imagem e mesmas variáveis da
API; no `docker compose` vira o serviço `worker` (OPS-07).
"""

import logging
from datetime import UTC, datetime

from apscheduler.schedulers.blocking import BlockingScheduler

from app.core.config import get_settings
from app.core.logging import configure_logging
from app.services.nostr_sync_worker import run_sync_cycle

JOB_ID = "nostr-sync"


def build_scheduler() -> BlockingScheduler:
    settings = get_settings()
    scheduler = BlockingScheduler(timezone=UTC)
    scheduler.add_job(
        run_sync_cycle,
        "interval",
        seconds=settings.nostr_sync_interval_seconds,
        id=JOB_ID,
        max_instances=1,
        coalesce=True,
        next_run_time=datetime.now(UTC),
    )
    return scheduler


def main() -> None:  # pragma: no cover — bloqueia até o processo ser encerrado
    settings = get_settings()
    configure_logging(settings.log_level)
    logging.getLogger("openlift.worker").info(
        "Worker NOSTR iniciado: %d relay(s), ciclo a cada %d s",
        len(settings.nostr_relay_urls),
        settings.nostr_sync_interval_seconds,
    )
    build_scheduler().start()


if __name__ == "__main__":  # pragma: no cover
    main()
