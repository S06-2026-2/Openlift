"""BE-09 — integração do worker de likes com PostgreSQL real.

Roda só quando `TEST_POSTGRES_URL` existe (no CI, depois do
`alembic upgrade head`). Tudo acontece dentro de uma transação desfeita no
fim, como em tests/integration/test_postgres.py.

Fica fora de tests/integration/ para importar tests/nostr_helpers.py pelo
mesmo caminho dos demais testes.
"""

import asyncio
import os
from datetime import date
from uuid import uuid4

import pytest
from nostr_helpers import FakeRelay, make_event, make_reaction
from sqlalchemy import create_engine, delete, select, text
from sqlalchemy.orm import Session

from app.domain.models.like import Like
from app.domain.models.shared_event import SharedEvent
from app.domain.models.user import User
from app.domain.models.workout import Workout
from app.infra.nostr.relay_client import RelayClient
from app.services.nostr_sync_worker import sync_reactions


@pytest.fixture(scope="module")
def postgres_engine():
    url = os.environ.get("TEST_POSTGRES_URL")
    if not url:
        pytest.skip("PostgreSQL não configurado para os testes")
    engine = create_engine(url, pool_pre_ping=True)
    try:
        with engine.connect() as connection:
            table = connection.execute(text("SELECT to_regclass('public.likes')")).scalar_one()
            assert table == "likes", "Execute alembic upgrade head"
        yield engine
    finally:
        engine.dispose()


@pytest.fixture()
def pg(postgres_engine):
    with postgres_engine.connect() as connection:
        transaction = connection.begin()
        try:
            with Session(bind=connection, join_transaction_mode="create_savepoint") as session:
                yield session
        finally:
            transaction.rollback()


async def _no_sleep(_: float) -> None:
    return None


def _sync(db: Session, relay: FakeRelay):
    client = RelayClient(["wss://relay.teste"], connect=relay.connect, sleep=_no_sleep)
    return asyncio.run(sync_reactions(db, client))


def test_worker_projeta_likes_no_postgres_e_reconstroi(pg: Session) -> None:
    user = User(email=f"worker-{uuid4().hex}@openlift.test", hashed_password="hash")
    pg.add(user)
    pg.flush()
    tag = uuid4().hex
    workout_event = make_event(f"autor {tag}", kind=1301, tags=[["d", tag]])
    workout = Workout(user_id=user.id, date=date(2026, 11, 10))
    pg.add(workout)
    pg.flush()
    pg.add(SharedEvent(workout_id=workout.id, event_id=workout_event["id"], kind=1301))
    pg.flush()

    reactions = [make_reaction(f"fã {tag} {i}", workout_event) for i in range(3)]
    reactions.append(make_reaction(f"fã {tag} 0", workout_event, created_at=9_999))  # RN-06
    relay = FakeRelay(reactions)

    assert _sync(pg, relay).new_likes == 3
    assert _sync(pg, relay).new_likes == 0  # RF-24

    def likes() -> list[str]:
        return sorted(
            pg.scalars(select(Like.liker_pubkey).where(Like.event_id == workout_event["id"]))
        )

    before = likes()
    pg.execute(delete(Like).where(Like.event_id == workout_event["id"]))
    _sync(pg, relay)
    assert likes() == before  # ADR-004: cache reconstruível
