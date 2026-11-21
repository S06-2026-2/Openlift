"""Configuração da aplicação via variáveis de ambiente (pydantic-settings).

Sprint 1: DATABASE_URL, ENV.
Sprint 2: JWT_SECRET, JWT_EXPIRATION_MINUTES.
Sprint 3: NOSTR_RELAYS (lista configurável, sem hardcode). Sem Redis (ADR-0011).
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Sprint 1
    database_url: str
    env: str = "development"

    # Sprint 2
    jwt_secret: str = "change-me"
    jwt_expiration_minutes: int = 30
    jwt_refresh_expiration_days: int = 7
    jwt_algorithm: str = "HS256"

    # BE-02 — origens liberadas no CORS (Flutter web em localhost:<porta qualquer>)
    cors_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    # Sprint 3 — relays NOSTR (ADR-0007); worker sem Redis (ADR-0011)
    nostr_relays: str | None = None
    # BE-08 — tempo máximo de espera por mensagem do relay e novas tentativas
    nostr_relay_timeout_seconds: float = 10.0
    nostr_relay_max_retries: int = 3
    # BE-09 — intervalo do worker de sincronização (ADR-0011)
    nostr_sync_interval_seconds: int = Field(default=300, ge=10)

    # ADR-0012 — URL pública da API: domínio do NIP-05 e base das URLs de foto
    public_base_url: str = "http://localhost:8000"

    @property
    def nostr_relay_urls(self) -> list[str]:
        """`NOSTR_RELAYS` (separados por vírgula) → lista sem vazios nem repetidos."""
        urls: list[str] = []
        for raw in (self.nostr_relays or "").split(","):
            url = raw.strip()
            if url and url not in urls:
                urls.append(url)
        return urls


@lru_cache
def get_settings() -> Settings:
    # Required settings are loaded from environment variables by BaseSettings
    return Settings()  # type: ignore[call-arg]
