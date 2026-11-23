"""Estatísticas do dashboard (RF-41, RF-42, RF-54): volume semanal, volume e
frequência por grupo muscular e heatmap.

Volume = Σ carga × repetições sem aquecimento (RN-03). Cobre usuário sem
treinos (zerado, não erro), isolamento por usuário e validação do período.
"""

from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.domain.models.exercise import Exercise
from app.domain.models.user import User
from app.infra.db.seed import seed_exercises

STATS = "/api/v1/stats"


@pytest.fixture()
def library(db_session: Session) -> dict[str, int]:
    seed_exercises(db_session)
    return {e.name: e.id for e in db_session.scalars(select(Exercise))}


@pytest.fixture()
def other_headers(db_session: Session) -> dict[str, str]:
    user = User(email="b@openlift.dev", hashed_password=hash_password("senha-do-b-123"))
    db_session.add(user)
    db_session.commit()
    return {"Authorization": f"Bearer {create_access_token(user.id)}"}


def _set(exercise_id: int, reps: int, weight: float, set_type: str = "normal") -> dict[str, Any]:
    return {"exercise_id": exercise_id, "reps": reps, "weight_kg": weight, "set_type": set_type}


def _workout(client: TestClient, headers: dict[str, str], day: str, *sets: dict) -> None:
    response = client.post(
        "/api/v1/workouts", json={"date": day, "sets": list(sets)}, headers=headers
    )
    assert response.status_code == 201, response.text


# ---------------------------------------------------------------------------
# /stats/volume
# ---------------------------------------------------------------------------


def test_volume_sem_treinos_vem_zerado(client: TestClient, auth_headers: dict[str, str]) -> None:
    response = client.get(
        f"{STATS}/volume", params={"periods": 3, "date_to": "2026-11-19"}, headers=auth_headers
    )

    assert response.status_code == 200
    assert response.json() == {
        "group_by": "week",
        "periods": [
            {"period_start": "2026-11-02", "volume": 0.0, "workouts": 0},
            {"period_start": "2026-11-09", "volume": 0.0, "workouts": 0},
            {"period_start": "2026-11-16", "volume": 0.0, "workouts": 0},
        ],
        "total_volume": 0.0,
        "total_workouts": 0,
        "workouts_this_month": 0,
        "streak_days": 0,
    }


