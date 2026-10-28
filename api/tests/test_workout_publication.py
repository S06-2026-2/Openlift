"""BE-S2-03 — POST /workouts/{id}/publication e /publication-failure.

Cobre: idempotência por `event_id`, validação da `pubkey` do chamador contra o
npub registrado, RN-01 (treino sem série não publica), RN-08 (republicar gera
evento novo com o mesmo `d_tag`), isolamento por usuário e o fato de o PATCH
não conseguir mexer em `publish_status`/`d_tag`.

Só chaves PÚBLICAS nos testes (ADR-0006): o vetor da NIP-19 e a pubkey dos
exemplos do mini-NIP; os ids de evento são hex arbitrário.
"""

from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.nostr import KIND_WORKOUT_RECORD, hex_to_npub
from app.core.security import create_access_token, hash_password
from app.domain.models.exercise import Exercise
from app.domain.models.shared_event import SharedEvent
from app.domain.models.user import User
from app.domain.models.workout import Workout
from app.infra.db.seed import seed_exercises

WORKOUTS = "/api/v1/workouts"
IDENTITY = "/api/v1/me/nostr-identity"

# Vetor público da NIP-19: é a identidade do usuário principal nos testes.
NPUB = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"
PUBKEY = "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
# Pubkey dos exemplos do mini-NIP: válida, mas de outra identidade.
OTHER_PUBKEY = "3361fd648012d81dfb176fd52b6c0f6dd9c5979b3bf40beaa30a9dae199a7f6a"

EVENT_A = "a" * 64
EVENT_B = "b" * 64
EVENT_C = "c" * 64
D_TAG = "7c9e6679-7425-4f1b-9a2e-6a1f0c8d5b34"
OTHER_D_TAG = "0b5a3a52-4f5c-4a43-8b1e-3f0f9d7a2c11"


@pytest.fixture()
def library(db_session: Session) -> dict[str, int]:
    seed_exercises(db_session)
    return {e.name: e.id for e in db_session.scalars(select(Exercise))}


@pytest.fixture()
def identity(client: TestClient, auth_headers: dict[str, str]) -> str:
    """Registra o npub do usuário principal e devolve o hex da pubkey."""
    assert client.post(IDENTITY, json={"npub": NPUB}, headers=auth_headers).status_code == 200
    return PUBKEY


@pytest.fixture()
def other_headers(db_session: Session) -> dict[str, str]:
    user = User(email="b@openlift.dev", hashed_password=hash_password("senha-do-b-123"))
    db_session.add(user)
    db_session.commit()
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


def _workout(client: TestClient, headers: dict[str, str], library: dict[str, int]) -> int:
    body = {
        "date": "2026-10-14",
        "sets": [{"exercise_id": library["Supino reto"], "reps": 8, "weight_kg": 80}],
    }
    response = client.post(WORKOUTS, json=body, headers=headers)
    assert response.status_code == 201
    return int(response.json()["id"])


def _publish(
    client: TestClient,
    headers: dict[str, str],
    workout_id: int,
    *,
    event_id: str = EVENT_A,
    pubkey: str = PUBKEY,
    d_tag: str = D_TAG,
):
    body = {"event_id": event_id, "pubkey": pubkey, "d_tag": d_tag}
    return client.post(f"{WORKOUTS}/{workout_id}/publication", json=body, headers=headers)


def _fail(
    client: TestClient,
    headers: dict[str, str],
    workout_id: int,
    *,
    event_id: str = EVENT_A,
    pubkey: str = PUBKEY,
):
    body = {"event_id": event_id, "pubkey": pubkey}
    return client.post(f"{WORKOUTS}/{workout_id}/publication-failure", json=body, headers=headers)


def _events(db: Session, workout_id: int | None = None) -> list[SharedEvent]:
    query = select(SharedEvent).order_by(SharedEvent.id)
    if workout_id is not None:
        query = query.where(SharedEvent.workout_id == workout_id)
    return list(db.scalars(query))


def _count(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(SharedEvent)) or 0


def _error(response: Any, status: int, code: str) -> None:
    assert response.status_code == status
    assert response.json()["code"] == code


# ---------------------------------------------------------------------------
# POST /workouts/{id}/publication — caminho principal
# ---------------------------------------------------------------------------


