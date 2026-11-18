"""Sincronização NOSTR → Postgres: projeta os likes (NIP-25, `kind 7`) sobre
os treinos publicados na tabela `likes` (BE-09, RF-52).

ADR-0004: `likes` é **cache**. A origem é sempre um evento assinado, lido e
verificado pelo `RelayClient` (RF-51). Apagar a tabela e rodar a
sincronização de novo reconstrói a mesma contagem; o comando de replay
(RF-53) é exatamente isso.

Regras:
- Só conta reação a evento que está em `shared_events` (treinos publicados
  pelo OpenLift). O alvo é a **última** tag `e`, como manda a NIP-25.
- **RN-06:** um like por (evento, pubkey). Vários `kind 7` da mesma pessoa no
  mesmo treino contam 1; vale o mais antigo.
- **RF-24:** o mesmo evento vindo de relays diferentes ou de ciclos
  diferentes não duplica linha (dedup por `id` no cliente e par único no banco).
- **`content` "-" é ignorado.** Na NIP-25 ele é um *dislike*, não um "descurtir";
  o OpenLift não tem dislike. Retirar o like de verdade é um pedido de
  exclusão (`kind 5`, NIP-09), que este worker ainda **não** processa: o like
  continua contado até o evento sumir dos relays e o replay rodar.

Cada ciclo é idempotente e não depende de estado guardado fora do Postgres
(ADR-0011). O agendamento fica em `app/worker.py`.
"""

import asyncio
import logging
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select, tuple_
from sqlalchemy.orm import Session

from app.core.nostr import KIND_REACTION, KIND_WORKOUT_RECORD
from app.domain.models.like import Like
from app.domain.models.shared_event import SharedEvent
from app.infra.nostr.relay_client import Event, Filter, RelayClient

logger = logging.getLogger("openlift.worker")

# Ids por filtro `#e`: relays costumam recusar filtros muito grandes.
FILTER_CHUNK = 100
DISLIKE = "-"


@dataclass(frozen=True)
class SyncResult:
    shared_events: int
    reactions: int
    new_likes: int


def target_event_id(reaction: Event) -> str | None:
    """Evento curtido: o valor da última tag `e` (NIP-25)."""
    e_tags = [tag for tag in reaction["tags"] if len(tag) >= 2 and tag[0] == "e"]
    return e_tags[-1][1] if e_tags else None


def reaction_filters(event_ids: Sequence[str]) -> list[Filter]:
    return [
        {"kinds": [KIND_REACTION], "#e": list(event_ids[i : i + FILTER_CHUNK])}
        for i in range(0, len(event_ids), FILTER_CHUNK)
    ]


def shared_workout_event_ids(db: Session) -> list[str]:
    return list(
        db.scalars(
            select(SharedEvent.event_id)
            .where(SharedEvent.kind == KIND_WORKOUT_RECORD)
            .order_by(SharedEvent.id)
        )
    )


def project_likes(db: Session, reactions: Iterable[Event], known_event_ids: set[str]) -> int:
    """Grava os likes novos e devolve quantos entraram. Não faz commit."""
    earliest: dict[tuple[str, str], int] = {}
    for reaction in reactions:
        if reaction.get("kind") != KIND_REACTION or reaction.get("content") == DISLIKE:
            continue
        target = target_event_id(reaction)
        if target not in known_event_ids:
            continue
        assert target is not None
        key = (target, reaction["pubkey"])
        created_at = reaction["created_at"]
        if key not in earliest or created_at < earliest[key]:
            earliest[key] = created_at
    if not earliest:
        return 0

    existing: set[tuple[Any, ...]] = set()
    pairs = list(earliest)
    for i in range(0, len(pairs), FILTER_CHUNK):
        chunk = pairs[i : i + FILTER_CHUNK]
        existing.update(
            tuple(row)
            for row in db.execute(
                select(Like.event_id, Like.liker_pubkey).where(
                    tuple_(Like.event_id, Like.liker_pubkey).in_(chunk)
                )
            )
        )
    new = [key for key in pairs if key not in existing]
    db.add_all(
        Like(
            event_id=event_id,
            liker_pubkey=pubkey,
            created_at=datetime.fromtimestamp(earliest[(event_id, pubkey)], tz=UTC),
        )
        for event_id, pubkey in new
    )
    return len(new)


async def sync_reactions(db: Session, client: RelayClient) -> SyncResult:
    """Um ciclo: lê do relay os `kind 7` sobre os treinos publicados e projeta."""
    event_ids = shared_workout_event_ids(db)
    if not event_ids:
        return SyncResult(shared_events=0, reactions=0, new_likes=0)
    reactions = await client.fetch(reaction_filters(event_ids))
    new_likes = project_likes(db, reactions, set(event_ids))
    db.commit()
    result = SyncResult(len(event_ids), len(reactions), new_likes)
    logger.info(
        "Sincronização de likes: %d treinos, %d reações verificadas, %d likes novos",
        result.shared_events,
        result.reactions,
        result.new_likes,
        extra={"shared_events": result.shared_events, "new_likes": result.new_likes},
    )
    return result


def run_sync_cycle() -> SyncResult | None:
    """Ponto de entrada do agendador: abre sessão própria e nunca propaga
    erro (um ciclo que falha não derruba o worker; o próximo tenta de novo)."""
    from app.infra.db.session import SessionLocal

    try:
        with SessionLocal() as db:
            return asyncio.run(sync_reactions(db, RelayClient.from_settings()))
    except Exception:
        logger.exception("Ciclo de sincronização falhou")
        return None
