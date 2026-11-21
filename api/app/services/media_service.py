"""Fotos da rede social (ADR-0012): valida, recodifica e salva.

Toda imagem é aberta pelo Pillow e salva de novo como WebP. Isso:
- confirma que o arquivo é mesmo JPEG, PNG ou WebP (não confia no
  Content-Type que o cliente manda);
- descarta o EXIF, inclusive a posição GPS (RNF-12), depois de aplicar a
  rotação que ele indicava;
- limita o lado maior a MAX_SIDE pixels.
"""

import hashlib
import io
import re
import uuid
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import ApiError
from app.domain.models.media import Media
from app.domain.models.user import User
from app.domain.schemas.media import MediaOut

MAX_UPLOAD_BYTES = 5 * 1024 * 1024
MAX_SIDE = 1600
MAX_PIXELS = 40_000_000  # barra "bomba de descompressão" antes de decodificar
ACCEPTED_FORMATS = {"JPEG", "PNG", "WEBP"}
OUTPUT_MIME = "image/webp"
FILENAME = re.compile(r"^[0-9a-f]{32}\.webp$")


def public_url(filename: str) -> str:
    return f"{get_settings().public_base_url.rstrip('/')}/media/{filename}"


def _unsupported() -> ApiError:
    return ApiError(415, "Envie uma foto em JPEG, PNG ou WebP.", "unsupported_media_type")


def _reencode(data: bytes) -> tuple[bytes, int, int]:
    try:
        with Image.open(io.BytesIO(data)) as probe:
            if probe.format not in ACCEPTED_FORMATS:
                raise _unsupported()
            if probe.width * probe.height > MAX_PIXELS:
                raise ApiError(422, "Essa foto tem resolução grande demais.", "image_too_large")
        with Image.open(io.BytesIO(data)) as source:
            # Aplica a rotação do EXIF antes de descartá-lo (sem EXIF, devolve a cópia).
            image = ImageOps.exif_transpose(source) or source.copy()
            # Metadados lidos do original (EXIF, XMP...) não seguem para o novo.
            image.info = {}
            image.thumbnail((MAX_SIDE, MAX_SIDE))
            if image.mode not in ("RGB", "RGBA"):
                image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
            output = io.BytesIO()
            # Sem `exif=`: o arquivo novo não carrega metadado nenhum.
            image.save(output, format="WEBP", quality=82, method=4)
            return output.getvalue(), image.width, image.height
    except ApiError:
        raise
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError) as exc:
        raise _unsupported() from exc


def save_upload(db: Session, user: User, data: bytes, media_dir: Path) -> MediaOut:
    if not data:
        raise ApiError(422, "O arquivo enviado está vazio.", "empty_file")
    if len(data) > MAX_UPLOAD_BYTES:
        raise ApiError(413, "A foto pode ter no máximo 5 MB.", "file_too_large")

    encoded, width, height = _reencode(data)
    digest = hashlib.sha256(encoded).hexdigest()
    filename = f"{uuid.uuid4().hex}.webp"

    media_dir.mkdir(parents=True, exist_ok=True)
    path = media_dir / filename
    path.write_bytes(encoded)

    media = Media(
        user_id=user.id,
        filename=filename,
        mime_type=OUTPUT_MIME,
        size_bytes=len(encoded),
        width=width,
        height=height,
        sha256=digest,
    )
    db.add(media)
    try:
        db.commit()
    except Exception:
        db.rollback()
        path.unlink(missing_ok=True)
        raise

    return MediaOut(
        url=public_url(filename),
        mime_type=OUTPUT_MIME,
        width=width,
        height=height,
        size_bytes=len(encoded),
        sha256=digest,
    )


def stored_file(filename: str, media_dir: Path) -> Path | None:
    """Caminho do arquivo pedido, ou `None` se o nome não é nosso ou não existe."""
    if not FILENAME.match(filename):
        return None
    path = media_dir / filename
    return path if path.is_file() else None
