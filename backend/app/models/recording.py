from sqlalchemy import Column, String, DateTime, ForeignKey, Enum as SQLEnum, Text, Integer, Boolean, UniqueConstraint, JSON
from sqlalchemy.orm import relationship, synonym
import uuid
import enum
from datetime import datetime
from app.core.database import Base


class RecordingStatus(str, enum.Enum):
    """Recording lifecycle status"""
    PENDING_REVIEW = "pending_review"
    UPLOADING = "uploading"
    UPLOADED = "uploaded"
    FAILED = "failed"
    REJECTED = "rejected"


class ValidationStatus(str, enum.Enum):
    """Validation status"""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class Recording(Base):
    """Recording metadata for the SignBridge collection protocol."""
    __tablename__ = "recordings"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    public_id = Column(String(50), unique=True, nullable=False, index=True)
    client_id = Column(String(100), unique=True, nullable=False, index=True)  # For idempotency
    
    # Session context
    session_id = Column(String(36), ForeignKey("collection_sessions.id"), nullable=False)
    signer_id = Column(String(36), ForeignKey("signers.id"), nullable=False)
    
    # Sign context
    sign_id = Column(String(36), ForeignKey("signs.id"), nullable=False)
    # Legacy ordinal retained for older clients/data; new recordings use capture_format.
    repetition_no = Column(Integer, nullable=False)
    capture_format = Column(String(32), nullable=True, index=True)
    # Timeline of guided prompts in a continuous video, in elapsed seconds.
    cue_markers = Column(JSON, nullable=False, default=list)
    orientation_status = Column(String(20), nullable=False, default="pending")
    orientation_error = Column(Text, nullable=True)
    processed_frame_count = Column(Integer, nullable=False, default=0)
    cloud_storage_status = Column(String(20), nullable=False, default="local_only")
    cloud_storage_error = Column(Text, nullable=True)
    storage_path = Column(String(500), nullable=True)
    cloud_object_key = synonym("storage_path")  # Compatibility for older API clients.
    
    # Human-readable capture format for new recordings; legacy rows keep camera angles.
    camera_angle = Column(String(50), nullable=False)
    
    # Session conditions (inherited from session)
    lighting_condition = Column(String(50), nullable=False)  # Daylight, Indoor Artificial, Low Light / Dim
    background = Column(String(50), nullable=False)  # Plain Wall — Light, Plain Wall — Dark, Textured / Cluttered
    
    # File metadata
    file_name = Column(String(255), nullable=False)  # S01_Hello_01.mp4
    file_url = Column(String(500), nullable=True)  # Storage path/URL
    mime_type = Column(String(100), nullable=True)
    file_size = Column(Integer, nullable=True)
    duration = Column(Integer, nullable=True)  # Seconds
    resolution = Column(String(20), nullable=True)  # e.g., 720p, 1080p
    fps = Column(Integer, nullable=True)  # Frames per second
    
    # Status tracking
    recording_status = Column(SQLEnum(RecordingStatus), nullable=False, default=RecordingStatus.PENDING_REVIEW)
    validation_status = Column(SQLEnum(ValidationStatus), nullable=False, default=ValidationStatus.PENDING)
    
    # Optional remarks
    remarks = Column(Text, nullable=True)
    
    # Validator/reviewer
    validator_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    validated_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Nullable format keeps historical rows while enforcing one video per new format.
    __table_args__ = (
        UniqueConstraint('session_id', 'sign_id', 'capture_format', name='uq_session_sign_capture_format'),
    )

    # Relationships
    session = relationship("CollectionSession", back_populates="recordings")
    signer = relationship("Signer")
    sign = relationship("Sign")
    validator = relationship("User", foreign_keys=[validator_id])
    orientation_frames = relationship(
        "OrientationFrame", back_populates="recording", cascade="all, delete-orphan",
        order_by="OrientationFrame.timestamp_ms",
    )
