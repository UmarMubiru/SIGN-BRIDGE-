from sqlalchemy import Column, Integer, String, DateTime, Text, JSON, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid
from ..core.database import Base


class DatasetVersion(Base):
    __tablename__ = "dataset_versions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    version_number = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    created_by = Column(String(36), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Dataset metadata
    total_recordings = Column(Integer, default=0, nullable=False)
    included_recordings = Column(Integer, default=0, nullable=False)
    excluded_recordings = Column(Integer, default=0, nullable=False)
    
    # Export configuration
    export_config = Column(JSON, nullable=True)
    
    # Relationships
    creator = relationship("User", back_populates="dataset_versions")
    
    def __repr__(self):
        return f"<DatasetVersion {self.version_number}: {self.name}>"
