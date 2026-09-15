"""Configuração da aplicação via variáveis de ambiente (pydantic-settings).

Sprint 1: DATABASE_URL, ENV.
Sprint 2: JWT_SECRET, JWT_EXPIRATION_MINUTES.
Sprint 4: NOSTR_RELAYS (lista configurável, sem hardcode), REDIS_URL.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Sprint 1
    database_url: str
    env: str = "development"

    # Sprint 2
    jwt_secret: str = "change-me"
    jwt_expiration_minutes: int = 30

    # Sprint 4-5 — opcionais até os workers existirem
    redis_url: str | None = None
    nostr_relays: str | None = None


@lru_cache
def get_settings() -> Settings:
    # Required settings are loaded from environment variables by BaseSettings
    return Settings() # type: ignore[call-arg]
