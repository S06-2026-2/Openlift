---
name: generate-tests
description: >-
  Use this skill when the user asks to generate, create, or write automated
  tests for the OpenLift backend. The skill reads source code changes (diffs
  or specific files) and generates Pytest test cases for the FastAPI API.
  It follows the project's test conventions, fixture patterns, and
  sprint-specific coverage goals defined in implementation.md.
---

# Generate Automated Tests for OpenLift Backend

## Project Context

OpenLift is a workout tracking app with NOSTR social features.
This skill covers **only the Python/FastAPI backend**.

| Component     | Stack                                              | Directory      |
|---------------|----------------------------------------------------|----------------|
| Backend       | Python 3.12, FastAPI, SQLAlchemy 2.0, Pydantic v2  | `api/app/`     |
| Tests         | `pytest` + `pytest-cov` + `httpx` (TestClient)     | `api/tests/`   |
| Config        | `pyproject.toml`                                    | `api/`         |

### Key Paths

- API routes: `api/app/api/v1/` (auth.py, workouts.py, stats.py, social.py)
- Services: `api/app/services/` (auth_service.py, workout_service.py, stats_service.py, ranking_service.py, nostr_sync_worker.py)
- Domain models: `api/app/domain/models/` (user.py, workout.py, set.py, nostr_identity.py, exercise.py, muscle_group.py, like.py, ranking.py, shared_event.py)
- Database: `api/app/core/database.py` (Base declarative, get_db dependency, engine)
- Settings: `api/app/core/config.py` (pydantic-settings: database_url, jwt_secret, redis_url, nostr_relays)
- Security: `api/app/core/security.py` (password hashing, JWT creation/validation)
- Pytest config: `api/pyproject.toml` (testpaths = ["tests"], coverage source = ["app"], omit main.py)

### Existing CI Pipelines

- **Backend CI** (`backend-ci.yml`): Ruff + Black + MyPy lint, then pytest with coverage (outputs `junit.xml` + `coverage.xml`)
- **CI Report Agent** (`ci-report-agent.yml`): Gemini-powered agent that reads CI artifacts and generates `CI_REPORT.md`

The tests you generate will be executed by these pipelines automatically.

---

## Step-by-Step Procedure

### Step 1 — Identify What to Test

1. Read the files the user indicates, or analyze the current diff/PR.
2. Map each changed source file to its corresponding test file:
   - `api/app/api/v1/auth.py` → `api/tests/test_auth.py`
   - `api/app/services/auth_service.py` → `api/tests/test_auth.py`
   - `api/app/api/v1/workouts.py` → `api/tests/test_workouts.py`
   - `api/app/services/workout_service.py` → `api/tests/test_workouts.py`
   - `api/app/api/v1/stats.py` → `api/tests/test_stats.py`
   - `api/app/services/stats_service.py` → `api/tests/test_stats.py`
   - `api/app/api/v1/social.py` → `api/tests/test_social.py`
   - `api/app/services/nostr_sync_worker.py` → `api/tests/test_social.py`
   - `api/app/services/ranking_service.py` → `api/tests/test_social.py`

### Step 2 — Read Existing Tests and Fixtures

1. Read the target test file to see what is already covered — **never duplicate tests**.
2. Read `api/tests/conftest.py` to learn available fixtures:
   - `db_session` — SQLAlchemy session on SQLite in-memory (creates/drops all tables per test)
   - `client` — `fastapi.testclient.TestClient` with `get_db` overridden to use the test session
   - `auth_headers` — dict `{"Authorization": "Bearer <token>"}` for a pre-created test user (`test@openlift.dev`)
3. If a needed fixture does not exist yet, **create it in `conftest.py`** before writing tests.

### Step 3 — Generate Tests

For each endpoint or service function, generate tests covering:

1. **Happy path** — the normal, expected behavior (2xx response)
2. **Edge cases / error cases**:
   - Invalid input: missing fields, wrong types → 422
   - Duplicate resources: email/npub already exists → 409
   - Unauthorized access: no token or invalid token → 401
   - Forbidden access: user accessing another user's resource → 403 or 404
   - Not found: resource does not exist → 404
   - Empty results: user with no workouts, zero stats (should return empty, not error)
   - Boundary values: very long strings, zero, negative numbers

#### Test Conventions

- **File names**: `test_<module>.py` (match existing: test_auth.py, test_workouts.py, test_stats.py, test_social.py)
- **Function names**: `test_<action>_<scenario>` (e.g., `test_register_email_already_exists_returns_409`)
- **Docstrings**: Every test file starts with a module docstring explaining what it tests and which sprint
- **Fixtures**: Always use fixtures from conftest.py — never instantiate TestClient or sessions inline
- **HTTP client**: Use `TestClient` (sync) for endpoint tests
- **Service tests**: Use plain function calls with `db_session` for unit testing services
- **Assertions**: Be specific — check status codes, response body keys, and values
- **Arrange-Act-Assert**: Structure tests clearly with comments when logic is non-trivial
- **No unittest**: Use plain pytest functions and fixtures, never `unittest.TestCase`

### Step 4 — Run and Validate

1. Run from the `api/` directory:
   ```bash
   pytest --tb=short -q
   ```
2. Check coverage against sprint goal:
   ```bash
   pytest --cov=app --cov-report=term-missing
   ```
3. All new tests **must pass**. If any fail, debug and fix before reporting.
4. Run tests **3 times** to confirm no flaky behavior.

### Step 5 — Report Results

After generating and validating, report:

- Number of new test cases created
- Which test files were created or modified
- Current coverage percentage vs. sprint goal
- Any modules that remain under-covered
- Any fixtures that were created or modified in conftest.py

---

## Coverage Goals by Sprint

| Sprint | Weeks | Goal | CI Gate      | Agent Focus                              |
|--------|-------|------|--------------|------------------------------------------|
| 1      | 1–2   | —    | informative  | Test structure and database fixtures      |
| 2      | 3–4   | 50%  | informative  | Auth and workout CRUD                     |
| 3      | 5–6   | 60%  | informative  | Aggregation/statistics endpoints          |
| 4      | 7–8   | 70%  | **blocking** | NOSTR worker, likes, and ranking          |
| 5      | 9–10  | 75%  | **blocking** | Heatmap + mutation testing spot-check     |
| 6      | 11–12 | 80%  | **blocking** | Final audit by module                     |

---

## Rules — What NOT To Do

- **Do NOT** generate tests that require a real database or network — always use SQLite in-memory and mocks
- **Do NOT** test third-party library internals (SQLAlchemy, FastAPI, Pydantic)
- **Do NOT** invent endpoints or service functions that don't exist in the source code — always read and verify first
- **Do NOT** exceed the current sprint scope — only test features that have been implemented
- **Do NOT** generate tests without docstrings — every test file needs a module docstring
- **Do NOT** use `unittest.TestCase` — use plain pytest functions and fixtures
- **Do NOT** hardcode database URLs or secrets in tests — use fixtures and env overrides
- **Do NOT** mock WebSocket with real relay URLs — use recorded fixtures
- **Do NOT** skip human review — all generated tests are proposals, the developer always reviews before merge

---

## Reference Material

For detailed patterns and fixture documentation, see:

- [fixture_catalog.md](./references/fixture_catalog.md) — Catalog of all shared pytest fixtures
- [mock_patterns.md](./references/mock_patterns.md) — Patterns for mocking NOSTR relays, time, and parametrized tests
- [example_test_auth.py](./examples/example_test_auth.py) — Reference implementation of auth tests (style template)
