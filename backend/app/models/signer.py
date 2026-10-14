from sqlalchemy import Column, String, Boolean, DateTime, Integer, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import uuid
from app.core.database import Base


class Signer(Base):
    __tablename__ = "signers"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    signer_id = Column(String(50), unique=True, nullable=True, index=True)  # Participant code like S001
    name = Column(String(100), nullable=False)
    category = Column(String(50), nullable=False)  # e.g., student, teacher, community_member
    age = Column(Integer, nullable=True)
    gender = Column(String(20), nullable=True)
    education_level = Column(String(50), nullable=True)
    consent_status = Column(String(20), default="pending", nullable=False)  # pending, consented, withdrawn
    status = Column(String(20), default="active", nullable=False)  # active, inactive
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(), server_default=func.now())
    updated_at = Column(DateTime(), onupdate=func.now())

    # Relationships
    sessions = relationship("CollectionSession", back_populates="signer")

    def __repr__(self):
        return f"<Signer(signer_id={self.signer_id}, name={self.name}, consent_status={self.consent_status})>"
