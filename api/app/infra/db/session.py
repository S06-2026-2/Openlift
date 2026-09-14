"""Fábrica de sessões do SQLAlchemy, usada por app/core/database.py e pelos
testes (fixture de banco em tests/conftest.py)."""

from sqlalchemy.orm import sessionmaker

from app.core.database import engine

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
