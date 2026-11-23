"""BE-09 — worker: projeção de likes no Postgres (RF-52, RF-24, RN-06, ADR-004).

Relay simulado (tests/nostr_helpers.FakeRelay) e eventos assinados com chaves
descartáveis. O teste de integração com Postgres fica em
test_nostr_sync_worker_postgres.py.
"""

import asyncio
from datetime import UTC, date, datetime

import pytest
from nostr_helpers import FakeRelay, MultiRelay, make_event, make_reaction, tampered
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.domain.models.like import Like
from app.domain.models.shared_event import SharedEvent
from app.domain.models.user import User
from app.domain.models.worker_heartbeat import WorkerHeartbeat
from app.domain.models.workout import Workout
from app.infra.nostr.relay_client import RelayClient
from app.services import nostr_sync_worker
from app.services.nostr_sync_worker import (
    FILTER_CHUNK,
    project_likes,
    reaction_filters,
    sync_reactions,
    target_event_id,
)


async def _no_sleep(_: float) -> None:
    return None


def _client(relay: FakeRelay | MultiRelay, urls: list[str] | None = None) -> RelayClient:
    return RelayClient(urls or ["wss://relay.teste"], connect=relay.connect, sleep=_no_sleep)


def _publish(db: Session, user: User, label: str = "autor", kind: int = 1301) -> dict:
    """Treino publicado: evento assinado + linha em shared_events."""
    event = make_event(label, kind=kind, tags=[["d", label]], created_at=1_792_445_400)
    workout = Workout(user_id=user.id, date=date(2026, 11, 10))
    db.add(workout)
    db.flush()
    db.add(SharedEvent(workout_id=workout.id, event_id=event["id"], kind=kind))
    db.commit()
    return event


def _likes(db: Session) -> list[tuple[str, str]]:
    return sorted(db.execute(select(Like.event_id, Like.liker_pubkey)).all())  # type: ignore[arg-type]


def _sync(db: Session, relay: FakeRelay | MultiRelay, urls: list[str] | None = None):
    return asyncio.run(sync_reactions(db, _client(relay, urls)))


# ---------------------------------------------------------------------------
# Regras de projeção
# ---------------------------------------------------------------------------


def test_like_em_treino_publicado_entra_em_likes(db_session: Session, auth_user: User) -> None:
    workout = _publish(db_session, auth_user)
    like = make_reaction("fã", workout, created_at=1_792_446_000)

    result = _sync(db_session, FakeRelay([workout, like]))

    assert result.new_likes == 1
    assert _likes(db_session) == [(workout["id"], like["pubkey"])]
    row = db_session.scalars(select(Like)).one()
    assert row.created_at.replace(tzinfo=UTC) == datetime.fromtimestamp(1_792_446_000, tz=UTC)


def test_dois_kind7_da_mesma_pessoa_no_mesmo_treino_contam_um(
    db_session: Session, auth_user: User
) -> None:
    """RN-06; vale o like mais antigo."""
    workout = _publish(db_session, auth_user)
    first = make_reaction("fã", workout, created_at=1_000)
    second = make_reaction("fã", workout, content="🔥", created_at=2_000)

    result = _sync(db_session, FakeRelay([second, first]))

    assert result.new_likes == 1
    row = db_session.scalars(select(Like)).one()
    assert row.created_at.replace(tzinfo=UTC) == datetime.fromtimestamp(1_000, tz=UTC)


def test_pessoas_diferentes_contam_separado(db_session: Session, auth_user: User) -> None:
    workout = _publish(db_session, auth_user)
    likes = [make_reaction(f"fã {i}", workout) for i in range(3)]
    assert _sync(db_session, FakeRelay(likes)).new_likes == 3


def test_mesmo_evento_ingerido_duas_vezes_nao_duplica(db_session: Session, auth_user: User) -> None:
    """RF-24: em dois relays e em dois ciclos seguidos."""
    workout = _publish(db_session, auth_user)
    like = make_reaction("fã", workout)
    relays = MultiRelay({"wss://a": FakeRelay([like]), "wss://b": FakeRelay([like])})

    assert _sync(db_session, relays, ["wss://a", "wss://b"]).new_likes == 1
    assert _sync(db_session, relays, ["wss://a", "wss://b"]).new_likes == 0
    assert len(_likes(db_session)) == 1


