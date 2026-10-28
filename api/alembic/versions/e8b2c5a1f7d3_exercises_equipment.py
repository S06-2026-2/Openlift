"""exercises: equipment (NIP-101e) para o modelo de exercício kind 33401

O evento `kind 33401` que o app publica exige a tag `equipment` (ADR-0003,
mini-NIP §3), no vocabulário do NIP-101e: barbell | dumbbell | bodyweight |
machine | cardio. Polia e cabo entram como `machine`.

Migração de dados: os 40 exercícios da biblioteca recebem o equipamento certo
aqui mesmo (cópia congelada da tabela do seed), então quem já tem o banco não
precisa rodar o seed de novo. Exercício fora da biblioteca, se existir, fica
como `machine` e pode ser corrigido depois.

Escrita à mão: o --autogenerate não cria a CHECK nem a migração de dados.

Revision ID: e8b2c5a1f7d3
Revises: d4f1a6c93b27
Create Date: 2026-10-28 15:00:00.000000

"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e8b2c5a1f7d3'
down_revision: str | None = 'd4f1a6c93b27'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_EQUIPMENT = {
    "Supino reto": "barbell",
    "Supino inclinado": "barbell",
    "Crucifixo com halteres": "dumbbell",
    "Flexão de braço": "bodyweight",
    "Puxada frontal": "machine",
    "Remada curvada": "barbell",
    "Remada baixa": "machine",
    "Barra fixa": "bodyweight",
    "Desenvolvimento com halteres": "dumbbell",
    "Elevação lateral": "dumbbell",
    "Elevação frontal": "dumbbell",
    "Crucifixo invertido": "dumbbell",
    "Rosca direta": "barbell",
    "Rosca alternada": "dumbbell",
    "Rosca martelo": "dumbbell",
    "Rosca Scott": "barbell",
    "Tríceps pulley": "machine",
    "Tríceps testa": "barbell",
    "Tríceps francês": "dumbbell",
    "Mergulho entre bancos": "bodyweight",
    "Agachamento livre": "barbell",
    "Leg press 45°": "machine",
    "Cadeira extensora": "machine",
    "Agachamento búlgaro": "dumbbell",
    "Levantamento terra romeno": "barbell",
    "Stiff": "barbell",
    "Mesa flexora": "machine",
    "Cadeira flexora": "machine",
    "Elevação pélvica": "barbell",
    "Afundo": "dumbbell",
    "Glúteo na polia": "machine",
    "Cadeira abdutora": "machine",
    "Panturrilha em pé": "machine",
    "Panturrilha sentado": "machine",
    "Panturrilha no leg press": "machine",
    "Panturrilha unilateral": "bodyweight",
    "Abdominal crunch": "bodyweight",
    "Prancha": "bodyweight",
    "Elevação de pernas": "bodyweight",
    "Abdominal na polia": "machine",
}


def upgrade() -> None:
    op.add_column('exercises', sa.Column('equipment', sa.String(length=16), nullable=True))
    exercises = sa.table('exercises', sa.column('name', sa.String), sa.column('equipment', sa.String))
    for name, equipment in _EQUIPMENT.items():
        op.execute(
            exercises.update().where(exercises.c.name == name).values(equipment=equipment)
        )
    op.execute(exercises.update().where(exercises.c.equipment.is_(None)).values(equipment='machine'))
    op.alter_column('exercises', 'equipment', existing_type=sa.String(length=16), nullable=False)
    op.create_check_constraint(
        'ck_exercises_equipment',
        'exercises',
        "equipment IN ('barbell', 'dumbbell', 'bodyweight', 'machine', 'cardio')",
    )


def downgrade() -> None:
    op.drop_constraint('ck_exercises_equipment', 'exercises', type_='check')
    op.drop_column('exercises', 'equipment')
