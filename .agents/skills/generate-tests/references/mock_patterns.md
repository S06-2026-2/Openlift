# Mock Patterns — OpenLift Backend Tests

Patterns for mocking external services and dependencies in OpenLift tests.

---

## Pattern 1: Override FastAPI Dependencies

Use `app.dependency_overrides` to replace real dependencies with test doubles.
This is how the `client` fixture works internally.

```python
from app.main import app
from app.core.database import get_db

def override_get_db():
    """Yield the test session instead of the production Postgres session."""
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
```

---

## Pattern 2: Mock NOSTR Relay WebSocket (Sprint 4+)

The `nostr_sync_worker` connects to relays via WebSocket. In tests, mock the
connection to return pre-recorded responses instead of hitting real relays.

```python
import json
from unittest.mock import AsyncMock, patch

import pytest


@pytest.fixture
def mock_relay():
    """Simulates a NOSTR relay returning a reaction event (NIP-25 kind 7)."""
    mock_ws = AsyncMock()
    mock_ws.recv.side_effect = [
        json.dumps(["EVENT", "sub1", {
            "id": "abc123",
            "kind": 7,
            "content": "+",
            "tags": [["e", "target_event_id"]],
            "pubkey": "sender_npub",
            "created_at": 1700000000,
            "sig": "fake_sig",
        }]),
        # EOSE = End of Stored Events
        json.dumps(["EOSE", "sub1"]),
    ]
    return mock_ws


async def test_sync_worker_processes_reactions(db_session, mock_relay):
    with patch("app.services.nostr_sync_worker.connect_to_relay", return_value=mock_relay):
        await process_relay_events(db_session)

    likes = db_session.query(Like).all()
    assert len(likes) == 1
    assert likes[0].event_id == "target_event_id"
```

---

## Pattern 3: Time-dependent Tests (Sprint 4–5)

For ranking score decay and heatmap date ranges, freeze time using
`freezegun` or `pytest-freezegun`:

```python
from freezegun import freeze_time


@freeze_time("2025-06-15 12:00:00")
def test_ranking_score_decays_with_time(db_session):
    """Likes from 30 days ago should have lower weight than recent ones."""
    # ... test implementation
```

> Note: `freezegun` is not in requirements.txt yet. Add it when Sprint 4 begins.

---

## Pattern 4: Parametrized Edge Cases (Sprint 3–5)

Use `@pytest.mark.parametrize` for boundary testing on stats and heatmap:

```python
import pytest


@pytest.mark.parametrize("timezone,expected_count", [
    ("UTC", 5),
    ("America/Sao_Paulo", 5),
    ("Asia/Tokyo", 4),  # date boundary shifts one workout to previous day
])
def test_heatmap_respects_timezone(client, auth_headers, timezone, expected_count):
    response = client.get(
        "/api/v1/stats/heatmap",
        params={"tz": timezone},
        headers=auth_headers,
    )
    assert len(response.json()["cells"]) == expected_count


@pytest.mark.parametrize("group_by", ["week", "month", "day"])
def test_volume_stats_supports_group_by(client, auth_headers, group_by):
    response = client.get(
        "/api/v1/stats/volume",
        params={"groupBy": group_by},
        headers=auth_headers,
    )
    assert response.status_code == 200
```

---

## Pattern 5: Empty State Tests (Sprint 2–3)

Always test that endpoints return clean empty responses (not errors)
when the user has no data:

```python
def test_user_with_no_workouts_returns_empty_list(client, auth_headers):
    """A new user with no workouts should get an empty list, not an error."""
    response = client.get("/api/v1/workouts", headers=auth_headers)
    assert response.status_code == 200
    assert response.json() == []


def test_stats_for_user_without_data_returns_zeros(client, auth_headers):
    """Stats for a user with no workouts should return zeroed values."""
    response = client.get("/api/v1/stats/volume", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total_volume"] == 0
```
