from sqlalchemy import Column, String, Boolean, DateTime, Integer
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import uuid
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    public_id = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="collector", nullable=False)  # admin, collector, validator
    token_version = Column(Integer, default=0, server_default="0", nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(), server_default=func.now())
    updated_at = Column(DateTime(), onupdate=func.now())
    last_login_at = Column(DateTime(), nullable=True)

    # Relationships
    sessions = relationship("CollectionSession", back_populates="collector")
    dataset_versions = relationship("DatasetVersion", back_populates="creator")

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, role={self.role})>"
