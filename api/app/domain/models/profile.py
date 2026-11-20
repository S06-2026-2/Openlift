"""Model `profiles` — diretório de nomes de usuário da rede social (ADR-0012).

Cada conta tem no máximo um perfil, com `username` único (3 a 20 caracteres
`a-z`, `0-9`, `_` e `.`, sempre minúsculo). A API publica esse nome como
NIP-05 (`/.well-known/nostr.json`), e o app publica o mesmo perfil como
`kind 0` assinado: a tabela é o índice de unicidade e de busca, não a única
cópia do perfil.

Nada de interação social aqui (ADR-0004): curtidas e comentários vivem nos
relays.
"""

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_profiles_user_id"),
        CheckConstraint(
            "length(username) BETWEEN 3 AND 20 AND username = lower(username)",
            name="ck_profiles_username",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", name="fk_profiles_user_id_users", ondelete="CASCADE"),
        nullable=False,
    )
    username: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(160), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
