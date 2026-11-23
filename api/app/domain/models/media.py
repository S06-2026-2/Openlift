"""Model `media` — fotos enviadas para a rede social (ADR-0012).

O arquivo fica em disco (`MEDIA_DIR`), com nome aleatório; aqui fica quem
enviou, o tipo, o tamanho, as dimensões e o SHA-256 (que vai na tag `imeta`
do evento, NIP-92). A imagem é sempre recodificada antes de salvar, o que
descarta o EXIF e a posição GPS (RNF-12).
"""

from datetime import datetime

from sqlalchemy import CHAR, DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Media(Base):
    __tablename__ = "media"
    __table_args__ = (UniqueConstraint("filename", name="uq_media_filename"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", name="fk_media_user_id_users", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    filename: Mapped[str] = mapped_column(String(64), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(32), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    width: Mapped[int] = mapped_column(Integer, nullable=False)
    height: Mapped[int] = mapped_column(Integer, nullable=False)
    sha256: Mapped[str] = mapped_column(CHAR(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
