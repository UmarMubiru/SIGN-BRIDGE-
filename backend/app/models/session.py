from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid
import enum
from datetime import datetime
from app.core.database import Base


class SessionStatus(str, enum.Enum):
    """Session lifecycle status"""
    CREATED = "created"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class CollectionSession(Base):
    """Collection session tracking"""
    __tablename__ = "collection_sessions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    public_id = Column(String(20), unique=True, nullable=False, index=True)
    
    # Session context
    signer_id = Column(String(36), ForeignKey("signers.id"), nullable=False)
    collector_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    
    # Collection context
    venue = Column(String(100), nullable=False, default="Makerere University / MUDSA")
    protocol_version = Column(String(20), nullable=False, default="v1")
    
    # Session conditions (set once, apply to all recordings)
    lighting_condition = Column(String(50), nullable=False)  # Daylight, Indoor Artificial, Low Light / Dim
    background = Column(String(50), nullable=False)  # Plain Wall — Light, Plain Wall — Dark, Textured / Cluttered
    
    # Device context
    device_info = Column(Text, nullable=True)  # JSON string: device type, OS, camera info
    camera_info = Column(Text, nullable=True)  # JSON string: camera type, resolution, FPS
    
    # Session lifecycle
    status = Column(SQLEnum(SessionStatus), nullable=False, default=SessionStatus.CREATED)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    # Counters
    total_recordings = Column(Integer, default=0)
    successful_recordings = Column(Integer, default=0)
    
    # Notes
    notes = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    signer = relationship("Signer", back_populates="sessions")
    collector = relationship("User", back_populates="sessions")
    recordings = relationship("Recording", back_populates="session")