def test_dislike_e_ignorado(db_session: Session, auth_user: User) -> None:
    """`content` "-" é dislike na NIP-25; o OpenLift não conta."""
    workout = _publish(db_session, auth_user)
    dislike = make_reaction("crítico", workout, content="-")
    assert _sync(db_session, FakeRelay([dislike])).new_likes == 0
    assert _likes(db_session) == []


@pytest.mark.parametrize("content", ["+", "", "🔥", "💪"])
def test_mais_vazio_e_emoji_contam_como_like(
    db_session: Session, auth_user: User, content: str
) -> None:
    workout = _publish(db_session, auth_user)
    assert (
        _sync(db_session, FakeRelay([make_reaction("fã", workout, content=content)])).new_likes == 1
    )


def test_reacao_a_evento_que_nao_e_do_openlift_e_ignorada(
    db_session: Session, auth_user: User
) -> None:
    workout = _publish(db_session, auth_user)
    like = make_reaction("fã", make_event("estranho", kind=1301))
    assert project_likes(db_session, [like], {workout["id"]}) == 0


def test_alvo_e_a_ultima_tag_e(db_session: Session, auth_user: User) -> None:
    workout = _publish(db_session, auth_user)
    other = make_event("outro", kind=1)
    reply_like = make_event(
        "fã",
        kind=7,
        tags=[["e", other["id"]], ["e", workout["id"]], ["p", workout["pubkey"]]],
        content="+",
    )
    assert target_event_id(reply_like) == workout["id"]
    assert _sync(db_session, FakeRelay([reply_like])).new_likes == 1


def test_reacao_sem_tag_e_e_ignorada(db_session: Session, auth_user: User) -> None:
    _publish(db_session, auth_user)
    orphan = make_event("fã", kind=7, tags=[["p", "a" * 64]], content="+")
    assert target_event_id(orphan) is None
    assert project_likes(db_session, [orphan], {"a" * 64}) == 0


def test_evento_que_nao_e_kind7_e_ignorado(db_session: Session, auth_user: User) -> None:
    workout = _publish(db_session, auth_user)
    note = make_event("fã", kind=1, tags=[["e", workout["id"]]], content="+")
    assert project_likes(db_session, [note], {workout["id"]}) == 0


def test_like_adulterado_nao_e_contado(db_session: Session, auth_user: User) -> None:
    """RNF-02: o worker só vê o que o RelayClient verificou."""
    workout = _publish(db_session, auth_user)
    real = make_reaction("fã", workout)
    forged = tampered(make_reaction("bot", workout), sig=real["sig"])
    assert _sync(db_session, FakeRelay([forged])).new_likes == 0


def test_like_em_evento_que_nao_e_treino_nao_conta(db_session: Session, auth_user: User) -> None:
    article = _publish(db_session, auth_user, label="artigo", kind=30023)
    assert _sync(db_session, FakeRelay([make_reaction("fã", article)])).shared_events == 0
    assert _likes(db_session) == []


# ---------------------------------------------------------------------------
# Cache reconstruível (ADR-004) e ciclo
# ---------------------------------------------------------------------------


def test_apagar_likes_e_sincronizar_de_novo_reconstroi_a_contagem(
    db_session: Session, auth_user: User
) -> None:
    workouts = [_publish(db_session, auth_user, label=f"treino {i}") for i in range(3)]
    reactions = [make_reaction(f"fã {j}", w) for w in workouts for j in range(2)]
    reactions.append(make_reaction("fã 0", workouts[0], created_at=9_999))  # repetido
    relay = FakeRelay(reactions)

    _sync(db_session, relay)
    before = _likes(db_session)
    db_session.execute(delete(Like))
    db_session.commit()
    _sync(db_session, relay)

    assert len(before) == 6
    assert _likes(db_session) == before


