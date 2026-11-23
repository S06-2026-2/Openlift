"""BE-14 — replay: apaga o cache de likes e reconstrói a partir dos relays
(RF-53, RNF-06, ADR-0004), com o comando `python -m app.cli replay`."""

import asyncio
import contextlib
from datetime import date

import pytest
from nostr_helpers import FakeRelay, make_event, make_reaction
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import cli
from app.domain.models.like import Like
from app.domain.models.shared_event import SharedEvent
from app.domain.models.user import User
from app.domain.models.workout import Workout
from app.infra.nostr.relay_client import RelayClient
from app.services.nostr_sync_worker import sync_reactions
from app.services.replay_service import ReplayAborted, replay_likes


async def _no_sleep(_: float) -> None:
    return None


def _client(relay: FakeRelay) -> RelayClient:
    return RelayClient(["wss://relay.teste"], connect=relay.connect, sleep=_no_sleep, max_retries=1)


def _publish(db: Session, user: User, label: str) -> dict:
    event = make_event(label, kind=1301, tags=[["d", label]])
    workout = Workout(user_id=user.id, date=date(2026, 11, 10))
    db.add(workout)
    db.flush()
    db.add(SharedEvent(workout_id=workout.id, event_id=event["id"], kind=1301))
    db.commit()
    return event


def _likes(db: Session) -> list[tuple[str, str]]:
    return sorted(db.execute(select(Like.event_id, Like.liker_pubkey)).all())  # type: ignore[arg-type]


@pytest.fixture()
def scenario(db_session: Session, auth_user: User) -> FakeRelay:
    """Dois treinos publicados e curtidas nos relays (com repetição e dislike)."""
    treino_a = _publish(db_session, auth_user, "treino-a")
    treino_b = _publish(db_session, auth_user, "treino-b")
    return FakeRelay(
        [
            make_reaction("ana", treino_a),
            make_reaction("ana", treino_a, created_at=1_792_446_500),  # repetido: conta 1
            make_reaction("bia", treino_a),
            make_reaction("caio", treino_b),
            make_reaction("davi", treino_b, content="-"),  # dislike: ignorado
        ]
    )


def test_replay_reconstroi_a_mesma_contagem(db_session: Session, scenario: FakeRelay) -> None:
    asyncio.run(sync_reactions(db_session, _client(scenario)))
    original = _likes(db_session)
    assert len(original) == 3

    # Cache apagado "por acidente" e um like falso escrito à mão no banco.
    db_session.query(Like).delete()
    db_session.add(Like(event_id="f" * 64, liker_pubkey="e" * 64))
    db_session.commit()

    result = asyncio.run(replay_likes(db_session, _client(scenario)))

    assert _likes(db_session) == original
    assert (result.likes_before, result.likes_after) == (1, 3)
    assert result.shared_events == 2
    assert result.relays_ok == 1
    assert result.seconds < 300  # RNF-06


def test_replay_e_idempotente(db_session: Session, scenario: FakeRelay) -> None:
    asyncio.run(replay_likes(db_session, _client(scenario)))
    first = _likes(db_session)

    asyncio.run(replay_likes(db_session, _client(scenario)))

    assert _likes(db_session) == first


def test_relay_fora_do_ar_nao_apaga_nada(db_session: Session, scenario: FakeRelay) -> None:
    asyncio.run(sync_reactions(db_session, _client(scenario)))
    before = _likes(db_session)

    down = FakeRelay(fail_connects=100)
    with pytest.raises(ReplayAborted, match="nada foi apagado"):
        asyncio.run(replay_likes(db_session, _client(down)))

    assert _likes(db_session) == before


def test_simulacao_nao_grava(db_session: Session, scenario: FakeRelay) -> None:
    db_session.add(Like(event_id="f" * 64, liker_pubkey="e" * 64))
    db_session.commit()

    result = asyncio.run(replay_likes(db_session, _client(scenario), dry_run=True))

    assert result.likes_after == 3
    assert db_session.scalar(select(func.count()).select_from(Like)) == 1


def test_sem_treino_publicado_limpa_o_cache(db_session: Session) -> None:
    db_session.add(Like(event_id="f" * 64, liker_pubkey="e" * 64))
    db_session.commit()

    result = asyncio.run(replay_likes(db_session, _client(FakeRelay())))

    assert result.likes_after == 0
    assert _likes(db_session) == []


def _patch_cli(monkeypatch: pytest.MonkeyPatch, db: Session, relay: FakeRelay) -> None:
    import app.infra.db.session as session_module

    monkeypatch.setattr(session_module, "SessionLocal", lambda: contextlib.nullcontext(db))
    monkeypatch.setattr(RelayClient, "from_settings", classmethod(lambda cls: _client(relay)))


def test_comando_replay(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    db_session: Session,
    scenario: FakeRelay,
) -> None:
    _patch_cli(monkeypatch, db_session, scenario)

    assert cli.main(["replay"]) == 0

    out = capsys.readouterr().out
    assert "Replay concluído" in out
    assert "likes depois: 3" in out
    assert len(_likes(db_session)) == 3


def test_comando_replay_com_relay_fora_do_ar_sai_com_erro(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    db_session: Session,
    scenario: FakeRelay,
) -> None:
    _patch_cli(monkeypatch, db_session, FakeRelay(fail_connects=100))

    assert cli.main(["replay", "--dry-run"]) == 1
    assert "nada foi apagado" in capsys.readouterr().err
