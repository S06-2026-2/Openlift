"""BE-04 — CRUD de treinos e séries: isolamento por usuário, limites RN-07,
RN-01 (publicado sem séries), filtros, paginação e rotas de série."""

from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.domain.models.exercise import Exercise
from app.domain.models.muscle_group import MuscleGroup
from app.domain.models.set import WorkoutSet
from app.domain.models.user import User
from app.infra.db.seed import seed_exercises

WORKOUTS = "/api/v1/workouts"


@pytest.fixture()
def library(db_session: Session) -> dict[str, int]:
    """Biblioteca do seed: nome do exercício → id."""
    seed_exercises(db_session)
    return {e.name: e.id for e in db_session.scalars(select(Exercise))}


@pytest.fixture()
def other_headers(db_session: Session) -> dict[str, str]:
    """Headers de um segundo usuário (B), para testar o isolamento."""
    user = User(email="b@openlift.dev", hashed_password=hash_password("senha-do-b-123"))
    db_session.add(user)
    db_session.commit()
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


def _set(exercise_id: int, **overrides: Any) -> dict[str, Any]:
    body: dict[str, Any] = {"exercise_id": exercise_id, "reps": 8, "weight_kg": 80, "rpe": 8}
    body.update(overrides)
    return body


def _create(
    client: TestClient, headers: dict[str, str], day: str = "2026-10-14", sets=None, **extra: Any
):
    payload = {"date": day, "sets": sets if sets is not None else [], **extra}
    return client.post(WORKOUTS, json=payload, headers=headers)


# ---------------------------------------------------------------------------
# Criar e detalhar
# ---------------------------------------------------------------------------


