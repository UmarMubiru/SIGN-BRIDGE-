from datetime import datetime
import uuid

from sqlalchemy import Column, DateTime, ForeignKey, String, Text

from app.core.database import Base


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    actor_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    event_type = Column(String(50), nullable=False, index=True)
    message = Column(String(255), nullable=False)
    details = Column(Text, nullable=True)
    recording_id = Column(String(36), nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
