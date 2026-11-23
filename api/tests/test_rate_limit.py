"""OPS-05 — rate limiting nos endpoints públicos (RNF-03): passou do limite,
429 no formato {detail, code} com Retry-After."""

from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.rate_limit import client_ip

LOGIN = "/api/v1/auth/login"
LIKES = "/api/v1/social/likes"


@pytest.fixture()
def limits() -> Generator[None, None, None]:
    """Limites pequenos para o teste e de volta ao padrão no fim."""
    settings = get_settings()
    original = (settings.rate_limit_auth, settings.rate_limit_social, settings.rate_limit_enabled)
    settings.rate_limit_auth = "3/minute"
    settings.rate_limit_social = "2/minute"
    settings.rate_limit_enabled = True
    yield
    settings.rate_limit_auth, settings.rate_limit_social, settings.rate_limit_enabled = original


def _login(client: TestClient, ip: str = "203.0.113.1"):
    return client.post(
        LOGIN,
        json={"email": "ninguem@openlift.dev", "password": "senha-errada-123"},
        headers={"X-Forwarded-For": ip},
    )


def test_login_acima_do_limite_responde_429(client: TestClient, limits: None) -> None:
    for _ in range(3):
        assert _login(client).status_code == 401

    response = _login(client)

    assert response.status_code == 429
    assert response.json() == {
        "detail": "Muitas requisições em pouco tempo. Espere um pouco e tente de novo.",
        "code": "rate_limited",
    }
    assert int(response.headers["retry-after"]) >= 1


def test_cada_ip_tem_o_seu_limite(client: TestClient, limits: None) -> None:
    for _ in range(3):
        _login(client, ip="203.0.113.1")

    assert _login(client, ip="203.0.113.1").status_code == 429
    assert _login(client, ip="198.51.100.7").status_code == 401


def test_social_tem_limite_proprio(
    client: TestClient, auth_headers: dict[str, str], limits: None
) -> None:
    for _ in range(3):
        _login(client)  # gasta o limite de /auth

    assert client.get(LIKES, headers=auth_headers).status_code == 200
    assert client.get(LIKES, headers=auth_headers).status_code == 200
    third = client.get(LIKES, headers=auth_headers)
    assert third.status_code == 429
    assert third.json()["code"] == "rate_limited"


def test_rota_fora_dos_grupos_nao_e_limitada(
    client: TestClient, auth_headers: dict[str, str], limits: None
) -> None:
    for _ in range(5):
        assert client.get("/api/v1/workouts", headers=auth_headers).status_code == 200


def test_desligado_por_configuracao(client: TestClient, limits: None) -> None:
    get_settings().rate_limit_enabled = False

    for _ in range(5):
        assert _login(client).status_code == 401


def test_ip_vem_do_primeiro_x_forwarded_for() -> None:
    class _Req:
        def __init__(self, headers: dict[str, str], host: str | None) -> None:
            self.headers = headers
            self.client = type("C", (), {"host": host})() if host else None

    assert client_ip(_Req({"x-forwarded-for": "1.2.3.4, 10.0.0.1"}, "10.0.0.2")) == "1.2.3.4"  # type: ignore[arg-type]
    assert client_ip(_Req({}, "10.0.0.2")) == "10.0.0.2"  # type: ignore[arg-type]
    assert client_ip(_Req({}, None)) == "desconhecido"  # type: ignore[arg-type]
