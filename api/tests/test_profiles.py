"""Perfil da rede social (ADR-0012): nome de usuário único, busca, perfis por
pubkey e o diretório NIP-05 em /.well-known/nostr.json."""

from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.nostr import hex_to_npub
from app.core.security import create_access_token, hash_password
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.user import User

ME = "/api/v1/me/profile"
PROFILES = "/api/v1/profiles"

# Chaves públicas de teste (só precisam ter o formato).
PUB_A = "a1" * 32
PUB_B = "b2" * 32


def _identity(db: Session, user: User, pubkey: str) -> None:
    db.add(NostrIdentity(user_id=user.id, npub=hex_to_npub(pubkey), pubkey_hex=pubkey))
    db.commit()


@pytest.fixture()
def me(db_session: Session, auth_user: User) -> User:
    _identity(db_session, auth_user, PUB_A)
    return auth_user


@pytest.fixture()
def other_headers(db_session: Session) -> dict[str, str]:
    user = User(email="b@openlift.dev", hashed_password=hash_password("senha-do-b-123"))
    db_session.add(user)
    db_session.commit()
    _identity(db_session, user, PUB_B)
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


def _save(client: TestClient, headers: dict[str, str], **body: Any):
    return client.put(ME, json=body, headers=headers)


# ---------------------------------------------------------------------------
# /me/profile
# ---------------------------------------------------------------------------


def test_sem_perfil_responde_404(client: TestClient, auth_headers: dict, me: User) -> None:
    response = client.get(ME, headers=auth_headers)

    assert response.status_code == 404
    assert response.json()["code"] == "profile_not_found"


def test_cria_perfil_normalizando_o_nome(client: TestClient, auth_headers: dict, me: User) -> None:
    response = _save(
        client,
        auth_headers,
        username="  @Ana.Treina ",
        display_name=" Ana ",
        bio="",
        avatar_url="http://localhost:8000/media/abc.webp",
    )

    assert response.status_code == 200
    assert response.json() == {
        "username": "ana.treina",
        "display_name": "Ana",
        "bio": None,
        "avatar_url": "http://localhost:8000/media/abc.webp",
        "npub": hex_to_npub(PUB_A),
        "pubkey": PUB_A,
        "nip05": "ana.treina@localhost:8000",
    }
    assert client.get(ME, headers=auth_headers).json()["username"] == "ana.treina"


def test_edita_o_proprio_perfil_e_troca_de_nome(
    client: TestClient, auth_headers: dict, me: User
) -> None:
    _save(client, auth_headers, username="ana")

    response = _save(client, auth_headers, username="ana_fit", bio="Corrida")

    assert response.status_code == 200
    assert response.json()["username"] == "ana_fit"
    assert response.json()["bio"] == "Corrida"


def test_nome_repetido_responde_409(
    client: TestClient, auth_headers: dict, other_headers: dict, me: User
) -> None:
    _save(client, auth_headers, username="ana")

    response = _save(client, other_headers, username="ANA")

    assert response.status_code == 409
    assert response.json()["code"] == "username_taken"


@pytest.mark.parametrize("username", ["ab", "a" * 21, "ana treina", "ana-treina", "joão", "ana!"])
def test_nome_fora_do_formato_responde_422(
    client: TestClient, auth_headers: dict, me: User, username: str
) -> None:
    response = _save(client, auth_headers, username=username)

    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"


def test_foto_precisa_ser_url_http(client: TestClient, auth_headers: dict, me: User) -> None:
    response = _save(client, auth_headers, username="ana", avatar_url="javascript:alert(1)")

    assert response.status_code == 422


def test_campo_desconhecido_e_recusado(client: TestClient, auth_headers: dict, me: User) -> None:
    response = _save(client, auth_headers, username="ana", nsec="nsec1qualquer")

    assert response.status_code == 422


