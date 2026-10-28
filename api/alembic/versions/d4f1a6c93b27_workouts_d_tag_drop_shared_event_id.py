"""workouts: d_tag no lugar de shared_event_id

BE-S2-03 (publicação do treino):
- adiciona `workouts.d_tag` VARCHAR(36), a tag `d` (UUID v4) do kind 1301, fixa
  por treino e reutilizada nas republicações (RN-08), com unicidade por usuário;
- remove `workouts.shared_event_id`: um treino pode ter vários eventos (um por
  publicação), então o vínculo vive em `shared_events.workout_id`. A coluna nunca
  foi escrita por nenhuma rota, então não há dado a migrar.

Escrita à mão: o --autogenerate não nomeia a UNIQUE como o resto do projeto.
O downgrade recria `shared_event_id` vazia: o id dos eventos continua em
`shared_events`.

Revision ID: d4f1a6c93b27
Revises: 5c1e9a7d2f40
Create Date: 2026-10-27 20:30:00.000000

"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4f1a6c93b27'
down_revision: str | None = '5c1e9a7d2f40'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_UQ_NAME = 'uq_workouts_user_id_d_tag'


def upgrade() -> None:
    op.add_column('workouts', sa.Column('d_tag', sa.String(length=36), nullable=True))
    op.create_unique_constraint(_UQ_NAME, 'workouts', ['user_id', 'd_tag'])
    op.drop_column('workouts', 'shared_event_id')


def downgrade() -> None:
    op.add_column(
        'workouts', sa.Column('shared_event_id', sa.String(length=255), nullable=True)
    )
    op.drop_constraint(_UQ_NAME, 'workouts', type_='unique')
    op.drop_column('workouts', 'd_tag')
