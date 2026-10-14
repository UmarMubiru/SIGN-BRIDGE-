from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, Literal, Any
from app.models.recording import RecordingStatus, ValidationStatus


class RecordingBase(BaseModel):
    public_id: str = Field(..., min_length=1, max_length=50)
    client_id: str = Field(..., min_length=1, max_length=100)
    session_id: str
    signer_id: str
    sign_id: str
    repetition_no: int = Field(..., ge=1, le=10)
    camera_angle: str = Field(..., max_length=50)
    capture_format: Optional[Literal[
        'standard_frontal',
        'repeat_frontal',
        'contextual_utterance',
        # Accept existing clients and historical recording formats.
        'horizontal_sweep',
        'vertical_sweep',
        'natural_performance',
    ]] = None
    cue_markers: list[dict[str, Any]] = Field(default_factory=list)
    lighting_condition: str = Field(..., max_length=50)
    background: str = Field(..., max_length=50)
    file_name: str = Field(..., max_length=255)
    remarks: Optional[str] = None
    recording_status: RecordingStatus = RecordingStatus.PENDING_REVIEW
    validation_status: ValidationStatus = ValidationStatus.PENDING


class RecordingCreate(RecordingBase):
    capture_format: Literal[
        'standard_frontal',
        'repeat_frontal',
        'contextual_utterance',
        'horizontal_sweep',
        'vertical_sweep',
        'natural_performance',
    ]
    remarks: Optional[str] = Field(None, max_length=5000)


class RecordingUploadRequest(BaseModel):
    file_name: str = Field(..., min_length=1, max_length=255)
    mime_type: Literal['video/webm', 'video/mp4']
    file_size: int = Field(..., gt=0)


class RecordingUploadFailure(BaseModel):
    error: str = Field(..., min_length=1, max_length=500)


class RecordingUpdate(BaseModel):
    recording_status: Optional[RecordingStatus] = None
    validation_status: Optional[ValidationStatus] = None
    file_url: Optional[str] = None
    mime_type: Optional[str] = None
    file_size: Optional[int] = None
    duration: Optional[int] = None
    resolution: Optional[str] = None
    fps: Optional[int] = None
    remarks: Optional[str] = None
    validator_id: Optional[str] = None
    validated_at: Optional[datetime] = None


class RecordingResponse(RecordingBase):
    id: str
    orientation_status: Literal['pending', 'queued', 'processing', 'completed', 'failed'] = 'pending'
    orientation_error: Optional[str] = None
    processed_frame_count: int = 0
    cloud_storage_status: Literal['local_only', 'queued', 'uploading', 'uploaded', 'failed'] = 'local_only'
    cloud_storage_error: Optional[str] = None
    storage_path: Optional[str] = None
    cloud_object_key: Optional[str] = None
    file_url: Optional[str] = None
    mime_type: Optional[str] = None
    file_size: Optional[int] = None
    duration: Optional[int] = None
    resolution: Optional[str] = None
    fps: Optional[int] = None
    remarks: Optional[str] = None
    validator_id: Optional[str] = None
    validated_at: Optional[datetime] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
