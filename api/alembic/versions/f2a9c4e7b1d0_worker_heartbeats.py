"""worker_heartbeats: último ciclo do worker para o /health (OPS-08)

Revision ID: f2a9c4e7b1d0
Revises: 4d3e6c347a8d
Create Date: 2026-11-22 12:00:00

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "f2a9c4e7b1d0"
down_revision: str | None = "4d3e6c347a8d"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "worker_heartbeats",
        sa.Column("name", sa.String(length=64), nullable=False),
        sa.Column("last_run_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_success_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("name", name="pk_worker_heartbeats"),
    )


def downgrade() -> None:
    op.drop_table("worker_heartbeats")