def test_sem_treinos_publicados_nao_conecta_no_relay(db_session: Session) -> None:
    relay = FakeRelay()
    result = _sync(db_session, relay)
    assert result.shared_events == 0
    assert relay.connections == 0


def test_muitos_treinos_viram_varios_filtros(db_session: Session, auth_user: User) -> None:
    ids = [f"{i:064x}" for i in range(FILTER_CHUNK * 2 + 5)]
    filters = reaction_filters(ids)
    assert [len(f["#e"]) for f in filters] == [FILTER_CHUNK, FILTER_CHUNK, 5]
    assert all(f["kinds"] == [7] for f in filters)


def test_ciclo_grava_muitos_likes_em_lotes(db_session: Session, auth_user: User) -> None:
    workout = _publish(db_session, auth_user)
    reactions = [make_reaction(f"fã {i}", workout) for i in range(FILTER_CHUNK + 20)]
    assert project_likes(db_session, reactions, {workout["id"]}) == FILTER_CHUNK + 20
    db_session.commit()
    assert project_likes(db_session, reactions, {workout["id"]}) == 0
    assert db_session.scalar(select(func.count()).select_from(Like)) == FILTER_CHUNK + 20


def test_run_sync_cycle_usa_sessao_e_relays_da_configuracao(
    db_session: Session, auth_user: User, monkeypatch: pytest.MonkeyPatch
) -> None:
    workout = _publish(db_session, auth_user)
    relay = FakeRelay([make_reaction("fã", workout)])

    class _Session:
        def __enter__(self) -> Session:
            return db_session

        def __exit__(self, *exc: object) -> None:
            return None

    monkeypatch.setattr("app.infra.db.session.SessionLocal", _Session)
    monkeypatch.setattr(RelayClient, "from_settings", classmethod(lambda cls: _client(relay)))

    result = nostr_sync_worker.run_sync_cycle()
    assert result is not None and result.new_likes == 1
    # OPS-08: o ciclo deixa o heartbeat que o /health lê.
    beat = db_session.get(WorkerHeartbeat, "nostr-sync")
    assert beat is not None and beat.last_success_at is not None and beat.last_error is None


def test_ciclo_que_falha_registra_o_erro_no_heartbeat(
    db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = {"n": 0}

    class _Session:
        def __enter__(self) -> Session:
            calls["n"] += 1
            if calls["n"] == 1:
                raise ConnectionError("relay e banco instáveis")
            return db_session

        def __exit__(self, *exc: object) -> None:
            return None

    monkeypatch.setattr("app.infra.db.session.SessionLocal", _Session)
    assert nostr_sync_worker.run_sync_cycle() is None
    beat = db_session.get(WorkerHeartbeat, "nostr-sync")
    assert beat is not None and beat.last_error == "ConnectionError"
    assert beat.last_success_at is None


def test_run_sync_cycle_nao_propaga_erro(monkeypatch: pytest.MonkeyPatch) -> None:
    def boom() -> None:
        raise RuntimeError("banco fora do ar")

    monkeypatch.setattr("app.infra.db.session.SessionLocal", boom)
    assert nostr_sync_worker.run_sync_cycle() is None


# ---------------------------------------------------------------------------
# Agendador
# ---------------------------------------------------------------------------


def test_agendador_usa_intervalo_da_configuracao(monkeypatch: pytest.MonkeyPatch) -> None:
    from app import worker

    settings = Settings(database_url="sqlite:///:memory:", nostr_sync_interval_seconds=42)
    monkeypatch.setattr(worker, "get_settings", lambda: settings)

    scheduler = worker.build_scheduler()
    job = scheduler.get_job(worker.JOB_ID)

    assert job.trigger.interval.total_seconds() == 42
    assert job.max_instances == 1
    assert job.coalesce is True
    assert job.func is nostr_sync_worker.run_sync_cycle


def test_intervalo_minimo_de_10_segundos() -> None:
    with pytest.raises(ValueError):
        Settings(database_url="sqlite:///:memory:", nostr_sync_interval_seconds=5)
