"""Replay das agregações sociais (BE-14, RF-53, RNF-06, ADR-0004).

Apaga o cache de curtidas (`likes`, e `rankings`, que também é derivado) e
reconstrói tudo a partir dos eventos `kind 7` assinados que estão nos
relays, com a **mesma** projeção do worker (`project_likes`). É a prova de
que nada social vive só no Postgres.

Segurança:
- os relays são lidos **antes** de apagar qualquer coisa;
- se nenhum relay respondeu até o fim, nada é apagado (`ReplayAborted`);
- apagar e reprojetar acontecem na mesma transação: ou fica o cache novo,
  ou fica o antigo.
"""

import logging
import time
from dataclasses import dataclass

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.domain.models.like import Like
from app.domain.models.ranking import RankingEntry
from app.infra.nostr.relay_client import RelayClient
from app.services.nostr_sync_worker import (
    project_likes,
    reaction_filters,
    shared_workout_event_ids,
)

logger = logging.getLogger("openlift.replay")


class ReplayAborted(Exception):
    """Nenhum relay respondeu: o replay não apagou nada."""


@dataclass(frozen=True)
class ReplayResult:
    shared_events: int
    reactions: int
    likes_before: int
    likes_after: int
    relays_ok: int
    relays_total: int
    seconds: float


def _count_likes(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(Like)) or 0


async def replay_likes(db: Session, client: RelayClient, *, dry_run: bool = False) -> ReplayResult:
    started = time.perf_counter()
    event_ids = shared_workout_event_ids(db)
    likes_before = _count_likes(db)

    if event_ids:
        report = await client.fetch_report(reaction_filters(event_ids))
        if report.relays_ok == 0:
            raise ReplayAborted(
                f"Nenhum dos {report.relays_total} relay(s) respondeu; nada foi apagado."
            )
        reactions, relays_ok, relays_total = report.events, report.relays_ok, report.relays_total
    else:
        reactions, relays_ok, relays_total = [], 0, len(client.relay_urls)

    db.execute(delete(Like))
    db.execute(delete(RankingEntry))
    likes_after = project_likes(db, reactions, set(event_ids))
    if dry_run:
        db.rollback()
    else:
        db.commit()

    result = ReplayResult(
        shared_events=len(event_ids),
        reactions=len(reactions),
        likes_before=likes_before,
        likes_after=likes_after,
        relays_ok=relays_ok,
        relays_total=relays_total,
        seconds=time.perf_counter() - started,
    )
    logger.info(
        "Replay de likes%s: %d treinos, %d reações, likes %d → %d em %.1f s",
        " (simulação)" if dry_run else "",
        result.shared_events,
        result.reactions,
        result.likes_before,
        result.likes_after,
        result.seconds,
        extra={"likes_before": likes_before, "likes_after": likes_after},
    )
    return result
