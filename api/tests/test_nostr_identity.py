"""BE-05 (S2-02) — POST /me/nostr-identity e validação de npub (NIP-19).

O backend só conhece a chave PÚBLICA (ADR-0006, RNF-01). Os npubs dos testes
são públicos: o vetor oficial da NIP-19 e chaves públicas de docs/nips/examples.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.nostr import hex_to_npub, npub_to_hex
from app.core.security import create_access_token, hash_password
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.user import User

URL = "/api/v1/me/nostr-identity"

# Vetor da NIP-19 (github.com/nostr-protocol/nips/blob/master/19.md).
NIP19_HEX = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
NIP19_NPUB = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"

# Pubkey dos exemplos do mini-NIP (docs/nips/examples).
OTHER_HEX = "3361fd648012d81dfb176fd52b6c0f6dd9c5979b3bf40beaa30a9dae199a7f6a"


def _identities(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(NostrIdentity)) or 0


def _pubkey_hex(db: Session, user: User) -> str | None:
    return db.scalar(select(NostrIdentity.pubkey_hex).where(NostrIdentity.user_id == user.id))


# ---------------------------------------------------------------------------
# NIP-19 (bech32)
# ---------------------------------------------------------------------------


def test_npub_decodifica_o_vetor_da_nip19() -> None:
    assert npub_to_hex(NIP19_NPUB) == NIP19_HEX


def test_npub_codifica_o_vetor_da_nip19() -> None:
    assert hex_to_npub(NIP19_HEX) == NIP19_NPUB


def test_npub_ida_e_volta() -> None:
    assert npub_to_hex(hex_to_npub(OTHER_HEX)) == OTHER_HEX


@pytest.mark.parametrize(
    "value",
    [
        "",
        "npub1",
        NIP19_HEX,  # hex no lugar do npub
        NIP19_NPUB[:-1] + ("q" if NIP19_NPUB[-1] != "q" else "p"),  # checksum errado
        NIP19_NPUB.replace("npub", "nsec", 1),  # prefixo de chave privada
        "nprofile1" + NIP19_NPUB[5:],
        NIP19_NPUB[:20],  # truncado
        NIP19_NPUB + "q",  # longo demais
        NIP19_NPUB.replace("0", "b", 1),  # caractere fora do alfabeto bech32
        NIP19_NPUB.upper()[:10] + NIP19_NPUB[10:],  # maiúsculas misturadas
    ],
)
def test_npub_invalido_e_recusado(value: str) -> None:
    with pytest.raises(ValueError):
        npub_to_hex(value)


# ---------------------------------------------------------------------------
# POST /me/nostr-identity
# ---------------------------------------------------------------------------


def test_registra_npub_e_devolve_user_out(
    client: TestClient, auth_headers: dict[str, str], auth_user: User, db_session: Session
) -> None:
    response = client.post(URL, json={"npub": NIP19_NPUB}, headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert body["npub"] == NIP19_NPUB
    assert body["id"] == auth_user.id
    assert body["email"] == auth_user.email
    assert _identities(db_session) == 1
    assert _pubkey_hex(db_session, auth_user) == NIP19_HEX


def test_pubkey_hex_nao_aparece_na_resposta(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.post(URL, json={"npub": NIP19_NPUB}, headers=auth_headers)

    assert "pubkey_hex" not in response.json()


def test_pubkey_hex_enviado_pelo_cliente_e_recusado(
    client: TestClient, auth_headers: dict[str, str], db_session: Session
) -> None:
    """O hex é derivado no servidor; o corpo continua aceitando só `npub`."""
    response = client.post(
        URL, json={"npub": NIP19_NPUB, "pubkey_hex": OTHER_HEX}, headers=auth_headers
    )

    assert response.status_code == 422
    assert _identities(db_session) == 0


def test_repetir_o_mesmo_npub_e_idempotente(
    client: TestClient, auth_headers: dict[str, str], db_session: Session
) -> None:
    first = client.post(URL, json={"npub": NIP19_NPUB}, headers=auth_headers)
    second = client.post(URL, json={"npub": NIP19_NPUB}, headers=auth_headers)

    assert first.status_code == second.status_code == 200
    assert second.json() == first.json()
    assert _identities(db_session) == 1


def test_npub_novo_do_mesmo_usuario_substitui(
    client: TestClient, auth_headers: dict[str, str], auth_user: User, db_session: Session
) -> None:
    """ADR-0005: trocar de dispositivo sem importar a chave gera identidade nova."""
    other = hex_to_npub(OTHER_HEX)
    client.post(URL, json={"npub": NIP19_NPUB}, headers=auth_headers)

    response = client.post(URL, json={"npub": other}, headers=auth_headers)

    assert response.status_code == 200
    assert response.json()["npub"] == other
    assert _identities(db_session) == 1
    db_session.expire_all()
    assert _pubkey_hex(db_session, auth_user) == OTHER_HEX


def test_npub_de_outra_conta_e_409(
    client: TestClient, auth_headers: dict[str, str], db_session: Session
) -> None:
    someone = User(email="outra@openlift.dev", hashed_password=hash_password("senha-segura-123"))
    db_session.add(someone)
    db_session.commit()
    other_headers = {"Authorization": f"Bearer {create_access_token(someone.id)}"}
    client.post(URL, json={"npub": NIP19_NPUB}, headers=other_headers)

    response = client.post(URL, json={"npub": NIP19_NPUB}, headers=auth_headers)

    assert response.status_code == 409
    assert response.json()["code"] == "npub_already_registered"
    assert _identities(db_session) == 1


def test_sem_token_e_401(client: TestClient) -> None:
    response = client.post(URL, json={"npub": NIP19_NPUB})

    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"


@pytest.mark.parametrize(
    "npub",
    ["npub1abc", NIP19_HEX, NIP19_NPUB[:-1] + "x", 42, None],
)
def test_npub_malformado_e_422_no_campo(
    client: TestClient, auth_headers: dict[str, str], db_session: Session, npub: object
) -> None:
    response = client.post(URL, json={"npub": npub}, headers=auth_headers)

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "validation_error"
    assert [e["field"] for e in body["errors"]] == ["npub"]
    assert _identities(db_session) == 0


@pytest.mark.parametrize("field", ["nsec", "private_key", "secret_key", "privkey"])
def test_campo_de_chave_privada_e_recusado(
    client: TestClient, auth_headers: dict[str, str], db_session: Session, field: str
) -> None:
    """RNF-01: o corpo aceita só a chave pública, e o valor recusado não volta no erro."""
    secret_like = "nsec1" + "q" * 58
    response = client.post(URL, json={"npub": NIP19_NPUB, field: secret_like}, headers=auth_headers)

    assert response.status_code == 422
    assert field in [e["field"] for e in response.json()["errors"]]
    assert secret_like not in response.text
    assert _identities(db_session) == 0


def test_rota_documentada_no_openapi(client: TestClient) -> None:
    operation = client.get("/openapi.json").json()["paths"][URL]["post"]

    assert operation["tags"] == ["me"]
    assert {"401", "409", "422"} <= set(operation["responses"])
    schema_ref = operation["requestBody"]["content"]["application/json"]["schema"]["$ref"]
    assert schema_ref.endswith("NostrIdentityIn")
