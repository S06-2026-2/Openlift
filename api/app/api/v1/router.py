"""Router agregado da v1 — montado em app/main.py com prefixo /api/v1.

Rate limiting (OPS-05, RNF-03): `/auth` com `RATE_LIMIT_AUTH`; `/social`,
`/profiles` e `/media` com `RATE_LIMIT_SOCIAL` (app/core/rate_limit.py).
"""

from fastapi import APIRouter, Depends

from app.api.v1 import auth, exercises, me, media, profiles, social, stats, workouts
from app.core.rate_limit import rate_limit

_auth_limit = [Depends(rate_limit("auth", "rate_limit_auth"))]
_social_limit = [Depends(rate_limit("social", "rate_limit_social"))]

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"], dependencies=_auth_limit)
api_router.include_router(me.router, prefix="/me", tags=["me"])
api_router.include_router(exercises.router, prefix="/exercises", tags=["exercises"])

api_router.include_router(workouts.router, prefix="/workouts", tags=["workouts"])
api_router.include_router(stats.router, prefix="/stats", tags=["stats"])
api_router.include_router(
    social.router, prefix="/social", tags=["social"], dependencies=_social_limit
)
api_router.include_router(
    profiles.router, prefix="/profiles", tags=["profiles"], dependencies=_social_limit
)
api_router.include_router(media.router, prefix="/media", tags=["media"], dependencies=_social_limit)
