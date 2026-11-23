"""OPS-08 — logs estruturados em JSON (RNF-14) e redação de chave (RNF-01).

A chave "privada" dos testes é derivada em tempo de execução: nada com cara
de segredo fica versionado (gitleaks).
"""

import hashlib
import json
import logging

import pytest
from fastapi.testclient import TestClient

from app.core.logging import REDACTED, JsonFormatter, configure_logging, redact, sanitize

SECRET_HEX = hashlib.sha256(b"openlift-ops08-chave-descartavel").hexdigest()
NSEC = "nsec1" + "q" * 58
EVENT_ID = "2763ff3b0e19519634b11700b323eb26fe82d5a53f1fe5da307c9b76eb847e93"


def _format(message: str, *args: object, exc: bool = False, **extra: object) -> dict:
    record = logging.LogRecord("openlift.teste", logging.INFO, __file__, 1, message, args, None)
    if exc:
        try:
            raise ValueError(f"falhou com {SECRET_HEX}")
        except ValueError:
            import sys

            record.exc_info = sys.exc_info()
    for key, value in extra.items():
        setattr(record, key, value)
    return json.loads(JsonFormatter().format(record))


def test_linha_e_json_com_campos_basicos() -> None:
    data = _format("Ciclo com %d likes", 3)
    assert data["message"] == "Ciclo com 3 likes"
    assert data["level"] == "INFO"
    assert data["logger"] == "openlift.teste"
    assert data["timestamp"].endswith("+00:00")


def test_campos_extra_entram_no_json() -> None:
    data = _format("Evento descartado", event_id=EVENT_ID, relay="wss://a", attempts=2)
    assert data["event_id"] == EVENT_ID
    assert data["relay"] == "wss://a"
    assert data["attempts"] == 2


def test_nsec_e_hex_de_64_na_mensagem_sao_redigidos() -> None:
    data = _format("payload %s e %s", NSEC, SECRET_HEX)
    assert NSEC not in data["message"] and SECRET_HEX not in data["message"]
    assert data["message"].count(REDACTED) == 2


def test_hex_de_64_em_campo_extra_qualquer_e_redigido() -> None:
    data = _format("x", body={"private_key": SECRET_HEX, "lista": [NSEC]}, outro=SECRET_HEX)
    assert data["body"] == {"private_key": REDACTED, "lista": [REDACTED]}
    assert data["outro"] == REDACTED


def test_event_id_e_pubkey_sao_mantidos_porque_sao_publicos() -> None:
    data = _format("x", event_id=EVENT_ID, pubkey=EVENT_ID)
    assert data["event_id"] == EVENT_ID
    assert data["pubkey"] == EVENT_ID


def test_campo_publico_com_valor_estranho_e_sanitizado() -> None:
    data = _format("x", event_id=f"{NSEC} lixo")
    assert NSEC not in data["event_id"]


def test_traceback_e_redigido() -> None:
    data = _format("erro", exc=True)
    assert "ValueError" in data["exception"]
    assert SECRET_HEX not in data["exception"]


def test_hex_mais_longo_que_64_nao_e_confundido() -> None:
    assert redact("sig=" + "ab" * 64) == "sig=" + "ab" * 64


def test_sanitize_tipos_simples_e_objetos() -> None:
    assert sanitize(None) is None
    assert sanitize(3) == 3
    assert sanitize(True) is True
    assert sanitize((NSEC,)) == [REDACTED]

    class Obj:
        def __str__(self) -> str:
            return f"obj {SECRET_HEX}"

    assert sanitize(Obj()) == f"obj {REDACTED}"


def test_configure_logging_e_idempotente() -> None:
    root = logging.getLogger()
    configure_logging("DEBUG")
    configure_logging("info")
    json_handlers = [h for h in root.handlers if isinstance(h.formatter, JsonFormatter)]
    assert len(json_handlers) == 1
    assert root.level == logging.INFO
    assert logging.getLogger("uvicorn.access").disabled is True


def test_log_level_invalido_e_recusado() -> None:
    from app.core.config import Settings

    with pytest.raises(ValueError):
        Settings(database_url="sqlite:///:memory:", log_level="BARULHO")


def test_cada_requisicao_gera_uma_linha_com_metodo_status_e_duracao(
    client: TestClient, caplog: pytest.LogCaptureFixture
) -> None:
    with caplog.at_level(logging.INFO, logger="openlift.http"):
        client.get("/version?token=segredo")
    records = [r for r in caplog.records if r.name == "openlift.http"]
    assert len(records) == 1
    record = records[0]
    assert record.method == "GET"  # type: ignore[attr-defined]
    assert record.path == "/version"  # type: ignore[attr-defined]
    assert record.status_code == 200  # type: ignore[attr-defined]
    assert record.duration_ms >= 0  # type: ignore[attr-defined]
    # query string fica fora do log da API (o httpx do TestClient loga a URL dele)
    assert all("segredo" not in r.getMessage() for r in records)
    assert "segredo" not in json.dumps(JsonFormatter().format(record))


def test_requisicao_com_erro_nao_tratado_e_registrada(caplog: pytest.LogCaptureFixture) -> None:
    from fastapi import FastAPI

    from app.core.middleware import RequestLoggingMiddleware

    app = FastAPI()
    app.add_middleware(RequestLoggingMiddleware)

    @app.get("/boom")
    def boom() -> None:
        raise RuntimeError("quebrou")

    with caplog.at_level(logging.ERROR, logger="openlift.http"):
        with pytest.raises(RuntimeError):
            TestClient(app).get("/boom")
    assert any(r.message == "Requisição falhou" for r in caplog.records)
