from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class SignBase(BaseModel):
    sign_code: str = Field(..., min_length=2, max_length=50)
    gloss: str = Field(..., min_length=2, max_length=100)
    display_name: str = Field(..., min_length=2, max_length=100)
    category: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = None
    instruction: Optional[str] = None


class SignCreate(SignBase):
    target_formats: int = Field(default=3, ge=1, le=3)


class SignUpdate(BaseModel):
    gloss: Optional[str] = Field(None, min_length=2, max_length=100)
    display_name: Optional[str] = Field(None, min_length=2, max_length=100)
    category: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = None
    instruction: Optional[str] = None
    active: Optional[bool] = None
    target_formats: Optional[int] = Field(None, ge=1, le=3)


class SignResponse(SignBase):
    id: str
    active: bool
    target_formats: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SignVersionBase(BaseModel):
    sign_id: Optional[str] = None  # Optional, can be set from URL
    version: str = "v1.0"
    instruction: Optional[str] = None
    definition: Optional[str] = None


class SignVersionCreate(SignVersionBase):
    pass


class SignVersionResponse(SignVersionBase):
    id: str
    created_at: datetime
    created_by: Optional[str] = None

    class Config:
        from_attributes = True
