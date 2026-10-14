from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class SignerBase(BaseModel):
    signer_id: Optional[str] = Field(None, min_length=3, max_length=50)
    name: str = Field(..., min_length=2, max_length=100)
    category: str = Field(..., max_length=50)
    age: Optional[int] = Field(None, ge=0, le=120)
    gender: Optional[str] = Field(None, max_length=20)
    education_level: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = None


class SignerCreate(SignerBase):
    pass


class SignerUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    category: Optional[str] = Field(None, max_length=50)
    age: Optional[int] = Field(None, ge=0, le=120)
    gender: Optional[str] = Field(None, max_length=20)
    education_level: Optional[str] = Field(None, max_length=50)
    consent_status: Optional[str] = None
    status: Optional[str] = None
    notes: Optional[str] = None


class SignerResponse(SignerBase):
    id: str
    consent_status: str
    status: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ConsentBase(BaseModel):
    signer_id: Optional[str] = None  # Optional, can be set from URL
    consent_version: str = "v1.0"
    notes: Optional[str] = None


class ConsentCreate(ConsentBase):
    consent_status: str = "consented"  # consented or withdrawn


class ConsentResponse(ConsentBase):
    id: str
    consent_status: str
    consented_at: Optional[datetime] = None
    recorded_by: Optional[str] = None
    withdrawn_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True
