"""OPS-08 — `/health` estendido: banco e status do worker de sincronização."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.domain.models.worker_heartbeat import WorkerHeartbeat
from app.main import app
from app.services.worker_status import record_heartbeat, worker_status

NOW = datetime(2026, 11, 22, 12, 0, tzinfo=UTC)
INTERVAL = 300


def test_sem_heartbeat_o_worker_e_unknown(db_session: Session) -> None:
    assert worker_status(db_session, INTERVAL, now=NOW)["status"] == "unknown"


def test_ciclo_recente_e_ok(db_session: Session) -> None:
    record_heartbeat(db_session, now=NOW - timedelta(minutes=5))
    status = worker_status(db_session, INTERVAL, now=NOW)
    assert status["status"] == "ok"
    assert status["last_error"] is None
    assert status["last_success_at"] == NOW - timedelta(minutes=5)


def test_sem_sucesso_por_mais_de_tres_intervalos_e_stale(db_session: Session) -> None:
    record_heartbeat(db_session, now=NOW - timedelta(seconds=INTERVAL * 3 + 1))
    assert worker_status(db_session, INTERVAL, now=NOW)["status"] == "stale"


def test_falhas_recentes_mantem_o_ultimo_sucesso(db_session: Session) -> None:
    record_heartbeat(db_session, now=NOW - timedelta(hours=2))
    record_heartbeat(db_session, error="OSError", now=NOW - timedelta(minutes=1))
    status = worker_status(db_session, INTERVAL, now=NOW)
    assert status["status"] == "stale"
    assert status["last_error"] == "OSError"
    assert status["last_run_at"] == NOW - timedelta(minutes=1)
    assert status["last_success_at"] == NOW - timedelta(hours=2)


def test_worker_que_nunca_teve_sucesso_e_stale(db_session: Session) -> None:
    record_heartbeat(db_session, error="OSError", now=NOW)
    status = worker_status(db_session, INTERVAL, now=NOW)
    assert status["status"] == "stale"
    assert status["last_success_at"] is None


def test_heartbeat_e_uma_linha_por_worker(db_session: Session) -> None:
    for minutes in (10, 5, 1):
        record_heartbeat(db_session, now=NOW - timedelta(minutes=minutes))
    assert db_session.query(WorkerHeartbeat).count() == 1


def test_endpoint_mostra_banco_e_worker(client: TestClient, db_session: Session) -> None:
    record_heartbeat(db_session)
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert body["database"] == "ok"
    assert body["worker"]["status"] == "ok"
    assert body["worker"]["last_success_at"]


def test_banco_fora_do_ar_e_503(client: TestClient) -> None:
    class Broken:
        def execute(self, *args: object, **kwargs: object) -> None:
            raise OperationalError("SELECT 1", {}, Exception("conexão recusada"))

    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = lambda: Broken()
    try:
        response = client.get("/health")
    finally:
        if previous is not None:
            app.dependency_overrides[get_db] = previous
    assert response.status_code == 503
    assert response.json()["code"] == "database_unavailable"


@pytest.mark.parametrize("path", ["/health", "/version"])
def test_rotas_de_sistema_nao_exigem_token(client: TestClient, path: str) -> None:
    assert client.get(path).status_code == 200
