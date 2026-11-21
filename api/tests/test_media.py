"""Fotos da rede social (ADR-0012): upload validado e recodificado sem EXIF
(RNF-12: a posição GPS não pode sair do servidor) e leitura pública."""

import hashlib
import io
from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.v1.media import get_media_dir
from app.domain.models.media import Media
from app.main import app

UPLOAD = "/api/v1/media"
GPS_IFD = 0x8825


@pytest.fixture()
def media_dir(tmp_path: Path) -> Generator[Path, None, None]:
    app.dependency_overrides[get_media_dir] = lambda: tmp_path
    yield tmp_path
    app.dependency_overrides.pop(get_media_dir, None)


def _image(fmt: str = "JPEG", size: tuple[int, int] = (800, 600), gps: bool = False) -> bytes:
    image = Image.new("RGB", size, (255, 106, 43))
    output = io.BytesIO()
    kwargs = {}
    if gps:
        exif = Image.Exif()
        exif[0x010F] = "Celular de teste"  # Make
        exif[GPS_IFD] = {1: "S", 2: (22.0, 54.0, 30.0)}  # latitude
        kwargs["exif"] = exif.tobytes()
    image.save(output, format=fmt, **kwargs)
    return output.getvalue()


def _upload(client: TestClient, headers: dict, data: bytes, name: str = "foto.jpg"):
    return client.post(UPLOAD, files={"file": (name, data, "image/jpeg")}, headers=headers)


def test_upload_recodifica_em_webp_e_responde_imeta(
    client: TestClient, auth_headers: dict, media_dir: Path, db_session: Session
) -> None:
    response = _upload(client, auth_headers, _image())

    assert response.status_code == 201
    body = response.json()
    assert body["mime_type"] == "image/webp"
    assert (body["width"], body["height"]) == (800, 600)
    assert body["url"].startswith("http://localhost:8000/media/")
    filename = body["url"].rsplit("/", 1)[1]
    stored = (media_dir / filename).read_bytes()
    assert hashlib.sha256(stored).hexdigest() == body["sha256"]
    assert body["size_bytes"] == len(stored)
    media = db_session.scalar(select(Media))
    assert media is not None and media.filename == filename


def test_upload_remove_exif_e_gps(client: TestClient, auth_headers: dict, media_dir: Path) -> None:
    original = _image(gps=True)
    assert Image.open(io.BytesIO(original)).getexif().get_ifd(GPS_IFD)  # tinha GPS

    body = _upload(client, auth_headers, original).json()

    stored = Image.open(media_dir / body["url"].rsplit("/", 1)[1])
    assert dict(stored.getexif()) == {}
    assert not stored.getexif().get_ifd(GPS_IFD)


def test_upload_reduz_o_lado_maior(client: TestClient, auth_headers: dict, media_dir: Path) -> None:
    body = _upload(client, auth_headers, _image("PNG", size=(3200, 1600))).json()

    assert (body["width"], body["height"]) == (1600, 800)


def test_aceita_png_e_webp(client: TestClient, auth_headers: dict, media_dir: Path) -> None:
    assert _upload(client, auth_headers, _image("PNG")).status_code == 201
    assert _upload(client, auth_headers, _image("WEBP")).status_code == 201


def test_recusa_arquivo_que_nao_e_foto(
    client: TestClient, auth_headers: dict, media_dir: Path
) -> None:
    response = _upload(client, auth_headers, b"<script>alert(1)</script>", name="foto.jpg")

    assert response.status_code == 415
    assert response.json()["code"] == "unsupported_media_type"
    assert list(media_dir.iterdir()) == []


def test_recusa_gif(client: TestClient, auth_headers: dict, media_dir: Path) -> None:
    response = _upload(client, auth_headers, _image("GIF"))

    assert response.status_code == 415


def test_recusa_mais_de_5_mb(client: TestClient, auth_headers: dict, media_dir: Path) -> None:
    response = _upload(client, auth_headers, b"\xff" * (5 * 1024 * 1024 + 1))

    assert response.status_code == 413
    assert response.json()["code"] == "file_too_large"


def test_recusa_arquivo_vazio(client: TestClient, auth_headers: dict, media_dir: Path) -> None:
    response = _upload(client, auth_headers, b"")

    assert response.status_code == 422
    assert response.json()["code"] == "empty_file"


def test_upload_exige_login(client: TestClient, media_dir: Path) -> None:
    response = client.post(UPLOAD, files={"file": ("f.jpg", _image(), "image/jpeg")})

    assert response.status_code == 401


def test_foto_e_publica_com_cache_longo(
    client: TestClient, auth_headers: dict, media_dir: Path
) -> None:
    body = _upload(client, auth_headers, _image()).json()

    response = client.get(f"/media/{body['url'].rsplit('/', 1)[1]}")

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/webp"
    assert "immutable" in response.headers["cache-control"]
    assert hashlib.sha256(response.content).hexdigest() == body["sha256"]


@pytest.mark.parametrize("name", ["nao-existe.webp", "../app/main.py", "a" * 32 + ".webp"])
def test_foto_inexistente_ou_nome_estranho_da_404(
    client: TestClient, media_dir: Path, name: str
) -> None:
    response = client.get(f"/media/{name}")

    assert response.status_code == 404
