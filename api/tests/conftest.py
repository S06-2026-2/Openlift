"""Fixtures compartilhadas dos testes de backend.

Preparado no Sprint 1 para já receber os testes gerados pelo agente de IA
a partir do Sprint 2 em diante (ver implementation.md, seção "Plano de
qualidade com IA").

Fixtures disponíveis:
    db_session   — sessão SQLAlchemy sobre SQLite in-memory (Sprint 1)
    client       — httpx TestClient com get_db sobrescrito (Sprint 1)
    auth_headers — headers de autenticação JWT para usuário de teste (Sprint 2)
"""

import os
import sys
from collections.abc import Generator
from datetime import UTC, datetime, timedelta
from pathlib import Path

# Garante que a raiz do backend (onde fica a pasta app) está no sys.path
api_root = str(Path(__file__).resolve().parent.parent)
if api_root not in sys.path:
    sys.path.insert(0, api_root)

# Garante que o DATABASE_URL aponta para SQLite de teste ANTES de qualquer
# import da aplicação (evita que o engine de produção tente conectar ao Postgres).
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("ENV", "testing")

import jwt as pyjwt  # noqa: E402
import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, event  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.database import Base, get_db  # noqa: E402

# Importa todos os models para que Base.metadata conheça as tabelas.
from app.domain import models as _models  # noqa: F401, E402
from app.main import app  # noqa: E402

# ---------------------------------------------------------------------------
# Banco de teste (SQLite in-memory)
# ---------------------------------------------------------------------------

TEST_DATABASE_URL = "sqlite:///:memory:"

test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)


# Habilita suporte a FK no SQLite (desligado por padrão).
@event.listens_for(test_engine, "connect")
def _set_sqlite_pragma(dbapi_conn, connection_record):
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


TestSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=test_engine,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def db_session() -> Generator[Session, None, None]:
    """Cria todas as tabelas, abre uma sessão limpa e derruba tudo ao final."""
    Base.metadata.create_all(bind=test_engine)
    session = TestSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=test_engine)


@pytest.fixture()
def client(db_session: Session) -> Generator[TestClient, None, None]:
    """TestClient do FastAPI com get_db sobrescrito para usar o db_session de teste."""

    def _override_get_db() -> Generator[Session, None, None]:
        try:
            yield db_session
        finally:
            pass  # sessão é gerenciada pela fixture db_session

    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as tc:
        yield tc
    app.dependency_overrides.clear()


@pytest.fixture()
def auth_headers(db_session: Session) -> dict[str, str]:
    """Cria um usuário de teste e retorna headers com JWT válido.

    Usuário: test@openlift.dev / testpassword123
    O token é gerado manualmente com PyJWT usando o jwt_secret do Settings,
    sem depender de endpoints de auth que podem não existir ainda.
    """
    from app.domain.models.user import User

    # Cria o usuário de teste direto no banco
    test_user = User(
        email="test@openlift.dev",
        hashed_password="$2b$12$fakehashfortestingonly000000000000000000000000000",
    )
    db_session.add(test_user)
    db_session.commit()
    db_session.refresh(test_user)

    # Gera um JWT válido
    settings = get_settings()
    payload = {
        "sub": str(test_user.id),
        "exp": datetime.now(UTC) + timedelta(minutes=settings.jwt_expiration_minutes),
    }
    token = pyjwt.encode(payload, settings.jwt_secret, algorithm="HS256")

    return {"Authorization": f"Bearer {token}"}
