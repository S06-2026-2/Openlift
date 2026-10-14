"""Ponto de entrada da API FastAPI.

- /health (checa o Postgres) e /version;
- router da v1 em /api/v1 (auth; demais domínios entram nos próximos BEs);
- CORS para o app Flutter web (origem configurável via CORS_ORIGIN_REGEX);
- erros sempre no formato {"detail": "...", "code": "..."} (app/core/errors.py).
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.database import engine
from app.core.errors import register_exception_handlers

app = FastAPI(
    title="OpenLift API",
    version="0.1.0",
    description="API do OpenLift: identidade, treinos, histórico e agregações. "
    "Use **Authorize** com o `access_token` do `/api/v1/auth/login` para as rotas protegidas.",
    openapi_tags=[
        {"name": "auth", "description": "Cadastro, login e renovação de sessão (JWT)."},
        {"name": "system", "description": "Saúde e versão da API."},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=get_settings().cors_origin_regex,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

register_exception_handlers(app)


@app.get("/health", tags=["system"], summary="Saúde da API (checa o banco)")
def health() -> dict:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
    return {"status": "ok"}


@app.get("/version", tags=["system"], summary="Versão e ambiente")
def version() -> dict:
    return {"version": app.version, "env": get_settings().env}


app.include_router(api_router, prefix="/api/v1")

# TODO(Sprint 4): middleware de rate limiting (slowapi)
