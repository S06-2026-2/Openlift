"""Testes dos endpoints base da API (Sprint 1).

Cobre os endpoints de infraestrutura e monitoramento:
- GET /health: conectividade com o banco de dados
- GET /version: versão e ambiente configurado
- GET /nonexistent: comportamento padrão para rotas não mapeadas
"""

from fastapi.testclient import TestClient


def test_health_returns_200_and_status_ok(client: TestClient) -> None:
    """GET /health deve verificar a conexão com o banco e retornar 200 com status ok."""
    # Act
    response = client.get("/health")

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data == {"status": "ok"}


def test_version_returns_app_version_and_environment(client: TestClient) -> None:
    """GET /version deve retornar a versão da API e o ambiente configurado."""
    # Act
    response = client.get("/version")

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["version"] == "0.1.0"
    assert data["env"] == "testing"


def test_unmapped_route_returns_404(client: TestClient) -> None:
    """Acesso a rota inexistente deve retornar 404 Not Found."""
    # Act
    response = client.get("/unmapped-endpoint")

    # Assert
    assert response.status_code == 404
