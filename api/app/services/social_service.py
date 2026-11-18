"""Regras das métricas sociais servidas pela API (BE-10).

As contagens vêm do cache `likes`, que o worker (BE-09) projeta a partir de
eventos `kind 7` assinados (ADR-0004). Esta camada só lê.
"""

from collections.abc import Sequence

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.domain.models.like import Like
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.user import User
from app.domain.schemas.social import LikeCountOut


def like_counts(db: Session, user: User, event_ids: Sequence[str]) -> list[LikeCountOut]:
    """Uma entrada por `event_id` pedido, na ordem pedida (sem repetidos);
    evento sem like vem com `count` 0."""
    ids = list(dict.fromkeys(event_ids))
    if not ids:
        return []
    counts: dict[str, int] = {
        event_id: count
        for event_id, count in db.execute(
            select(Like.event_id, func.count())
            .where(Like.event_id.in_(ids))
            .group_by(Like.event_id)
        ).tuples()
    }
    my_pubkey = db.scalar(select(NostrIdentity.pubkey_hex).where(NostrIdentity.user_id == user.id))
    mine: set[str] = set()
    if my_pubkey:
        mine = set(
            db.scalars(
                select(Like.event_id).where(Like.event_id.in_(ids), Like.liker_pubkey == my_pubkey)
            )
        )
    return [
        LikeCountOut(event_id=event_id, count=counts.get(event_id, 0), liked_by_me=event_id in mine)
        for event_id in ids
    ]
