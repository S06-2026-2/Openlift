"""Exemplo de referência — teste de autenticação (padrão ouro).

Este arquivo serve como template de estilo para a skill generate-tests.
O agente de IA deve seguir este padrão ao gerar novos testes.

Sprint 2 — gerados inicialmente pelo agente de IA, revisados por humano.
"""

import pytest


# ---------------------------------------------------------------------------
# Registro
# ---------------------------------------------------------------------------


def test_register_success(client):
    """Registrar um novo usuário retorna 201 com os dados do perfil."""
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": "novo@openlift.dev",
            "password": "SenhaForte123!",
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "novo@openlift.dev"
    assert "id" in data
    assert "hashed_password" not in data  # nunca expor hash


def test_register_email_already_exists_returns_409(client, db_session):
    """Registrar com e-mail duplicado retorna 409 Conflict."""
    # Arrange — cria o primeiro usuário
    client.post(
        "/api/v1/auth/register",
        json={"email": "dup@openlift.dev", "password": "Senha123!"},
    )

    # Act — tenta duplicar
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "dup@openlift.dev", "password": "OutraSenha1!"},
    )

    # Assert
    assert response.status_code == 409


def test_register_invalid_email_returns_422(client):
    """E-mail mal formatado deve ser rejeitado pelo Pydantic (422)."""
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "nao-e-email", "password": "Senha123!"},
    )
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------


def test_login_success_returns_token_pair(client):
    """Login com credenciais válidas retorna access e refresh tokens."""
    # Arrange
    client.post(
        "/api/v1/auth/register",
        json={"email": "login@openlift.dev", "password": "Senha123!"},
    )

    # Act
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "login@openlift.dev", "password": "Senha123!"},
    )

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_login_wrong_password_returns_401(client):
    """Senha incorreta retorna 401 Unauthorized."""
    client.post(
        "/api/v1/auth/register",
        json={"email": "wrong@openlift.dev", "password": "Correta123!"},
    )

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "wrong@openlift.dev", "password": "Errada999!"},
    )

    assert response.status_code == 401


def test_login_nonexistent_user_returns_401(client):
    """Tentativa de login com e-mail inexistente retorna 401."""
    response = client.post(
        "/api/v1/auth/login",
        json={"email": "fantasma@openlift.dev", "password": "Qualquer1!"},
    )
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# Identidade NOSTR
# ---------------------------------------------------------------------------


def test_register_nostr_identity(client, auth_headers):
    """Registrar npub com token válido retorna 201."""
    response = client.post(
        "/api/v1/me/nostr-identity",
        json={"npub": "npub1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz567"},
        headers=auth_headers,
    )
    assert response.status_code == 201


def test_register_duplicate_npub_returns_409(client, auth_headers):
    """npub já associado a outro usuário deve ser rejeitado."""
    npub = "npub1duplicated000000000000000000000000000000000000000000000"

    # Primeiro registro — sucesso
    client.post(
        "/api/v1/me/nostr-identity",
        json={"npub": npub},
        headers=auth_headers,
    )

    # Segundo registro (mesmo npub) — conflito
    response = client.post(
        "/api/v1/me/nostr-identity",
        json={"npub": npub},
        headers=auth_headers,
    )
    assert response.status_code == 409
