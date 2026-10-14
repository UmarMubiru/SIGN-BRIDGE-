import uuid

from sqlalchemy import Column, Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import relationship

from app.core.database import Base


class OrientationFrame(Base):
    """Sampled video frame, estimated head pose, and hand/face landmarks."""

    __tablename__ = "orientation_frames"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    recording_id = Column(
        String(36), ForeignKey("recordings.id", ondelete="CASCADE"), nullable=False, index=True
    )
    frame_index = Column(Integer, nullable=False)
    timestamp_ms = Column(Integer, nullable=False)
    yaw_degrees = Column(Float, nullable=True)
    pitch_degrees = Column(Float, nullable=True)
    orientation_label = Column(String(32), nullable=False)
    face_landmarks = Column(JSON, nullable=True)
    hand_landmarks = Column(JSON, nullable=False, default=list)
    image_url = Column(String(500), nullable=False)

    recording = relationship("Recording", back_populates="orientation_frames")