def test_sem_identidade_nostr_responde_409(client: TestClient, auth_headers: dict) -> None:
    response = _save(client, auth_headers, username="ana")

    assert response.status_code == 409
    assert response.json()["code"] == "nostr_identity_required"


def test_perfil_exige_login(client: TestClient) -> None:
    assert client.get(ME).status_code == 401
    assert client.put(ME, json={"username": "ana"}).status_code == 401


# ---------------------------------------------------------------------------
# /profiles
# ---------------------------------------------------------------------------


def test_disponibilidade(
    client: TestClient, auth_headers: dict, other_headers: dict, me: User
) -> None:
    _save(client, auth_headers, username="ana")

    def check(headers: dict, name: str):
        return client.get(
            f"{PROFILES}/availability", params={"username": name}, headers=headers
        ).json()

    assert check(other_headers, "Ana") == {"username": "ana", "available": False}
    assert check(auth_headers, "ana") == {"username": "ana", "available": True}
    assert check(other_headers, "bia") == {"username": "bia", "available": True}

    invalid = client.get(
        f"{PROFILES}/availability", params={"username": "a b"}, headers=auth_headers
    )
    assert invalid.status_code == 422
    assert invalid.json()["code"] == "invalid_username"


def test_busca_por_nome_e_nome_de_exibicao(
    client: TestClient, auth_headers: dict, other_headers: dict, me: User
) -> None:
    _save(client, auth_headers, username="ana.treina", display_name="Ana Souza")
    _save(client, other_headers, username="bia_run", display_name="Bia Corredora")

    def search(q: str) -> list[str]:
        response = client.get(f"{PROFILES}/search", params={"q": q}, headers=auth_headers)
        return [p["username"] for p in response.json()]

    assert search("an") == ["ana.treina"]
    assert search("@BIA") == ["bia_run"]
    assert search("corredora") == ["bia_run"]
    assert search("_") == []  # curinga do LIKE é literal
    assert search("xyz") == []


def test_perfis_por_pubkey(
    client: TestClient, auth_headers: dict, other_headers: dict, me: User
) -> None:
    _save(client, auth_headers, username="ana")

    response = client.get(
        PROFILES, params=[("pubkeys", PUB_A), ("pubkeys", PUB_B)], headers=auth_headers
    )

    assert response.status_code == 200
    assert [p["username"] for p in response.json()] == ["ana"]  # B não tem perfil


def test_perfis_por_pubkey_valida_formato(client: TestClient, auth_headers: dict) -> None:
    response = client.get(PROFILES, params={"pubkeys": "npub1x"}, headers=auth_headers)

    assert response.status_code == 422
    assert response.json()["code"] == "invalid_pubkey"


def test_perfil_por_nome(client: TestClient, auth_headers: dict, me: User) -> None:
    _save(client, auth_headers, username="ana")

    assert client.get(f"{PROFILES}/@Ana", headers=auth_headers).json()["pubkey"] == PUB_A
    missing = client.get(f"{PROFILES}/ninguem", headers=auth_headers)
    assert missing.status_code == 404
    assert missing.json()["code"] == "profile_not_found"


# ---------------------------------------------------------------------------
# /.well-known/nostr.json (NIP-05)
# ---------------------------------------------------------------------------


def test_nip05_liga_o_nome_a_pubkey(client: TestClient, auth_headers: dict, me: User) -> None:
    _save(client, auth_headers, username="ana")

    response = client.get("/.well-known/nostr.json", params={"name": "ana"})

    assert response.status_code == 200
    assert response.json() == {"names": {"ana": PUB_A}}
    assert response.headers["access-control-allow-origin"] == "*"


@pytest.mark.parametrize("params", [{}, {"name": "ninguem"}, {"name": "a b"}])
def test_nip05_nao_lista_o_diretorio(
    client: TestClient, auth_headers: dict, me: User, params: dict
) -> None:
    _save(client, auth_headers, username="ana")

    assert client.get("/.well-known/nostr.json", params=params).json() == {"names": {}}
