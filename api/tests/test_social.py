"""Testes dos endpoints `/social` (BE-10).

As contagens saem do cache `likes`, preenchido aqui direto no banco; a
projeção a partir dos eventos `kind 7` é testada em test_nostr_sync_worker.py.

TODO(BE-15): compute_score / ranking semanal e endpoint /social/ranking.
"""

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.domain.models.like import Like
from app.domain.models.nostr_identity import NostrIdentity
from app.domain.models.user import User

URL = "/api/v1/social/likes"

# Ids e pubkeys de teste: só precisam ter o formato (hex de 64).
TREINO_A = "a" * 64
TREINO_B = "b" * 64
TREINO_SEM_LIKE = "c" * 64
EU = "1" * 64
FA_1 = "2" * 64
FA_2 = "3" * 64

# npub do vetor público da NIP-19 e o hex correspondente.
NPUB = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"
NPUB_HEX = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"


def _like(db: Session, event_id: str, pubkey: str) -> None:
    db.add(Like(event_id=event_id, liker_pubkey=pubkey))
    db.commit()


def _with_identity(db: Session, user: User, pubkey_hex: str = NPUB_HEX) -> None:
    db.add(NostrIdentity(user_id=user.id, npub=NPUB, pubkey_hex=pubkey_hex))
    db.commit()


def _get(client: TestClient, headers: dict[str, str], *event_ids: str):
    return client.get(URL, params=[("event_ids", e) for e in event_ids], headers=headers)


def test_sem_event_ids_devolve_lista_vazia(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.get(URL, headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == []


def test_conta_likes_por_evento_na_ordem_pedida(
    client: TestClient, auth_headers: dict[str, str], db_session: Session
) -> None:
    _like(db_session, TREINO_A, FA_1)
    _like(db_session, TREINO_A, FA_2)
    _like(db_session, TREINO_B, FA_1)

    response = _get(client, auth_headers, TREINO_B, TREINO_SEM_LIKE, TREINO_A)

    assert response.status_code == 200
    assert response.json() == [
        {"event_id": TREINO_B, "count": 1, "liked_by_me": False},
        {"event_id": TREINO_SEM_LIKE, "count": 0, "liked_by_me": False},
        {"event_id": TREINO_A, "count": 2, "liked_by_me": False},
    ]


def test_liked_by_me_usa_a_identidade_nostr_do_usuario(
    client: TestClient, auth_headers: dict[str, str], db_session: Session, auth_user: User
) -> None:
    _with_identity(db_session, auth_user, NPUB_HEX)
    _like(db_session, TREINO_A, NPUB_HEX)
    _like(db_session, TREINO_A, FA_1)
    _like(db_session, TREINO_B, FA_1)

    body = _get(client, auth_headers, TREINO_A, TREINO_B).json()

    assert body == [
        {"event_id": TREINO_A, "count": 2, "liked_by_me": True},
        {"event_id": TREINO_B, "count": 1, "liked_by_me": False},
    ]


def test_sem_identidade_liked_by_me_e_sempre_false(
    client: TestClient, auth_headers: dict[str, str], db_session: Session
) -> None:
    _like(db_session, TREINO_A, EU)
    assert _get(client, auth_headers, TREINO_A).json()[0]["liked_by_me"] is False


def test_like_de_outra_conta_nao_vira_liked_by_me(
    client: TestClient, db_session: Session, auth_user: User
) -> None:
    other = User(email="outra@openlift.dev", hashed_password=hash_password("senha-qualquer"))
    db_session.add(other)
    db_session.commit()
    _with_identity(db_session, auth_user, NPUB_HEX)
    _like(db_session, TREINO_A, NPUB_HEX)

    headers = {"Authorization": f"Bearer {create_access_token(other.id)}"}
    assert _get(client, headers, TREINO_A).json() == [
        {"event_id": TREINO_A, "count": 1, "liked_by_me": False}
    ]


def test_ids_repetidos_aparecem_uma_vez(
    client: TestClient, auth_headers: dict[str, str], db_session: Session
) -> None:
    _like(db_session, TREINO_A, FA_1)
    body = _get(client, auth_headers, TREINO_A, TREINO_A, TREINO_B, TREINO_A).json()
    assert [item["event_id"] for item in body] == [TREINO_A, TREINO_B]


def test_limite_de_100_event_ids(client: TestClient, auth_headers: dict[str, str]) -> None:
    ids = [f"{i:064x}" for i in range(101)]
    response = _get(client, auth_headers, *ids)
    assert response.status_code == 422
    assert response.json()["code"] == "too_many_event_ids"
    assert _get(client, auth_headers, *ids[:100]).status_code == 200


def test_100_ids_com_repeticao_nao_passam_do_limite(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    ids = [f"{i:064x}" for i in range(100)]
    assert _get(client, auth_headers, *ids, *ids).status_code == 200


def test_event_id_fora_do_formato_e_422(client: TestClient, auth_headers: dict[str, str]) -> None:
    for bad in ["abc", "A" * 64, "g" * 64, "npub1" + "q" * 58]:
        response = _get(client, auth_headers, TREINO_A, bad)
        assert response.status_code == 422, bad
        assert response.json()["code"] == "invalid_event_id"
        assert response.json()["detail"]


def test_sem_token_e_401(client: TestClient) -> None:
    response = client.get(URL, params={"event_ids": TREINO_A})
    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"


def test_rota_documentada_no_openapi(client: TestClient) -> None:
    operation = client.get("/openapi.json").json()["paths"][URL]["get"]
    assert operation["tags"] == ["social"]
    assert {"401", "422"} <= set(operation["responses"])
    schema = client.get("/openapi.json").json()["components"]["schemas"]["LikeCountOut"]
    assert schema["examples"][0]["count"] == 3
