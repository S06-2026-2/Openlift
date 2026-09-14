"""Engine e Base declarativa do SQLAlchemy 2.0 (Postgres).

Os models em app/domain/models herdam de `Base`. A sessão de fato (usada
pelos endpoints via `get_db`) é montada em app/infra/db/session.py.
"""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session

from app.core.config import get_settings

engine = create_engine(get_settings().database_url, pool_pre_ping=True)


class Base(DeclarativeBase):
    pass


def get_db() -> Generator[Session, None, None]:
    """Dependency do FastAPI: abre uma sessão por request e garante o fechamento."""
    from app.infra.db.session import SessionLocal

    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
