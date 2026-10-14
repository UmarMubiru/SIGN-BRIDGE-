from sqlalchemy import Column, String, Boolean, DateTime, Text, ForeignKey
from sqlalchemy.sql import func
import uuid
from app.core.database import Base


class Consent(Base):
    __tablename__ = "consents"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    signer_id = Column(String(36), ForeignKey("signers.id"), nullable=False)
    consent_version = Column(String(20), nullable=False)  # e.g., v1.0
    consent_status = Column(String(20), nullable=False)  # consented, withdrawn
    consented_at = Column(DateTime(), nullable=True)
    recorded_by = Column(String(36), ForeignKey("users.id"), nullable=True)
    withdrawn_at = Column(DateTime(), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(), server_default=func.now())

    def __repr__(self):
        return f"<Consent(signer_id={self.signer_id}, version={self.consent_version}, status={self.consent_status})>"
