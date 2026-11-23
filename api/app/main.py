"""Ponto de entrada da API FastAPI.

- /health (banco + worker de sincronização) e /version;
- logs estruturados em JSON e log de cada requisição (OPS-08, RNF-14);
- router da v1 em /api/v1 (auth; demais domínios entram nos próximos BEs);
- CORS para o app Flutter web (origem configurável via CORS_ORIGIN_REGEX);
- erros sempre no formato {"detail": "...", "code": "..."} (app/core/errors.py).
"""

from typing import Annotated

from fastapi import FastAPI, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.api.deps import DbSession
from app.api.v1.media import MediaDir
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import ApiError, register_exception_handlers
from app.core.logging import configure_logging
from app.core.middleware import RequestLoggingMiddleware
from app.services import media_service, profile_service, worker_status

configure_logging(get_settings().log_level)

app = FastAPI(
    title="OpenLift API",
    version="0.1.0",
    description="API do OpenLift: identidade, treinos, histórico e agregações. "
    "Use **Authorize** com o `access_token` do `/api/v1/auth/login` para as rotas protegidas.",
    openapi_tags=[
        {"name": "auth", "description": "Cadastro, login e renovação de sessão (JWT)."},
        {"name": "me", "description": "Dados do usuário logado, como a identidade NOSTR."},
        {"name": "exercises", "description": "Biblioteca de exercícios por grupo muscular."},
        {"name": "workouts", "description": "Treinos e séries do usuário logado."},
        {"name": "stats", "description": "Volume semanal, grupos musculares e mapa de calor."},
        {"name": "profiles", "description": "Perfis da rede social e busca por nome de usuário."},
        {"name": "nostr", "description": "Diretório NIP-05 dos nomes de usuário."},
        {"name": "media", "description": "Fotos da rede social (envio e leitura pública)."},
        {"name": "system", "description": "Saúde e versão da API."},
    ],
)

app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=get_settings().cors_origin_regex,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
)

register_exception_handlers(app)


@app.get(
    "/health",
    tags=["system"],
    summary="Saúde da API: banco e worker",
    description="`status` e `database` dizem se a API consegue falar com o Postgres "
    "(senão, 503 `database_unavailable`). `worker` mostra o último ciclo do worker de "
    "sincronização NOSTR: `ok` (sucesso nos últimos 3 intervalos), `stale` (rodou, mas "
    "sem sucesso recente) ou `unknown` (nunca rodou neste ambiente). O worker parado "
    "não derruba o `/health`: a API continua servindo.",
    responses={503: {"description": "Banco de dados indisponível"}},
)
def health(db: DbSession) -> dict:
    try:
        db.execute(text("SELECT 1"))
        worker = worker_status.worker_status(db, get_settings().nostr_sync_interval_seconds)
    except SQLAlchemyError as exc:
        raise ApiError(503, "Banco de dados indisponível.", "database_unavailable") from exc
    return {"status": "ok", "database": "ok", "worker": worker}


@app.get("/version", tags=["system"], summary="Versão e ambiente")
def version() -> dict:
    return {"version": app.version, "env": get_settings().env}


app.include_router(api_router, prefix="/api/v1")


@app.get(
    "/.well-known/nostr.json",
    tags=["nostr"],
    summary="Nomes verificados (NIP-05)",
    description="Liga `nome@domínio` à chave pública, no formato da NIP-05. Público e com "
    "CORS aberto, como a NIP-05 exige. Sem `name` (ou com nome inexistente), `names` vem "
    "vazio: o diretório não é listado inteiro.",
)
def nostr_json(
    response: Response,
    db: DbSession,
    name: Annotated[str | None, Query(max_length=40, description="Nome de usuário")] = None,
) -> dict:
    response.headers["Access-Control-Allow-Origin"] = "*"
    return {"names": profile_service.nip05_names(db, name)}


@app.get(
    "/media/{filename}",
    tags=["media"],
    summary="Ler foto",
    description="Foto enviada por `POST /api/v1/media`. Pública, como toda foto publicada "
    "na rede aberta (ADR-0012), e com cache longo: o nome do arquivo nunca é reutilizado.",
    response_class=FileResponse,
    responses={404: {"description": "Foto não encontrada"}},
)
def read_media(filename: str, media_dir: MediaDir) -> FileResponse:
    path = media_service.stored_file(filename, media_dir)
    if path is None:
        raise ApiError(404, "Foto não encontrada.", "media_not_found")
    return FileResponse(
        path,
        media_type=media_service.OUTPUT_MIME,
        headers={
            "Cache-Control": "public, max-age=31536000, immutable",
            "Access-Control-Allow-Origin": "*",
        },
    )
