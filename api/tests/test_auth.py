"""BE-02 — Testes de auth (register/login/refresh), get_current_user, CORS,
formato de erro e documentação OpenAPI."""

from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, get_db
from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.domain.models.user import User

REGISTER = "/api/v1/auth/register"
LOGIN = "/api/v1/auth/login"
REFRESH = "/api/v1/auth/refresh"


EMAIL = "ana@openlift.dev"
PASSWORD = "senha-segura-123"


def _register(client: TestClient, email: str = EMAIL, password: str = PASSWORD):
    return client.post(REGISTER, json={"email": email, "password": password})


def _login(client: TestClient, email: str = EMAIL, password: str = PASSWORD):
    return client.post(LOGIN, json={"email": email, "password": password})


def _expired_token(user_id: int, token_type: str) -> str:
    settings = get_settings()
    past = datetime.now(UTC) - timedelta(hours=2)
    payload = {
        "sub": str(user_id),
        "type": token_type,
        "iat": past,
        "exp": past + timedelta(minutes=1),
        "jti": "expired",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


# ---------------------------------------------------------------------------
# register
# ---------------------------------------------------------------------------


def test_register_returns_201_and_public_user(client: TestClient) -> None:
    response = _register(client)

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "ana@openlift.dev"
    assert isinstance(body["id"], int)
    assert body["npub"] is None
    assert "created_at" in body
    assert "password" not in body and "hashed_password" not in body


def test_register_stores_only_the_password_hash(client: TestClient, db_session: Session) -> None:
    _register(client, password="senha-segura-123")

    user = db_session.scalar(select(User).where(User.email == "ana@openlift.dev"))
    assert user is not None
    assert user.hashed_password != "senha-segura-123"
    assert user.hashed_password.startswith("$2")


def test_register_duplicate_email_returns_409(client: TestClient) -> None:
    assert _register(client).status_code == 201

    response = _register(client, email="ANA@OpenLift.dev")

    assert response.status_code == 409
    assert response.json() == {
        "detail": "Este e-mail já está cadastrado.",
        "code": "email_already_registered",
    }


@pytest.mark.parametrize(
    ("payload", "field"),
    [
        ({"email": "nao-e-email", "password": "senha-segura-123"}, "email"),
        ({"email": "ana@openlift.dev", "password": "curta"}, "password"),
        ({"password": "senha-segura-123"}, "email"),
    ],
)
def test_register_invalid_payload_returns_422_in_standard_format(
    client: TestClient, payload: dict, field: str
) -> None:
    response = client.post(REGISTER, json=payload)

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "validation_error"
    assert isinstance(body["detail"], str)
    assert any(err["field"] == field for err in body["errors"])


# ---------------------------------------------------------------------------
# login
# ---------------------------------------------------------------------------


def test_login_returns_token_pair(client: TestClient) -> None:
    user_id = _register(client).json()["id"]

    response = _login(client)

    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert decode_token(body["access_token"], "access")["sub"] == str(user_id)
    assert decode_token(body["refresh_token"], "refresh")["sub"] == str(user_id)


def test_login_is_case_insensitive_on_email(client: TestClient) -> None:
    _register(client)

    assert _login(client, email="Ana@OPENLIFT.dev").status_code == 200


def test_login_wrong_password_returns_401(client: TestClient) -> None:
    _register(client)

    response = _login(client, password="senha-errada-999")

    assert response.status_code == 401
    assert response.json() == {
        "detail": "E-mail ou senha incorretos.",
        "code": "invalid_credentials",
    }


def test_login_unknown_email_returns_same_401(client: TestClient) -> None:
    response = _login(client, email="ninguem@openlift.dev")

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_credentials"


# ---------------------------------------------------------------------------
# refresh
# ---------------------------------------------------------------------------


def test_refresh_returns_new_valid_pair(client: TestClient) -> None:
    _register(client)
    tokens = _login(client).json()

    response = client.post(REFRESH, json={"refresh_token": tokens["refresh_token"]})

    assert response.status_code == 200
    new = response.json()
    assert new["access_token"] != tokens["access_token"]
    assert new["refresh_token"] != tokens["refresh_token"]
    assert decode_token(new["access_token"], "access")["type"] == "access"


def test_refresh_rejects_access_token(client: TestClient) -> None:
    _register(client)
    tokens = _login(client).json()

    response = client.post(REFRESH, json={"refresh_token": tokens["access_token"]})

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


def test_refresh_rejects_garbage(client: TestClient) -> None:
    response = client.post(REFRESH, json={"refresh_token": "nao-e-um-jwt"})

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


def test_refresh_expired_returns_token_expired(client: TestClient) -> None:
    user_id = _register(client).json()["id"]

    response = client.post(REFRESH, json={"refresh_token": _expired_token(user_id, "refresh")})

    assert response.status_code == 401
    assert response.json()["code"] == "token_expired"


def test_refresh_for_deleted_user_returns_401(client: TestClient, db_session: Session) -> None:
    user_id = _register(client).json()["id"]
    refresh_token = create_refresh_token(user_id)
    db_session.delete(db_session.get(User, user_id))
    db_session.commit()

    response = client.post(REFRESH, json={"refresh_token": refresh_token})

    assert response.status_code == 401


# ---------------------------------------------------------------------------
# get_current_user (deps.py)
# ---------------------------------------------------------------------------


@pytest.fixture()
def protected_client(db_session: Session):
    """App mínimo com uma rota protegida, para testar get_current_user isolado."""
    test_app = FastAPI()
    register_exception_handlers(test_app)

    @test_app.get("/whoami")
    def whoami(user: CurrentUser) -> dict:
        return {"id": user.id, "email": user.email}

    test_app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(test_app) as tc:
        yield tc


def test_current_user_with_valid_access_token(protected_client: TestClient, auth_user) -> None:
    response = protected_client.get(
        "/whoami", headers={"Authorization": f"Bearer {create_access_token(auth_user.id)}"}
    )

    assert response.status_code == 200
    assert response.json() == {"id": auth_user.id, "email": "test@openlift.dev"}


def test_current_user_with_auth_headers_fixture(protected_client: TestClient, auth_headers) -> None:
    assert protected_client.get("/whoami", headers=auth_headers).status_code == 200


def test_current_user_without_token_returns_401(protected_client: TestClient) -> None:
    response = protected_client.get("/whoami")

    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_current_user_rejects_refresh_token(protected_client: TestClient, auth_user) -> None:
    response = protected_client.get(
        "/whoami", headers={"Authorization": f"Bearer {create_refresh_token(auth_user.id)}"}
    )

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


def test_current_user_expired_token(protected_client: TestClient, auth_user) -> None:
    response = protected_client.get(
        "/whoami", headers={"Authorization": f"Bearer {_expired_token(auth_user.id, 'access')}"}
    )

    assert response.status_code == 401
    assert response.json()["code"] == "token_expired"


def test_current_user_unknown_user(protected_client: TestClient) -> None:
    response = protected_client.get(
        "/whoami", headers={"Authorization": f"Bearer {create_access_token(9999)}"}
    )

    assert response.status_code == 401
    assert response.json()["code"] == "invalid_token"


# ---------------------------------------------------------------------------
# CORS, formato de erro e OpenAPI
# ---------------------------------------------------------------------------


def test_cors_allows_flutter_web_on_localhost(client: TestClient) -> None:
    response = client.options(
        LOGIN,
        headers={
            "Origin": "http://localhost:5959",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type,authorization",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5959"


def test_cors_blocks_unknown_origin(client: TestClient) -> None:
    response = client.options(
        LOGIN,
        headers={"Origin": "https://site-malicioso.com", "Access-Control-Request-Method": "POST"},
    )

    assert "access-control-allow-origin" not in response.headers


def test_unknown_route_uses_standard_error_format(client: TestClient) -> None:
    response = client.get("/api/v1/nao-existe")

    assert response.status_code == 404
    assert response.json() == {"detail": "Recurso não encontrado.", "code": "not_found"}


def test_openapi_lists_auth_routes_with_examples(client: TestClient) -> None:
    schema = client.get("/openapi.json").json()

    for path in (REGISTER, LOGIN, REFRESH):
        assert path in schema["paths"]
    assert schema["paths"][REGISTER]["post"]["summary"] == "Cadastro de usuário"
    assert "409" in schema["paths"][REGISTER]["post"]["responses"]
    components = schema["components"]["schemas"]
    assert components["RegisterRequest"]["examples"]
    assert components["TokenPair"]["examples"]
