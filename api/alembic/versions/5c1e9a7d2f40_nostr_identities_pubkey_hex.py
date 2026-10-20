"""nostr_identities: pubkey_hex e FK com nome explícito

- adiciona `pubkey_hex` CHAR(64) UNIQUE NOT NULL, a chave pública em hex como
  aparece nos eventos NOSTR;
- backfill: deriva o hex do `npub` de cada linha existente com o mesmo
  decodificador NIP-19 da API (app/core/nostr.py). Se alguma linha tiver npub
  inválido, a migration para e nada muda (é melhor corrigir à mão do que
  apagar a identidade de alguém);
- troca a FK `user_id -> users.id`, criada sem nome na migration inicial
  (nome automático do Postgres), por `fk_nostr_identities_user_id_users`.

Escrita à mão: o --autogenerate não faz backfill nem renomeia constraint.

Revision ID: 5c1e9a7d2f40
Revises: b7a5b0094d26
Create Date: 2026-10-19 12:00:00.000000

"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

from app.core.nostr import npub_to_hex


# revision identifiers, used by Alembic.
revision: str = '5c1e9a7d2f40'
down_revision: str | None = 'b7a5b0094d26'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Nome que o Postgres deu à FK sem nome da migration 3424377aff1c.
_AUTO_FK_NAME = 'nostr_identities_user_id_fkey'
_FK_NAME = 'fk_nostr_identities_user_id_users'
_UQ_NAME = 'uq_nostr_identities_pubkey_hex'


def upgrade() -> None:
    op.add_column('nostr_identities', sa.Column('pubkey_hex', sa.CHAR(length=64), nullable=True))

    identities = sa.table(
        'nostr_identities',
        sa.column('id', sa.Integer),
        sa.column('npub', sa.String),
        sa.column('pubkey_hex', sa.CHAR),
    )
    bind = op.get_bind()
    rows = bind.execute(sa.select(identities.c.id, identities.c.npub)).all()
    invalid = []
    for identity_id, npub in rows:
        try:
            pubkey_hex = npub_to_hex(npub)
        except ValueError:
            invalid.append(identity_id)
            continue
        bind.execute(
            identities.update()
            .where(identities.c.id == identity_id)
            .values(pubkey_hex=pubkey_hex)
        )
    if invalid:
        ids = ', '.join(str(i) for i in invalid)
        raise RuntimeError(
            f'nostr_identities com npub inválido (ids: {ids}). Corrija ou remova essas '
            'linhas antes de rodar a migration.'
        )

    op.alter_column('nostr_identities', 'pubkey_hex', nullable=False)
    op.create_unique_constraint(_UQ_NAME, 'nostr_identities', ['pubkey_hex'])

    op.drop_constraint(_AUTO_FK_NAME, 'nostr_identities', type_='foreignkey')
    op.create_foreign_key(_FK_NAME, 'nostr_identities', 'users', ['user_id'], ['id'])


def downgrade() -> None:
    op.drop_constraint(_FK_NAME, 'nostr_identities', type_='foreignkey')
    op.create_foreign_key(_AUTO_FK_NAME, 'nostr_identities', 'users', ['user_id'], ['id'])

    op.drop_constraint(_UQ_NAME, 'nostr_identities', type_='unique')
    op.drop_column('nostr_identities', 'pubkey_hex')
