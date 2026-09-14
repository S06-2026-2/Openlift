"""Importa todos os models implementados para que fiquem registrados em
`Base.metadata` — é isso que o Alembic usa para gerar migrations
automaticamente (ver alembic/env.py).

Sprint 3 adiciona Exercise e MuscleGroup; Sprint 4 adiciona Like, Ranking e
SharedEvent — descomentar os imports conforme cada model ganha implementação.
"""

from app.domain.models.nostr_identity import NostrIdentity  # noqa: F401
from app.domain.models.set import WorkoutSet  # noqa: F401
from app.domain.models.user import User  # noqa: F401
from app.domain.models.workout import Workout  # noqa: F401

# TODO(Sprint 3): from app.domain.models.exercise import Exercise
# TODO(Sprint 3): from app.domain.models.muscle_group import MuscleGroup
# TODO(Sprint 4): from app.domain.models.like import Like
# TODO(Sprint 4): from app.domain.models.ranking import RankingEntry
# TODO(Sprint 4): from app.domain.models.shared_event import SharedEvent
