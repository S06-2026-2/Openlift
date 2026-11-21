"""Schemas Pydantic v2 das fotos enviadas (ADR-0012)."""

from pydantic import BaseModel, ConfigDict, Field


class MediaOut(BaseModel):
    """Foto salva: os campos batem com a tag `imeta` (NIP-92) do evento."""

    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "url": "https://api.openlift.dev/media/3f2c9a1e0b6d4c8f9a7e5d3c1b2a4f6e.webp",
                    "mime_type": "image/webp",
                    "width": 1600,
                    "height": 1200,
                    "size_bytes": 184233,
                    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                }
            ]
        }
    )

    url: str = Field(description="URL pública da foto")
    mime_type: str
    width: int = Field(gt=0)
    height: int = Field(gt=0)
    size_bytes: int = Field(gt=0)
    sha256: str = Field(description="SHA-256 do arquivo salvo, em hex (tag `x` da `imeta`)")