def test_volume_soma_por_semana_iso_sem_aquecimento(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench, squat = library["Supino reto"], library["Agachamento livre"]
    # Semana de 09/11: dois treinos.
    _workout(client, auth_headers, "2026-11-09", _set(bench, 10, 60), _set(bench, 10, 40, "warmup"))
    _workout(client, auth_headers, "2026-11-15", _set(squat, 5, 100))
    # Semana de 16/11 (19/11 é quinta): um treino com série até a falha.
    _workout(client, auth_headers, "2026-11-19", _set(squat, 8, 82.5, "failure"))
    # Fora da janela de 2 semanas: não entra.
    _workout(client, auth_headers, "2026-11-08", _set(bench, 10, 100))

    body = client.get(
        f"{STATS}/volume", params={"periods": 2, "date_to": "2026-11-19"}, headers=auth_headers
    ).json()

    assert body["periods"] == [
        {"period_start": "2026-11-09", "volume": 1100.0, "workouts": 2},
        {"period_start": "2026-11-16", "volume": 660.0, "workouts": 1},
    ]
    assert body["total_volume"] == 1760.0
    assert body["total_workouts"] == 3


def test_volume_conta_treino_so_de_aquecimento_mas_sem_volume(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    _workout(client, auth_headers, "2026-11-17", _set(library["Supino reto"], 10, 40, "warmup"))

    body = client.get(
        f"{STATS}/volume", params={"periods": 1, "date_to": "2026-11-19"}, headers=auth_headers
    ).json()

    assert body["periods"] == [{"period_start": "2026-11-16", "volume": 0.0, "workouts": 1}]


def test_volume_nao_mistura_usuarios(
    client: TestClient,
    auth_headers: dict[str, str],
    other_headers: dict[str, str],
    library: dict[str, int],
) -> None:
    _workout(client, other_headers, "2026-11-18", _set(library["Supino reto"], 10, 100))

    body = client.get(
        f"{STATS}/volume", params={"periods": 1, "date_to": "2026-11-19"}, headers=auth_headers
    ).json()

    assert body["total_volume"] == 0.0
    assert body["total_workouts"] == 0


@pytest.mark.parametrize("weeks", [0, 53])
def test_volume_limita_semanas(
    client: TestClient, auth_headers: dict[str, str], weeks: int
) -> None:
    response = client.get(f"{STATS}/volume", params={"periods": weeks}, headers=auth_headers)

    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"


def test_volume_padrao_tem_12_periodos(client: TestClient, auth_headers: dict[str, str]) -> None:
    body = client.get(f"{STATS}/volume", headers=auth_headers).json()

    assert len(body["periods"]) == 12


def test_volume_por_mes(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench = library["Supino reto"]
    _workout(client, auth_headers, "2026-09-30", _set(bench, 10, 50))
    _workout(client, auth_headers, "2026-10-01", _set(bench, 10, 60))
    _workout(client, auth_headers, "2026-11-19", _set(bench, 10, 70), _set(bench, 5, 70, "warmup"))

    body = client.get(
        f"{STATS}/volume",
        params={"group_by": "month", "periods": 3, "date_to": "2026-11-19"},
        headers=auth_headers,
    ).json()

    assert body["group_by"] == "month"
    assert body["periods"] == [
        {"period_start": "2026-09-01", "volume": 500.0, "workouts": 1},
        {"period_start": "2026-10-01", "volume": 600.0, "workouts": 1},
        {"period_start": "2026-11-01", "volume": 700.0, "workouts": 1},
    ]
    assert body["workouts_this_month"] == 1


def test_volume_por_mes_atravessa_o_ano(client: TestClient, auth_headers: dict[str, str]) -> None:
    body = client.get(
        f"{STATS}/volume",
        params={"group_by": "month", "periods": 3, "date_to": "2027-01-10"},
        headers=auth_headers,
    ).json()

    assert [p["period_start"] for p in body["periods"]] == [
        "2026-11-01",
        "2026-12-01",
        "2027-01-01",
    ]


def test_streak_atravessa_virada_de_mes_e_semana(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench = library["Supino reto"]
    # 30/11 (segunda) → 03/12: quatro dias seguidos, passando de mês.
    for day in ("2026-11-27", "2026-11-30", "2026-12-01", "2026-12-02", "2026-12-03"):
        _workout(client, auth_headers, day, _set(bench, 10, 50))

    def streak(date_to: str) -> int:
        return client.get(
            f"{STATS}/volume", params={"date_to": date_to}, headers=auth_headers
        ).json()["streak_days"]

    assert streak("2026-12-03") == 4
    # Ainda sem treino hoje: a sequência de ontem continua valendo.
    assert streak("2026-12-04") == 4
    # Dois dias sem treino: acabou.
    assert streak("2026-12-05") == 0
    # 29/11 (domingo) sem treino quebra a sequência que vinha de 27/11.
    assert streak("2026-11-30") == 1


def test_treinos_no_mes_contam_ate_date_to(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench = library["Supino reto"]
    for day in ("2026-10-31", "2026-11-01", "2026-11-10", "2026-11-25"):
        _workout(client, auth_headers, day, _set(bench, 10, 50))

    body = client.get(
        f"{STATS}/volume", params={"date_to": "2026-11-19"}, headers=auth_headers
    ).json()

    assert body["workouts_this_month"] == 2


def test_volume_recusa_agrupamento_desconhecido(
    client: TestClient, auth_headers: dict[str, str]
) -> None:
    response = client.get(f"{STATS}/volume", params={"group_by": "year"}, headers=auth_headers)

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# /stats/muscle-groups
# ---------------------------------------------------------------------------


def test_grupos_somam_volume_series_e_dias(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench, incline = library["Supino reto"], library["Supino inclinado"]
    row = library["Remada curvada"]
    _workout(client, auth_headers, "2026-11-10", _set(bench, 10, 60), _set(incline, 10, 40))
    _workout(client, auth_headers, "2026-11-10", _set(bench, 5, 80))  # mesmo dia
    _workout(client, auth_headers, "2026-11-12", _set(bench, 10, 60), _set(row, 10, 50))
    _workout(client, auth_headers, "2026-11-12", _set(row, 10, 30, "warmup"))

    body = client.get(
        f"{STATS}/muscle-groups",
        params={"date_from": "2026-11-01", "date_to": "2026-11-19"},
        headers=auth_headers,
    ).json()

    peito, costas = body[0], body[1]
    assert peito["muscle_group"] == "Peito"
    assert (peito["volume"], peito["sets"], peito["sessions"]) == (2000.0, 4, 2)
    assert costas["muscle_group"] == "Costas"
    assert (costas["volume"], costas["sets"], costas["sessions"]) == (500.0, 1, 1)


def test_grupos_traz_todos_os_grupos_zerados_em_ordem_alfabetica(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    body = client.get(f"{STATS}/muscle-groups", headers=auth_headers).json()

    names = [item["muscle_group"] for item in body]
    assert names == sorted(names)
    assert len(names) > 5
    assert all(item["volume"] == 0 and item["sessions"] == 0 for item in body)


def test_grupos_recusa_periodo_invertido(client: TestClient, auth_headers: dict[str, str]) -> None:
    response = client.get(
        f"{STATS}/muscle-groups",
        params={"date_from": "2026-11-19", "date_to": "2026-11-01"},
        headers=auth_headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "invalid_date_range"


# ---------------------------------------------------------------------------
# /stats/heatmap
# ---------------------------------------------------------------------------


def test_heatmap_tem_uma_celula_por_dia_e_grupo(
    client: TestClient, auth_headers: dict[str, str], library: dict[str, int]
) -> None:
    bench, squat = library["Supino reto"], library["Agachamento livre"]
    _workout(client, auth_headers, "2026-11-17", _set(bench, 10, 60), _set(squat, 5, 100))
    _workout(client, auth_headers, "2026-11-17", _set(bench, 10, 40))
    _workout(client, auth_headers, "2026-11-18", _set(squat, 10, 40, "warmup"))

    body = client.get(
        f"{STATS}/heatmap",
        params={"date_from": "2026-11-16", "date_to": "2026-11-19"},
        headers=auth_headers,
    ).json()

    assert body["date_from"] == "2026-11-16"
    assert body["date_to"] == "2026-11-19"
    assert [(c["date"], c["muscle_group"], c["volume"]) for c in body["cells"]] == [
        ("2026-11-17", "Peito", 1000.0),
        ("2026-11-17", "Quadríceps", 500.0),
    ]
    names = [g["name"] for g in body["muscle_groups"]]
    assert "Peito" in names and names == sorted(names)


def test_heatmap_isola_por_usuario(
    client: TestClient,
    auth_headers: dict[str, str],
    other_headers: dict[str, str],
    library: dict[str, int],
) -> None:
    _workout(client, other_headers, "2026-11-17", _set(library["Supino reto"], 10, 60))

    body = client.get(
        f"{STATS}/heatmap",
        params={"date_from": "2026-11-16", "date_to": "2026-11-19"},
        headers=auth_headers,
    ).json()

    assert body["cells"] == []


def test_heatmap_limita_periodo(client: TestClient, auth_headers: dict[str, str]) -> None:
    response = client.get(
        f"{STATS}/heatmap",
        params={"date_from": "2025-01-01", "date_to": "2026-11-19"},
        headers=auth_headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "date_range_too_long"


@pytest.mark.parametrize("path", ["/volume", "/muscle-groups", "/heatmap"])
def test_stats_exigem_login(client: TestClient, path: str) -> None:
    response = client.get(f"{STATS}{path}")

    assert response.status_code == 401
    assert set(response.json()) == {"detail", "code"}