def test_new_workout_has_no_d_tag_and_no_shared_event_id(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    body = client.get(f"{WORKOUTS}/{_workout(client, auth_headers, library)}", headers=auth_headers)

    assert body.json()["d_tag"] is None
    assert "shared_event_id" not in body.json()


def test_publish_marks_workout_published_and_records_the_event(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)

    response = _publish(client, auth_headers, workout_id)

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == workout_id
    assert body["publish_status"] == "published"
    assert body["visibility"] == "published"
    assert body["d_tag"] == D_TAG
    assert len(body["sets"]) == 1
    events = _events(db_session, workout_id)
    assert [(e.event_id, e.kind) for e in events] == [(EVENT_A, KIND_WORKOUT_RECORD)]


def test_publish_persists_across_reads(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], identity: str
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id)

    body = client.get(f"{WORKOUTS}/{workout_id}", headers=auth_headers).json()

    assert (body["publish_status"], body["d_tag"]) == ("published", D_TAG)


# ---------------------------------------------------------------------------
# Idempotência por event_id
# ---------------------------------------------------------------------------


def test_publish_same_event_twice_is_idempotent(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)

    first = _publish(client, auth_headers, workout_id)
    second = _publish(client, auth_headers, workout_id)

    assert first.status_code == second.status_code == 200
    assert second.json() == first.json()
    assert _count(db_session) == 1


def test_replaying_an_old_event_does_not_change_the_current_state(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id, event_id=EVENT_A)
    _fail(client, auth_headers, workout_id, event_id=EVENT_B)

    replay = _publish(client, auth_headers, workout_id, event_id=EVENT_A)

    assert replay.status_code == 200
    assert replay.json()["publish_status"] == "failed"
    assert _count(db_session) == 1


def test_event_id_already_used_by_another_workout_is_409(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    first = _workout(client, auth_headers, library)
    second = _workout(client, auth_headers, library)
    _publish(client, auth_headers, first, event_id=EVENT_A, d_tag=D_TAG)

    response = _publish(client, auth_headers, second, event_id=EVENT_A, d_tag=OTHER_D_TAG)

    _error(response, 409, "event_id_already_registered")
    assert _count(db_session) == 1
    assert db_session.get(Workout, second).d_tag is None  # type: ignore[union-attr]


# ---------------------------------------------------------------------------
# RN-08 — editar e publicar de novo: evento novo, mesmo d_tag
# ---------------------------------------------------------------------------


def test_republish_after_edit_creates_a_new_event_with_the_same_d_tag(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id, event_id=EVENT_A)
    edit = client.patch(
        f"{WORKOUTS}/{workout_id}",
        json={"sets": [{"exercise_id": library["Supino reto"], "reps": 10, "weight_kg": 82.5}]},
        headers=auth_headers,
    )
    assert edit.status_code == 200

    response = _publish(client, auth_headers, workout_id, event_id=EVENT_B)

    assert response.status_code == 200
    assert response.json()["d_tag"] == D_TAG
    assert response.json()["publish_status"] == "published"
    # O evento anterior permanece (imutabilidade do protocolo).
    assert [e.event_id for e in _events(db_session, workout_id)] == [EVENT_A, EVENT_B]


def test_republish_with_a_different_d_tag_is_422(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id, event_id=EVENT_A)

    response = _publish(client, auth_headers, workout_id, event_id=EVENT_B, d_tag=OTHER_D_TAG)

    _error(response, 422, "d_tag_mismatch")
    assert _count(db_session) == 1
    db_session.expire_all()
    assert db_session.get(Workout, workout_id).d_tag == D_TAG  # type: ignore[union-attr]


def test_d_tag_of_another_workout_of_the_same_user_is_409(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    first = _workout(client, auth_headers, library)
    second = _workout(client, auth_headers, library)
    _publish(client, auth_headers, first, event_id=EVENT_A)

    response = _publish(client, auth_headers, second, event_id=EVENT_B)

    _error(response, 409, "d_tag_already_used")
    assert _count(db_session) == 1


def test_d_tag_is_only_unique_per_user(
    client: TestClient,
    auth_headers: dict[str, str],
    other_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
) -> None:
    """O endereço NOSTR é pubkey + d: outro autor pode ter o mesmo `d`."""
    client.post(IDENTITY, json={"npub": hex_to_npub(OTHER_PUBKEY)}, headers=other_headers)
    mine = _workout(client, auth_headers, library)
    theirs = _workout(client, other_headers, library)

    assert _publish(client, auth_headers, mine, event_id=EVENT_A).status_code == 200
    response = _publish(client, other_headers, theirs, event_id=EVENT_B, pubkey=OTHER_PUBKEY)

    assert response.status_code == 200
    assert response.json()["d_tag"] == D_TAG


# ---------------------------------------------------------------------------
# Pubkey do chamador
# ---------------------------------------------------------------------------


def test_publish_with_someone_elses_pubkey_is_403(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)

    response = _publish(client, auth_headers, workout_id, pubkey=OTHER_PUBKEY)

    _error(response, 403, "pubkey_mismatch")
    assert _count(db_session) == 0
    db_session.expire_all()
    stored = db_session.get(Workout, workout_id)
    assert stored is not None
    assert (stored.publish_status, stored.d_tag) == ("local", None)


def test_publish_without_registered_identity_is_409(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], db_session: Session
) -> None:
    workout_id = _workout(client, auth_headers, library)

    response = _publish(client, auth_headers, workout_id)

    _error(response, 409, "nostr_identity_required")
    assert _count(db_session) == 0


def test_pubkey_follows_the_identity_replacement(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], identity: str
) -> None:
    """ADR-0005: o npub pode ser trocado; vale sempre o registrado agora."""
    workout_id = _workout(client, auth_headers, library)
    client.post(IDENTITY, json={"npub": hex_to_npub(OTHER_PUBKEY)}, headers=auth_headers)

    _error(_publish(client, auth_headers, workout_id), 403, "pubkey_mismatch")
    assert _publish(client, auth_headers, workout_id, pubkey=OTHER_PUBKEY).status_code == 200


