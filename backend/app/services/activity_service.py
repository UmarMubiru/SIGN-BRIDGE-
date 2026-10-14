from sqlalchemy.orm import Session

from app.models.activity_log import ActivityLog


def log_activity(
    db: Session,
    *,
    actor_id: str | None,
    event_type: str,
    message: str,
    details: str | None = None,
    recording_id: str | None = None,
) -> ActivityLog:
    event = ActivityLog(
        actor_id=actor_id,
        event_type=event_type,
        message=message,
        details=details,
        recording_id=recording_id,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event
