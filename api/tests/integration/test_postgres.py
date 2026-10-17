
"""Testes de integração utilizando PostgreSQL real."""

import os
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.domain.models.user import User


@pytest.fixture(scope="module")
def postgres_engine():
    url = os.environ.get("TEST_POSTGRES_URL")

    if not url:
        pytest.skip("PostgreSQL não configurado para os testes")

    if not url.startswith("postgresql+psycopg://"):
        pytest.fail("TEST_POSTGRES_URL deve utilizar PostgreSQL")

    engine = create_engine(url, pool_pre_ping=True)

    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            assert result.scalar_one() == 1

            table = connection.execute(
                text("SELECT to_regclass('public.users')")
            ).scalar_one()

            assert table == "users", "Execute alembic upgrade head"

        yield engine
    finally:
        engine.dispose()


@pytest.fixture()
def postgres_session(postgres_engine):
    with postgres_engine.connect() as connection:
        transaction = connection.begin()

        try:
            with Session(
                bind=connection,
                join_transaction_mode="create_savepoint",
            ) as session:
                yield session
        finally:
            transaction.rollback()


def test_postgres_persists_and_reads_user(postgres_session):
    email = f"integration-{uuid4().hex}@openlift.test"

    user = User(
        email=email,
        hashed_password="integration-test-hash",
    )

    postgres_session.add(user)
    postgres_session.commit()

    result = postgres_session.scalar(
        select(User).where(User.email == email)
    )

    assert result is not None
    assert result.id is not None
    assert result.email == email


def test_postgres_rejects_duplicate_email(postgres_session):
    email = f"integration-{uuid4().hex}@openlift.test"

    postgres_session.add(
        User(email=email, hashed_password="hash1")
    )
    postgres_session.commit()

    postgres_session.add(
        User(email=email, hashed_password="hash2")
    )

    with pytest.raises(IntegrityError):
        postgres_session.commit()

    postgres_session.rollback()
