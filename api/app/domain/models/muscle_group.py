"""Model `muscle_groups` — taxonomia usada no seletor de exercício, no
dashboard e no mapa de calor (ex.: Peito, Costas, Quadríceps...)."""

from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.domain.models.exercise import Exercise


class MuscleGroup(Base):
    __tablename__ = "muscle_groups"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)

    exercises: Mapped[list["Exercise"]] = relationship(back_populates="muscle_group")
