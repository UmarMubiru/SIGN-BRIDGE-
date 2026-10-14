from sqlalchemy import Column, String, Boolean, Integer, DateTime, Text, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import uuid
from app.core.database import Base


class Sign(Base):
    __tablename__ = "signs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sign_code = Column(String(50), unique=True, nullable=False, index=True)  # e.g., HELLO, THANK_YOU
    gloss = Column(String(100), nullable=False)  # The actual sign name
    display_name = Column(String(100), nullable=False)  # User-friendly display name
    category = Column(String(50), nullable=True)  # e.g., greeting, question, action
    description = Column(Text, nullable=True)
    instruction = Column(Text, nullable=True)  # How to perform the sign
    active = Column(Boolean, default=True, nullable=False)
    target_formats = Column("target_repetitions", Integer, default=3, nullable=False)
    created_at = Column(DateTime(), server_default=func.now())
    updated_at = Column(DateTime(), onupdate=func.now())

    def __repr__(self):
        return f"<Sign(sign_code={self.sign_code}, gloss={self.gloss}, target_formats={self.target_formats})>"


class SignVersion(Base):
    __tablename__ = "sign_versions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sign_id = Column(String(36), ForeignKey("signs.id"), nullable=False)
    version = Column(String(20), nullable=False)  # e.g., v1.0, v1.1
    instruction = Column(Text, nullable=True)
    definition = Column(Text, nullable=True)
    created_at = Column(DateTime(), server_default=func.now())
    created_by = Column(String(36), ForeignKey("users.id"), nullable=True)

    def __repr__(self):
        return f"<SignVersion(sign_id={self.sign_id}, version={self.version})>"
