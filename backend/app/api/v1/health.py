from datetime import datetime, timezone

from fastapi import APIRouter
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core.database import engine
from app.core.config import settings

router = APIRouter()


@router.get("/health")
def health_check():
    """Report healthy only when the configured database accepts a query."""
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(status_code=503, detail="Database is unavailable")

    return {
        "status": "healthy",
        "version": settings.VERSION,
        "database": "connected",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
