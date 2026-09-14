"""Ponto de entrada da API FastAPI.

Sprint 1: cria a app, expõe /health (checando o Postgres) e /version.
Sprint 2+: inclui o router agregado de app.api.v1 (auth, workouts, stats, social).
"""

from fastapi import FastAPI
from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import engine

app = FastAPI(title="OpenLift API", version="0.1.0")


@app.get("/health")
def health() -> dict:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
    return {"status": "ok"}


@app.get("/version")
def version() -> dict:
    return {"version": app.version, "env": get_settings().env}


# TODO(Sprint 2): app.include_router(api_router, prefix="/api/v1")
# TODO(Sprint 4): middleware de rate limiting (slowapi)