# ---------------------------------------------------------------------------
# RN-01 e isolamento
# ---------------------------------------------------------------------------


def test_workout_without_sets_cannot_be_published(
    client: TestClient, auth_headers: dict[str, str], identity: str, db_session: Session
) -> None:
    workout_id = client.post(
        WORKOUTS, json={"date": "2026-10-14", "sets": []}, headers=auth_headers
    ).json()["id"]

    response = _publish(client, auth_headers, workout_id)

    _error(response, 422, "published_workout_without_sets")
    assert _count(db_session) == 0
    db_session.expire_all()
    stored = db_session.get(Workout, workout_id)
    assert stored is not None
    assert (stored.visibility, stored.publish_status, stored.d_tag) == ("private", "local", None)


def test_publish_someone_elses_workout_is_404(
    client: TestClient,
    auth_headers: dict[str, str],
    other_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    theirs = _workout(client, other_headers, library)

    _error(_publish(client, auth_headers, theirs), 404, "workout_not_found")
    _error(_fail(client, auth_headers, theirs), 404, "workout_not_found")
    assert _count(db_session) == 0


def test_publish_unknown_workout_is_404(
    client: TestClient, auth_headers: dict[str, str], identity: str
) -> None:
    _error(_publish(client, auth_headers, 9999), 404, "workout_not_found")


@pytest.mark.parametrize("path", ["publication", "publication-failure"])
def test_publication_routes_require_authentication(client: TestClient, path: str) -> None:
    response = client.post(f"{WORKOUTS}/1/{path}", json={"event_id": EVENT_A, "pubkey": PUBKEY})

    _error(response, 401, "not_authenticated")


# ---------------------------------------------------------------------------
# Validação do corpo (RNF-01)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("event_id", "A" * 64),  # maiúsculas
        ("event_id", "a" * 63),
        ("event_id", "g" * 64),
        ("pubkey", PUBKEY.upper()),
        ("pubkey", NPUB),  # npub no lugar do hex
        ("d_tag", D_TAG.upper()),
        ("d_tag", "7c9e6679-7425-1f1b-9a2e-6a1f0c8d5b34"),  # versão 1, não v4
        ("d_tag", "nao-e-um-uuid"),
    ],
)
def test_publish_malformed_field_is_422_on_that_field(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
    field: str,
    value: str,
) -> None:
    workout_id = _workout(client, auth_headers, library)
    body = {"event_id": EVENT_A, "pubkey": PUBKEY, "d_tag": D_TAG, field: value}

    response = client.post(f"{WORKOUTS}/{workout_id}/publication", json=body, headers=auth_headers)

    assert response.status_code == 422
    assert [e["field"] for e in response.json()["errors"]] == [field]
    assert _count(db_session) == 0


def test_publish_missing_d_tag_is_422(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], identity: str
) -> None:
    workout_id = _workout(client, auth_headers, library)

    response = client.post(
        f"{WORKOUTS}/{workout_id}/publication",
        json={"event_id": EVENT_A, "pubkey": PUBKEY},
        headers=auth_headers,
    )

    assert response.status_code == 422
    assert [e["field"] for e in response.json()["errors"]] == ["d_tag"]


