"""GET /me — dados do usuário logado, com o npub registrado (se houver)."""

from fastapi.testclient import TestClient

from app.core.nostr import hex_to_npub
from app.domain.models.user import User

URL = "/api/v1/me"

# Pubkey dos exemplos do mini-NIP (docs/nips/examples).
PUBKEY_HEX = "3361fd648012d81dfb176fd52b6c0f6dd9c5979b3bf40beaa30a9dae199a7f6a"  # gitleaks:allow


def test_devolve_o_usuario_logado_sem_npub(
    client: TestClient, auth_headers: dict[str, str], auth_user: User
) -> None:
    response = client.get(URL, headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == auth_user.id
    assert body["email"] == auth_user.email
    assert body["npub"] is None
    assert "created_at" in body


def test_devolve_o_npub_depois_de_registrado(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    npub = hex_to_npub(PUBKEY_HEX)
    client.post(f"{URL}/nostr-identity", json={"npub": npub}, headers=auth_headers)

    response = client.get(URL, headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["npub"] == npub


def test_nao_expoe_senha_nem_pubkey_hex(client: TestClient, auth_headers: dict[str, str]) -> None:
    body = client.get(URL, headers=auth_headers).json()

    assert set(body) == {"id", "email", "npub", "created_at"}


def test_sem_token_e_401(client: TestClient) -> None:
    response = client.get(URL)

    assert response.status_code == 401
    assert response.json() == {"detail": "Autenticação necessária.", "code": "not_authenticated"}


def test_token_invalido_e_401(client: TestClient) -> None:
    response = client.get(URL, headers={"Authorization": "Bearer nao-e-um-jwt"})

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


def test_rota_documentada_no_openapi(client: TestClient) -> None:
    operation = client.get("/openapi.json").json()["paths"][URL]["get"]

    assert operation["tags"] == ["me"]
    assert "401" in operation["responses"]
