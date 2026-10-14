from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.auth_dependencies import get_current_user
from app.core.database import get_db
from app.models.activity_log import ActivityLog
from app.schemas.activity_log import ActivityLogResponse
from app.schemas.user import UserResponse

router = APIRouter()


@router.get("/", response_model=list[ActivityLogResponse])
def list_activity(
    limit: int = Query(default=20, ge=1, le=100),
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(ActivityLog)
        .order_by(ActivityLog.created_at.desc(), ActivityLog.id.desc())
        .limit(limit)
        .all()
    )