@pytest.mark.parametrize("path", ["publication", "publication-failure"])
@pytest.mark.parametrize("field", ["nsec", "private_key", "secret_key", "sig", "content"])
def test_publication_body_refuses_extra_fields_and_never_echoes_them(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
    path: str,
    field: str,
) -> None:
    """RNF-01: o corpo é fechado; o valor recusado não volta no erro."""
    workout_id = _workout(client, auth_headers, library)
    secret_like = "nsec1" + "q" * 58
    body = {"event_id": EVENT_A, "pubkey": PUBKEY, "d_tag": D_TAG, field: secret_like}
    if path == "publication-failure":
        body.pop("d_tag")

    response = client.post(f"{WORKOUTS}/{workout_id}/{path}", json=body, headers=auth_headers)

    assert response.status_code == 422
    assert field in [e["field"] for e in response.json()["errors"]]
    assert secret_like not in response.text
    assert _count(db_session) == 0


# ---------------------------------------------------------------------------
# O PATCH não mexe em publish_status / d_tag (S2-05)
# ---------------------------------------------------------------------------


def test_patch_cannot_change_publication_fields(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)

    response = client.patch(
        f"{WORKOUTS}/{workout_id}",
        json={"publish_status": "published", "d_tag": D_TAG, "shared_event_id": EVENT_A},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["publish_status"] == "local"
    assert response.json()["d_tag"] is None


# ---------------------------------------------------------------------------
# POST /workouts/{id}/publication-failure
# ---------------------------------------------------------------------------


def test_failure_marks_workout_failed(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)

    response = _fail(client, auth_headers, workout_id)

    assert response.status_code == 200
    assert response.json()["publish_status"] == "failed"
    assert response.json()["d_tag"] is None
    assert _count(db_session) == 0  # nada foi publicado: nenhum evento registrado


def test_failure_is_idempotent(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], identity: str
) -> None:
    workout_id = _workout(client, auth_headers, library)

    first = _fail(client, auth_headers, workout_id)
    second = _fail(client, auth_headers, workout_id)

    assert first.status_code == second.status_code == 200
    assert second.json() == first.json()


def test_retry_after_failure_publishes(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], identity: str
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _fail(client, auth_headers, workout_id, event_id=EVENT_A)

    response = _publish(client, auth_headers, workout_id, event_id=EVENT_B)

    assert response.status_code == 200
    assert response.json()["publish_status"] == "published"


def test_failed_republish_keeps_d_tag_and_the_previous_event(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id, event_id=EVENT_A)

    response = _fail(client, auth_headers, workout_id, event_id=EVENT_B)

    assert response.status_code == 200
    assert response.json()["publish_status"] == "failed"
    assert response.json()["d_tag"] == D_TAG
    assert [e.event_id for e in _events(db_session, workout_id)] == [EVENT_A]


def test_failure_of_an_already_published_event_is_409(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
) -> None:
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id, event_id=EVENT_A)

    response = _fail(client, auth_headers, workout_id, event_id=EVENT_A)

    _error(response, 409, "event_already_published")
    status = client.get(f"{WORKOUTS}/{workout_id}", headers=auth_headers).json()["publish_status"]
    assert status == "published"


def test_failure_with_someone_elses_pubkey_is_403(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int], identity: str
) -> None:
    workout_id = _workout(client, auth_headers, library)

    _error(_fail(client, auth_headers, workout_id, pubkey=OTHER_PUBKEY), 403, "pubkey_mismatch")
    status = client.get(f"{WORKOUTS}/{workout_id}", headers=auth_headers).json()["publish_status"]
    assert status == "local"


def test_failure_without_registered_identity_is_409(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    workout_id = _workout(client, auth_headers, library)

    _error(_fail(client, auth_headers, workout_id), 409, "nostr_identity_required")


# ---------------------------------------------------------------------------
# Efeitos colaterais e documentação
# ---------------------------------------------------------------------------


def test_deleting_a_published_workout_keeps_its_events(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    identity: str,
    db_session: Session,
) -> None:
    """O evento já está nos relays: o registro sobrevive, só perde o vínculo."""
    workout_id = _workout(client, auth_headers, library)
    _publish(client, auth_headers, workout_id)

    assert client.delete(f"{WORKOUTS}/{workout_id}", headers=auth_headers).status_code == 204

    db_session.expire_all()
    kept = _events(db_session)
    assert [(e.event_id, e.workout_id) for e in kept] == [(EVENT_A, None)]


def test_routes_are_documented_in_openapi(client: TestClient) -> None:
    paths = client.get("/openapi.json").json()["paths"]

    for suffix, schema in (("publication", "PublicationIn"), ("publication-failure", None)):
        operation = paths[f"{WORKOUTS}/{{workout_id}}/{suffix}"]["post"]
        assert operation["tags"] == ["workouts"]
        assert {"401", "403", "404", "409", "422"} <= set(operation["responses"])
        ref = operation["requestBody"]["content"]["application/json"]["schema"]["$ref"]
        assert ref.endswith(schema or "PublicationFailureIn")
