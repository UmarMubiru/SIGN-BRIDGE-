from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime


class DatasetVersionBase(BaseModel):
    version_number: str
    name: str
    description: Optional[str] = None
    total_recordings: int = 0
    included_recordings: int = 0
    excluded_recordings: int = 0
    export_config: Optional[Dict[str, Any]] = None


class DatasetVersionCreate(DatasetVersionBase):
    pass


class DatasetVersionResponse(DatasetVersionBase):
    id: str
    created_by: str
    created_at: datetime
    
    class Config:
        from_attributes = True
