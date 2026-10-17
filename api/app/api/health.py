from fastapi import APIRouter, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core.database import engine

router = APIRouter(tags=["Health"])


@router.get("/health/live")
def liveness():
    return {"status": "alive"}


@router.get("/health/ready")
def readiness():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))

        return {
            "status": "ready",
            "database": "connected",
        }

    except SQLAlchemyError:
        raise HTTPException(
            status_code=503,
            detail={
                "status": "not_ready",
                "database": "unavailable",
            },
        ) from None
