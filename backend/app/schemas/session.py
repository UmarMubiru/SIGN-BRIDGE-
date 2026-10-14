from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from enum import Enum


class SessionStatus(str, Enum):
    CREATED = "created"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class SessionBase(BaseModel):
    venue: str = "Makerere University / MUDSA"
    protocol_version: str = "v1"
    lighting_condition: str = Field(..., max_length=50)
    background: str = Field(..., max_length=50)
    device_info: Optional[str] = None
    camera_info: Optional[str] = None
    notes: Optional[str] = None


class SessionCreate(SessionBase):
    signer_id: str


class SessionUpdate(BaseModel):
    status: Optional[SessionStatus] = None
    venue: Optional[str] = None
    lighting_condition: Optional[str] = None
    background: Optional[str] = None
    device_info: Optional[str] = None
    camera_info: Optional[str] = None
    notes: Optional[str] = None


class SessionResponse(BaseModel):
    id: str
    public_id: str
    signer_id: str
    collector_id: str
    venue: str
    protocol_version: str
    lighting_condition: str
    background: str
    device_info: Optional[str] = None
    camera_info: Optional[str] = None
    status: SessionStatus
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    total_recordings: int
    successful_recordings: int
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
