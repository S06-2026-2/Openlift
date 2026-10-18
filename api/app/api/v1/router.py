"""Router agregado da v1 — montado em app/main.py com prefixo /api/v1."""

from fastapi import APIRouter

from app.api.v1 import auth

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# TODO(BE-04): api_router.include_router(workouts.router, prefix="/workouts", tags=["workouts"])
# TODO(Sprint 3): api_router.include_router(stats.router, prefix="/stats", tags=["stats"])
# TODO(Sprint 4): api_router.include_router(social.router, prefix="/social", tags=["social"])
