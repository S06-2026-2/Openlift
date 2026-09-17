"""Testes de configuração e banco de dados do núcleo da aplicação (Sprint 1).

Cobre:
- app.core.config.Settings: carregamento, valores padrão e cache de get_settings
- app.core.database: registro de tabelas em Base.metadata e ciclo de vida de get_db
"""

from collections.abc import Generator

import pytest
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.database import Base, get_db

# ---------------------------------------------------------------------------
# Config / Settings
# ---------------------------------------------------------------------------


def test_settings_default_values(monkeypatch: pytest.MonkeyPatch) -> None:
    """Settings deve carregar valores padrão corretos para variáveis opcionais."""
    # Garante que ENV não venha herdado do ambiente de teste para testar o default do modelo
    monkeypatch.delenv("ENV", raising=False)

    # Arrange & Act
    settings = Settings(database_url="sqlite:///:memory:")

    # Assert
    assert settings.database_url == "sqlite:///:memory:"
    assert settings.env == "development"
    assert settings.jwt_secret == "change-me"
    assert settings.jwt_expiration_minutes == 30
    assert settings.redis_url is None
    assert settings.nostr_relays is None


def test_settings_custom_overrides() -> None:
    """Settings deve permitir a sobrescrita explícita de valores de configuração."""
    # Act
    settings = Settings(
        database_url="sqlite:///:memory:",
        env="production",
        jwt_secret="super-secret-key-123",
        jwt_expiration_minutes=60,
        redis_url="redis://localhost:6379/0",
        nostr_relays="wss://relay.damus.io",
    )

    # Assert
    assert settings.env == "production"
    assert settings.jwt_secret == "super-secret-key-123"
    assert settings.jwt_expiration_minutes == 60
    assert settings.redis_url == "redis://localhost:6379/0"
    assert settings.nostr_relays == "wss://relay.damus.io"


def test_get_settings_returns_cached_instance() -> None:
    """get_settings deve utilizar lru_cache retornando a mesma instância em chamadas sucessivas."""
    s1 = get_settings()
    s2 = get_settings()
    assert s1 is s2


# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------


def test_base_metadata_contains_domain_tables() -> None:
    """Base.metadata deve conter as 4 tabelas de domínio do Sprint 1 registradas."""
    table_names = set(Base.metadata.tables.keys())
    expected_tables = {"users", "workouts", "sets", "nostr_identities"}

    assert expected_tables.issubset(table_names)


def test_get_db_yields_session_and_closes() -> None:
    """get_db deve funcionar como gerador produzindo uma sessão SQLAlchemy válida."""
    db_gen = get_db()
    assert isinstance(db_gen, Generator)

    session = next(db_gen)
    assert isinstance(session, Session)

    # Avança o gerador para disparar o bloco finally (fechamento)
    try:
        next(db_gen)
    except StopIteration:
        pass
