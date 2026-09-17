# Fixture Catalog — OpenLift Backend Tests

This document catalogs all shared pytest fixtures that should be available
in `api/tests/conftest.py`. The AI agent should read this before generating
tests to know what fixtures exist and how to use them.

---

## `db_session` (Sprint 1)

**Purpose**: Provides a clean SQLAlchemy `Session` on an in-memory SQLite database.
All tables are created before each test and dropped after.

**Usage**:
```python
def test_create_user(db_session):
    user = User(email="test@example.com", hashed_password="hashed")
    db_session.add(user)
    db_session.commit()
    assert user.id is not None
```

**Implementation notes**:
- Uses `sqlite:///:memory:` — never connects to Postgres in tests
- Creates all tables from `Base.metadata.create_all(engine)`
- Each test gets a fresh, isolated session
- The `Base` class is imported from `app.core.database`

---

## `client` (Sprint 1)

**Purpose**: An `httpx.TestClient` wrapping the FastAPI `app` with
the `get_db` dependency overridden to use the test `db_session`.

**Usage**:
```python
def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
```

**Implementation notes**:
- Overrides `app.core.database.get_db` so all endpoints use the SQLite test session
- Depends on the `db_session` fixture internally
- Uses `httpx.TestClient` (sync) — import from `fastapi.testclient` or `httpx`

---

## `auth_headers` (Sprint 2)

**Purpose**: Returns `{"Authorization": "Bearer <token>"}` for a pre-created test user.
Use this for testing authenticated endpoints without manual user creation.

**Usage**:
```python
def test_create_workout_authenticated(client, auth_headers):
    response = client.post(
        "/api/v1/workouts",
        json={"title": "Leg Day", "exercises": []},
        headers=auth_headers,
    )
    assert response.status_code == 201
```

**Implementation notes**:
- Creates a test user (`test@openlift.dev` / `testpassword123`) in the db_session
- Generates a valid JWT using `app.core.security` utilities
- Depends on `db_session` and `client` fixtures
- The user is created fresh for each test that uses this fixture

---

## `sample_workout` (Sprint 2+)

**Purpose**: Creates and returns a `Workout` with `WorkoutSet` entries persisted
in the test database. Useful for GET/PATCH/DELETE tests.

**Usage**:
```python
def test_get_workout_by_id(client, auth_headers, sample_workout):
    response = client.get(
        f"/api/v1/workouts/{sample_workout.id}",
        headers=auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["id"] == sample_workout.id
```

**Implementation notes**:
- Depends on `db_session` and the authenticated test user
- Contains realistic data: exercises, sets with reps/weight/RPE

---

## Future Fixtures (Sprint 4+)

These will be needed when implementing social features:

| Fixture | Sprint | Purpose |
|---------|--------|---------|
| `mock_relay_responses` | 4 | Pre-recorded WebSocket messages simulating NOSTR relay (NIP-01, NIP-25) |
| `sample_shared_event` | 4 | A `SharedEvent` linked to a workout and a NOSTR event ID |
| `sample_likes` | 4 | A set of `Like` entries for ranking/score tests |
| `redis_mock` | 5 | Mock Redis client for cache-dependent tests (heatmap) |
