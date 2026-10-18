"""Importa todos os models para que fiquem registrados em `Base.metadata` —
é isso que o Alembic usa para gerar migrations automaticamente (ver
alembic/env.py). Todo model novo precisa entrar aqui.
"""

from app.domain.models.exercise import Exercise  # noqa: F401
from app.domain.models.like import Like  # noqa: F401
from app.domain.models.muscle_group import MuscleGroup  # noqa: F401
from app.domain.models.nostr_identity import NostrIdentity  # noqa: F401
from app.domain.models.ranking import RankingEntry  # noqa: F401
from app.domain.models.set import WorkoutSet  # noqa: F401
from app.domain.models.shared_event import SharedEvent  # noqa: F401
from app.domain.models.user import User  # noqa: F401
from app.domain.models.workout import Workout  # noqa: F401
