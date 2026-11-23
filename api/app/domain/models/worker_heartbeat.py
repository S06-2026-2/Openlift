"""Model `worker_heartbeats` — último ciclo de cada processo em segundo plano
(OPS-08). O worker grava aqui a cada ciclo; o `/health` da API lê, já que os
dois rodam em containers diferentes e só têm o Postgres em comum (ADR-0011).

Uma linha por worker (`name`), sobrescrita a cada ciclo: não é histórico.
"""

from datetime import datetime

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class WorkerHeartbeat(Base):
    __tablename__ = "worker_heartbeats"

    name: Mapped[str] = mapped_column(String(64), primary_key=True)
    last_run_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_success_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Só o tipo da exceção: a mensagem pode carregar dado de usuário.
    last_error: Mapped[str | None] = mapped_column(Text)
