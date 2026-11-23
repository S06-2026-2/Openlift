"""Upload de fotos da rede social (ADR-0012). Rota fina: a regra fica em
app/services/media_service.py.

POST /media — envia uma foto (login obrigatório) → 201 | 401 | 413 | 415 | 422

A leitura pública (`GET /media/{arquivo}`) fica fora de /api/v1, em
app/main.py, para a URL da foto ser curta e servir em qualquer cliente NOSTR.
"""

from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, UploadFile, status

from app.api.deps import CurrentUser, DbSession
from app.api.responses import error_responses
from app.core.config import get_settings
from app.domain.schemas.media import MediaOut
from app.services import media_service

router = APIRouter()


def get_media_dir() -> Path:
    """Diretório das fotos (`MEDIA_DIR`). Override nos testes."""
    return Path(get_settings().media_dir)


MediaDir = Annotated[Path, Depends(get_media_dir)]


@router.post(
    "",
    response_model=MediaOut,
    status_code=status.HTTP_201_CREATED,
    summary="Enviar foto",
    description="Recebe JPEG, PNG ou WebP de até 5 MB no campo `file` (multipart). A foto "
    "é recodificada como WebP, sem EXIF (a posição GPS some — RNF-12), com o lado maior "
    f"limitado a {media_service.MAX_SIDE} px. A resposta traz a URL pública e os dados da "
    "tag `imeta` (NIP-92) para o app publicar o evento.",
    responses=error_responses(
        {
            401: "Não autenticado",
            413: "Arquivo maior que 5 MB (`file_too_large`)",
            415: "Não é JPEG, PNG nem WebP (`unsupported_media_type`)",
            422: "Arquivo vazio (`empty_file`) ou resolução grande demais (`image_too_large`)",
        }
    ),
)
def upload_media(
    db: DbSession,
    user: CurrentUser,
    media_dir: MediaDir,
    file: Annotated[UploadFile, File(description="A foto")],
) -> MediaOut:
    # Lê no máximo 5 MB + 1 byte: o suficiente para recusar o que passou.
    data = file.file.read(media_service.MAX_UPLOAD_BYTES + 1)
    return media_service.save_upload(db, user, data, media_dir)
