from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_serializer


class ActivityLogResponse(BaseModel):
    id: str
    actor_id: Optional[str] = None
    event_type: str
    message: str
    details: Optional[str] = None
    recording_id: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime) -> datetime:
        # ActivityLog.created_at is stored as a naive UTC timestamp for
        # compatibility with the existing database schema. Mark that timezone
        # explicitly so clients don't interpret UTC as their local time.
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)