def test_create_workout_returns_201_with_sets(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench = library["Supino reto"]
    response = _create(
        client,
        auth_headers,
        sets=[_set(bench, reps=10, weight_kg=60, set_type="warmup", rpe=None), _set(bench)],
    )

    assert response.status_code == 201
    body = response.json()
    assert body["date"] == "2026-10-14"
    assert body["visibility"] == "private"
    assert body["publish_status"] == "local"
    assert [s["set_type"] for s in body["sets"]] == ["warmup", "normal"]
    assert body["sets"][0]["rpe"] is None
    assert float(body["sets"][1]["weight_kg"]) == 80
    assert all(isinstance(s["id"], int) for s in body["sets"])


def test_create_and_get_workout(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Agachamento livre"])]).json()

    response = client.get(f"{WORKOUTS}/{created['id']}", headers=auth_headers)

    assert response.status_code == 200
    assert response.json() == created


def test_publish_status_cannot_be_set_by_the_client(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = _create(client, auth_headers, publish_status="published")

    assert response.status_code == 201
    assert response.json()["publish_status"] == "local"


def test_workouts_require_authentication(client: TestClient) -> None:
    assert client.get(WORKOUTS).status_code == 401
    assert client.post(WORKOUTS, json={"date": "2026-10-14"}).status_code == 401


# ---------------------------------------------------------------------------
# Validação (RN-07)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("overrides", "field"),
    [
        ({"weight_kg": 1001}, "weight_kg"),
        ({"weight_kg": -1}, "weight_kg"),
        ({"reps": 501}, "reps"),
        ({"reps": 0}, "reps"),
        ({"rpe": 0}, "rpe"),
        ({"rpe": 11}, "rpe"),
        ({"set_type": "drop-set"}, "set_type"),
    ],
)
def test_limits_return_422(
    client: TestClient,
    auth_headers: dict[str, str],
    library: dict[str, int],
    overrides: dict[str, Any],
    field: str,
) -> None:
    response = _create(client, auth_headers, sets=[_set(library["Supino reto"], **overrides)])

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "validation_error"
    assert any(err["field"] == f"sets.0.{field}" for err in body["errors"])


def test_exactly_1000_kg_and_500_reps_are_accepted(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    response = _create(
        client,
        auth_headers,
        sets=[_set(library["Leg press 45°"], weight_kg=1000, reps=500, rpe=10)],
    )

    assert response.status_code == 201


def test_unknown_exercise_returns_422(client: TestClient, auth_headers: dict[str, str]) -> None:
    response = _create(client, auth_headers, sets=[_set(9999)])

    assert response.status_code == 422
    assert response.json()["code"] == "unknown_exercise"


def test_invalid_visibility_returns_422(client: TestClient, auth_headers: dict[str, str]) -> None:
    assert _create(client, auth_headers, visibility="public").status_code == 422


# ---------------------------------------------------------------------------
# Isolamento por usuário
# ---------------------------------------------------------------------------


def test_user_b_cannot_see_edit_or_delete_user_a_workout(
    client: TestClient,
    auth_headers: dict[str, str],
    other_headers: dict[str, str],
    library: dict[str, int],
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()
    url = f"{WORKOUTS}/{created['id']}"
    set_url = f"{url}/sets/{created['sets'][0]['id']}"

    responses = [
        client.get(url, headers=other_headers),
        client.patch(url, json={"date": "2026-01-01"}, headers=other_headers),
        client.delete(url, headers=other_headers),
        client.post(f"{url}/sets", json=_set(library["Supino reto"]), headers=other_headers),
        client.patch(set_url, json={"reps": 1}, headers=other_headers),
        client.delete(set_url, headers=other_headers),
    ]

    for response in responses:
        assert response.status_code == 404
        assert response.json()["code"] == "workout_not_found"
    # O treino do A continua intacto.
    assert client.get(url, headers=auth_headers).json() == created


def test_user_b_list_does_not_include_user_a_workouts(
    client: TestClient, auth_headers: dict[str, str], other_headers: dict[str, str]
) -> None:
    _create(client, auth_headers)

    page = client.get(WORKOUTS, headers=other_headers).json()

    assert page["items"] == []
    assert page["total"] == 0


def test_missing_workout_returns_same_404(client: TestClient, auth_headers: dict[str, str]) -> None:
    response = client.get(f"{WORKOUTS}/999999", headers=auth_headers)

    assert response.status_code == 404
    assert response.json() == {"detail": "Treino não encontrado.", "code": "workout_not_found"}


# ---------------------------------------------------------------------------
# Listagem: ordem, paginação e filtros
# ---------------------------------------------------------------------------


@pytest.fixture()
def history(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> dict[str, int]:
    """Três treinos: 01/10 (supino), 07/10 (agachamento) e 13/10 (supino + remada)."""
    ids = {
        "01": _create(client, auth_headers, "2026-10-01", [_set(library["Supino reto"])]),
        "07": _create(client, auth_headers, "2026-10-07", [_set(library["Agachamento livre"])]),
        "13": _create(
            client,
            auth_headers,
            "2026-10-13",
            [_set(library["Supino reto"]), _set(library["Remada curvada"])],
        ),
    }
    return {day: r.json()["id"] for day, r in ids.items()}


def _ids(page: dict) -> list[int]:
    return [w["id"] for w in page["items"]]


def test_list_newest_first(
    client: TestClient, auth_headers: dict[str, str], history: dict[str, int]
) -> None:
    page = client.get(WORKOUTS, headers=auth_headers).json()

    assert _ids(page) == [history["13"], history["07"], history["01"]]
    assert page["total"] == 3
    assert (page["limit"], page["offset"]) == (50, 0)


def test_list_pagination(
    client: TestClient, auth_headers: dict[str, str], history: dict[str, int]
) -> None:
    first = client.get(WORKOUTS, params={"limit": 2}, headers=auth_headers).json()
    second = client.get(WORKOUTS, params={"limit": 2, "offset": 2}, headers=auth_headers).json()

    assert _ids(first) == [history["13"], history["07"]]
    assert _ids(second) == [history["01"]]
    assert first["total"] == second["total"] == 3


def test_list_filter_by_date_range_is_inclusive(
    client: TestClient, auth_headers: dict[str, str], history: dict[str, int]
) -> None:
    page = client.get(
        WORKOUTS, params={"date_from": "2026-10-07", "date_to": "2026-10-13"}, headers=auth_headers
    ).json()

    assert _ids(page) == [history["13"], history["07"]]


def test_list_filter_by_exercise(
    client: TestClient,
    auth_headers: dict[str, str],
    history: dict[str, int],
    library: dict[str, int],
) -> None:
    page = client.get(
        WORKOUTS, params={"exercise_id": library["Supino reto"]}, headers=auth_headers
    ).json()

    assert _ids(page) == [history["13"], history["01"]]
    # Os treinos voltam com todas as séries, não só as do exercício filtrado.
    assert len(page["items"][0]["sets"]) == 2


def test_list_filter_by_muscle_group(
    client: TestClient,
    auth_headers: dict[str, str],
    db_session: Session,
    history: dict[str, int],
) -> None:
    legs = db_session.scalar(select(MuscleGroup).where(MuscleGroup.name == "Quadríceps"))
    assert legs is not None

    page = client.get(WORKOUTS, params={"muscle_group_id": legs.id}, headers=auth_headers).json()

    assert _ids(page) == [history["07"]]


def test_list_invalid_date_range_returns_422(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.get(
        WORKOUTS, params={"date_from": "2026-10-13", "date_to": "2026-10-01"}, headers=auth_headers
    )

    assert response.status_code == 422
    assert response.json()["code"] == "invalid_date_range"


@pytest.mark.parametrize("params", [{"limit": 0}, {"limit": 101}, {"offset": -1}])
def test_list_invalid_pagination_returns_422(
    client: TestClient, auth_headers: dict[str, str], params: dict[str, int]
) -> None:
    assert client.get(WORKOUTS, params=params, headers=auth_headers).status_code == 422


# ---------------------------------------------------------------------------
# Editar e excluir treino
# ---------------------------------------------------------------------------


def test_patch_changes_only_sent_fields(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()

    response = client.patch(
        f"{WORKOUTS}/{created['id']}",
        json={"date": "2026-10-15", "visibility": "published"},
        headers=auth_headers,
    )

    body = response.json()
    assert response.status_code == 200
    assert body["date"] == "2026-10-15"
    assert body["visibility"] == "published"
    assert body["sets"] == created["sets"]  # séries intocadas sem o campo "sets"


def test_patch_with_sets_replaces_all_sets(
    client: TestClient,
    auth_headers: dict[str, str],
    db_session: Session,
    library: dict[str, int],
) -> None:
    created = _create(
        client, auth_headers, sets=[_set(library["Supino reto"]), _set(library["Supino reto"])]
    ).json()

    response = client.patch(
        f"{WORKOUTS}/{created['id']}",
        json={"sets": [_set(library["Rosca direta"], reps=12, weight_kg=14)]},
        headers=auth_headers,
    )

    body = response.json()
    assert response.status_code == 200
    assert len(body["sets"]) == 1
    assert body["sets"][0]["exercise_id"] == library["Rosca direta"]
    # As séries antigas foram apagadas de verdade, não só desassociadas.
    assert db_session.scalar(select(func.count()).select_from(WorkoutSet)) == 1


def test_patch_with_invalid_set_is_rejected_and_keeps_old_sets(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()
    url = f"{WORKOUTS}/{created['id']}"

    response = client.patch(url, json={"sets": [_set(9999)]}, headers=auth_headers)

    assert response.status_code == 422
    assert client.get(url, headers=auth_headers).json()["sets"] == created["sets"]


def test_delete_workout_removes_it_and_its_sets(
    client: TestClient,
    auth_headers: dict[str, str],
    db_session: Session,
    library: dict[str, int],
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()
    url = f"{WORKOUTS}/{created['id']}"

    response = client.delete(url, headers=auth_headers)

    assert response.status_code == 204
    assert response.content == b""
    assert client.get(url, headers=auth_headers).status_code == 404
    assert db_session.scalar(select(func.count()).select_from(WorkoutSet)) == 0


# ---------------------------------------------------------------------------
# Rotas de série
# ---------------------------------------------------------------------------


def test_add_set(client: TestClient, auth_headers: dict[str, str], library: dict[str, int]) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()

    response = client.post(
        f"{WORKOUTS}/{created['id']}/sets",
        json=_set(library["Supino reto"], set_type="failure"),
        headers=auth_headers,
    )

    assert response.status_code == 201
    assert response.json()["set_type"] == "failure"
    detail = client.get(f"{WORKOUTS}/{created['id']}", headers=auth_headers).json()
    assert len(detail["sets"]) == 2


def test_add_set_validates_limits(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(client, auth_headers).json()

    response = client.post(
        f"{WORKOUTS}/{created['id']}/sets",
        json=_set(library["Supino reto"], weight_kg=1001),
        headers=auth_headers,
    )

    assert response.status_code == 422


def test_patch_set_changes_only_sent_fields_and_null_rpe_clears(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"], rpe=7)]).json()
    set_id = created["sets"][0]["id"]

    response = client.patch(
        f"{WORKOUTS}/{created['id']}/sets/{set_id}",
        json={"reps": 6, "rpe": None},
        headers=auth_headers,
    )

    body = response.json()
    assert response.status_code == 200
    assert body["reps"] == 6
    assert body["rpe"] is None
    assert float(body["weight_kg"]) == 80  # não enviado → mantido


def test_patch_set_rejects_null_required_field(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()

    response = client.patch(
        f"{WORKOUTS}/{created['id']}/sets/{created['sets'][0]['id']}",
        json={"reps": None},
        headers=auth_headers,
    )

    assert response.status_code == 422


def test_delete_set(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(
        client, auth_headers, sets=[_set(library["Supino reto"]), _set(library["Supino reto"])]
    ).json()
    first, second = (s["id"] for s in created["sets"])

    response = client.delete(f"{WORKOUTS}/{created['id']}/sets/{first}", headers=auth_headers)

    assert response.status_code == 204
    detail = client.get(f"{WORKOUTS}/{created['id']}", headers=auth_headers).json()
    assert [s["id"] for s in detail["sets"]] == [second]


def test_set_from_another_workout_returns_404(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    first = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()
    second = _create(client, auth_headers, sets=[_set(library["Supino reto"])]).json()
    foreign_set = second["sets"][0]["id"]

    response = client.delete(f"{WORKOUTS}/{first['id']}/sets/{foreign_set}", headers=auth_headers)

    assert response.status_code == 404
    assert response.json()["code"] == "set_not_found"


# ---------------------------------------------------------------------------
# RN-01 — treino publicado precisa de ao menos uma série
# ---------------------------------------------------------------------------

RN01_ERROR = {
    "detail": "Treino publicado precisa ter ao menos uma série.",
    "code": "published_workout_without_sets",
}


def test_rn01_create_published_without_sets_returns_422(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = _create(client, auth_headers, sets=[], visibility="published")

    assert response.status_code == 422
    assert response.json() == RN01_ERROR
    assert client.get(WORKOUTS, headers=auth_headers).json()["total"] == 0


def test_rn01_patch_to_published_without_sets_returns_422(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    created = _create(client, auth_headers, sets=[]).json()

    response = client.patch(
        f"{WORKOUTS}/{created['id']}", json={"visibility": "published"}, headers=auth_headers
    )

    assert response.status_code == 422
    assert response.json() == RN01_ERROR
    detail = client.get(f"{WORKOUTS}/{created['id']}", headers=auth_headers).json()
    assert detail["visibility"] == "private"


def test_rn01_delete_last_set_of_published_workout_returns_422(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(
        client, auth_headers, sets=[_set(library["Supino reto"])], visibility="published"
    ).json()
    only_set = created["sets"][0]["id"]

    response = client.delete(f"{WORKOUTS}/{created['id']}/sets/{only_set}", headers=auth_headers)

    assert response.status_code == 422
    assert response.json() == RN01_ERROR
    detail = client.get(f"{WORKOUTS}/{created['id']}", headers=auth_headers).json()
    assert [s["id"] for s in detail["sets"]] == [only_set]


def test_rn01_patch_published_with_empty_sets_returns_422(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    created = _create(
        client, auth_headers, sets=[_set(library["Supino reto"])], visibility="published"
    ).json()

    response = client.patch(f"{WORKOUTS}/{created['id']}", json={"sets": []}, headers=auth_headers)

    assert response.status_code == 422
    assert response.json() == RN01_ERROR
    detail = client.get(f"{WORKOUTS}/{created['id']}", headers=auth_headers).json()
    assert detail["sets"] == created["sets"]


# ---------------------------------------------------------------------------
# OpenAPI
# ---------------------------------------------------------------------------


def test_openapi_documents_all_workout_routes(client: TestClient) -> None:
    paths = client.get("/openapi.json").json()["paths"]

    assert set(paths[WORKOUTS]) == {"get", "post"}
    assert set(paths[f"{WORKOUTS}/{{workout_id}}"]) == {"get", "patch", "delete"}
    assert set(paths[f"{WORKOUTS}/{{workout_id}}/sets"]) == {"post"}
    assert set(paths[f"{WORKOUTS}/{{workout_id}}/sets/{{set_id}}"]) == {"patch", "delete"}
