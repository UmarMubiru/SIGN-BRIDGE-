from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status, Query, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.core.database import get_db, SessionLocal
from app.api.v1.auth import get_current_user
from app.repositories.recording_repository import RecordingRepository
from app.schemas.recording import (
    RecordingCreate,
    RecordingUpdate,
    RecordingResponse,
    RecordingUploadFailure,
    RecordingUploadRequest,
)
from app.schemas.user import UserResponse
from app.services.activity_service import log_activity
from app.services.orientation_service import process_recording
from app.services.object_storage_service import (
    delete_object,
    download_object,
    object_metadata,
    presign_download,
    presign_upload,
    promote_object,
    upload_local_file,
    upload_stream,
)
from app.models.orientation_frame import OrientationFrame
from app.models.recording import Recording
from app.models.session import CollectionSession
from app.core.config import settings
import shutil
import tempfile
import uuid
from pathlib import Path
import logging
from sqlalchemy.exc import IntegrityError

router = APIRouter()
logger = logging.getLogger(__name__)

# Keep uploaded files next to the backend even when Uvicorn starts from a
# different working directory.
UPLOAD_DIR = Path(__file__).resolve().parents[3] / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)


def get_recording_service(db: Session = Depends(get_db)):
    """Dependency to get recording repository"""
    return RecordingRepository(db)


def _process_uploaded_recording(recording_id: str) -> None:
    """Process a temporary download; keep the R2 object as the durable video."""
    db = SessionLocal()
    try:
        recording = db.query(Recording).filter(Recording.id == recording_id).first()
        if recording is None or not recording.storage_path:
            return
        recording.orientation_status = "processing"
        recording.orientation_error = None
        db.commit()
        suffix = Path(recording.file_name).suffix or ".video"
        with tempfile.TemporaryDirectory(prefix="signbridge-processing-") as working_dir:
            video_path = Path(working_dir) / f"recording{suffix}"
            download_object(recording.storage_path, video_path)
            process_recording(db, recording, video_path, UPLOAD_DIR)
            frame_dir = UPLOAD_DIR / "processed" / recording.id
            for frame in recording.orientation_frames:
                image_name = Path(frame.image_url).name
                image_path = frame_dir / image_name
                if image_path.is_file():
                    image_key = f"{recording.storage_path}.frames/{image_name}"
                    upload_local_file(image_path, image_key, "image/jpeg")
                    frame.image_url = image_key
            db.commit()
        shutil.rmtree(UPLOAD_DIR / "processed" / recording.id, ignore_errors=True)
        recording.orientation_status = "completed"
        db.commit()
    except Exception as exc:
        db.rollback()
        recording = db.query(Recording).filter(Recording.id == recording_id).first()
        if recording is not None:
            recording.orientation_status = "failed"
            recording.orientation_error = str(exc)[:1000]
            db.commit()
    finally:
        db.close()


def cloud_storage_prefix() -> str:
    return settings.OBJECT_STORAGE_PREFIX.strip("/")


@router.post("/", response_model=RecordingResponse, status_code=status.HTTP_201_CREATED)
def create_recording(
    recording_data: RecordingCreate,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Create a new recording"""
    try:
        payload = recording_data.model_dump()
        session = repo.db.query(CollectionSession).filter(
            CollectionSession.id == payload["session_id"]
        ).first()
        if session is None:
            raise ValueError("Collection session was not found. Refresh and select a valid session.")
        signer = session.signer
        if signer is None or payload["signer_id"] not in {
            session.signer_id,
            signer.signer_id,
        }:
            raise ValueError("The selected signer does not match this collection session.")
        # Flutter carries the public code (S001) in RecordingContext for file
        # names and labels. PostgreSQL metadata must reference the signer UUID.
        payload["signer_id"] = session.signer_id
        format_metadata = {
            'standard_frontal': (1, 'Frontal • Standard Sign'),
            'repeat_frontal': (2, 'Frontal • Natural Repeat'),
            'contextual_utterance': (3, 'Frontal • Sign in Context'),
            # Keep older clients functional during rollout and preserve the
            # original labels on recordings already in the database.
            'horizontal_sweep': (1, 'Horizontal Sweep'),
            'vertical_sweep': (2, 'Vertical Sweep'),
            'natural_performance': (3, 'Natural Performance'),
        }
        payload['repetition_no'], payload['camera_angle'] = format_metadata[payload['capture_format']]
        recording = repo.create_recording(payload)
        return RecordingResponse.model_validate(recording)
    except ValueError as e:
        repo.db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except IntegrityError as exc:
        repo.db.rollback()
        logger.exception("Recording metadata conflicts with an existing row or database reference")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This recording conflicts with an existing session/sign format or an invalid database reference. Refresh the session and retry.",
        ) from exc
    except Exception as exc:
        repo.db.rollback()
        logger.exception("Could not save recording metadata")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="The server could not save the recording metadata. Check the backend log and retry.",
        ) from exc


@router.get("/", response_model=list[RecordingResponse])
def list_recordings(
    skip: int = 0,
    limit: int = 100,
    session_id: str = None,
    sign_id: str = None,
    signer_id: str = None,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """List recordings"""
    return repo.list_recordings(
        skip=skip,
        limit=limit,
        session_id=session_id,
        sign_id=sign_id,
        signer_id=signer_id
    )


@router.get("/{recording_id}", response_model=RecordingResponse)
def get_recording(
    recording_id: str,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get recording by ID"""
    recording = repo.get_recording_by_id(recording_id)
    if not recording:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recording not found"
        )
    return RecordingResponse.model_validate(recording)


@router.patch("/{recording_id}", response_model=RecordingResponse)
def update_recording(
    recording_id: str,
    update_data: RecordingUpdate,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Update recording"""
    existing = repo.get_recording_by_id(recording_id)
    previous_status = existing.validation_status.value if existing else None
    recording = repo.update_recording(recording_id, update_data.model_dump(exclude_unset=True))
    if not recording:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recording not found"
        )
    current_status = recording.validation_status.value
    if previous_status != current_status:
        log_activity(
            repo.db,
            actor_id=current_user.id,
            event_type=f"recording_{current_status}",
            message=f"Recording {current_status}",
            details=f"{recording.file_name} · {recording.capture_format or 'legacy recording'}",
            recording_id=recording.id,
        )
    return RecordingResponse.model_validate(recording)


@router.delete("/{recording_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_recording(
    recording_id: str,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Delete recording"""
    recording = repo.get_recording_by_id(recording_id)
    if not recording:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recording not found"
        )
    file_url = recording.file_url
    storage_path = recording.storage_path
    recording_name = recording.file_name
    capture_format = recording.capture_format or f"legacy recording {recording.repetition_no}"
    video_path = UPLOAD_DIR / Path(file_url or "").name if (file_url or "").startswith("/uploads/") else None
    if storage_path:
        try:
            delete_object(storage_path)
            for frame in recording.orientation_frames:
                if frame.image_url and not frame.image_url.startswith("/uploads/"):
                    delete_object(frame.image_url)
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Could not delete the cloud video object: {exc}",
            )
    success = repo.delete_recording(recording_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recording not found"
        )
    if video_path and video_path.is_file():
        video_path.unlink(missing_ok=True)
    import shutil
    shutil.rmtree(UPLOAD_DIR / "processed" / recording_id, ignore_errors=True)
    log_activity(
        repo.db,
        actor_id=current_user.id,
        event_type="recording_deleted",
        message="Recording deleted",
        details=f"{recording_name} · {capture_format}",
        recording_id=recording_id,
    )
    return None


@router.post("/{recording_id}/upload-url")
def create_upload_url(
    recording_id: str,
    payload: RecordingUploadRequest,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Reserve a private R2 object and issue a short-lived direct upload URL."""
    recording = repo.get_recording_by_id(recording_id)
    if not recording:
        raise HTTPException(status_code=404, detail="Recording not found")
    try:
        from app.services.object_storage_service import require_cloud_storage
        require_cloud_storage()
        if recording.cloud_storage_status == "uploaded":
            raise HTTPException(status_code=409, detail="This recording already has a completed upload.")
        mime_type = payload.mime_type
        extension = {"video/webm": ".webm", "video/mp4": ".mp4"}.get(mime_type)
        if extension is None:
            raise HTTPException(status_code=415, detail="Only WebM and MP4 videos are accepted.")
        if payload.file_size > settings.MAX_UPLOAD_SIZE:
            raise HTTPException(status_code=413, detail="Video must be between 1 byte and the configured upload limit.")
        year_month = recording.created_at.strftime("%Y/%m")
        prefix = cloud_storage_prefix()
        staging_key = f"{prefix}/staging/{recording.id}/{uuid.uuid4().hex}{extension}"
        if recording.storage_path:
            delete_object(recording.storage_path)
        url = presign_upload(staging_key, mime_type)
        recording = repo.update_recording(recording_id, {
            "storage_path": staging_key,
            "cloud_storage_status": "uploading",
            "cloud_storage_error": None,
            "recording_status": "uploading",
        })
        return {"upload_url": url, "expires_in": 900, "content_type": mime_type}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Cloud upload is unavailable: {exc}")


@router.post("/{recording_id}/upload-proxy", status_code=status.HTTP_204_NO_CONTENT)
def upload_video_through_backend(
    recording_id: str,
    video: UploadFile = File(...),
    mime_type: str = Form(...),
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user),
):
    """Fallback for browsers whose network blocks cross-origin PUT to R2."""
    recording = repo.get_recording_by_id(recording_id)
    if not recording or not recording.storage_path:
        raise HTTPException(status_code=409, detail="Reserve an upload before sending the video.")
    if recording.cloud_storage_status == "uploaded":
        raise HTTPException(status_code=409, detail="This recording already has a completed upload.")
    if mime_type not in {"video/webm", "video/mp4"}:
        raise HTTPException(status_code=415, detail="Only WebM and MP4 videos are accepted.")
    file_size = video.size
    if file_size is None:
        video.file.seek(0, 2)
        file_size = video.file.tell()
        video.file.seek(0)
    if file_size <= 0 or file_size > settings.MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=413, detail="Video exceeds the configured upload size limit.")
    try:
        upload_stream(video.file, recording.storage_path, mime_type)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Could not stream the video to cloud storage: {exc}")
    return None


@router.post("/{recording_id}/complete-upload", response_model=RecordingResponse)
def complete_upload(
    recording_id: str,
    background_tasks: BackgroundTasks,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user),
):
    recording = repo.get_recording_by_id(recording_id)
    if not recording or not recording.storage_path:
        raise HTTPException(status_code=404, detail="No upload was reserved for this recording.")
    if recording.cloud_storage_status == "uploaded" and recording.file_url == recording.storage_path:
        return RecordingResponse.model_validate(recording)
    try:
        metadata = object_metadata(recording.storage_path)
    except Exception as exc:
        raise HTTPException(status_code=409, detail=f"Uploaded object is not available yet: {exc}")
    mime_type = metadata["content_type"].split(";")[0].strip().lower()
    if metadata["size"] <= 0 or metadata["size"] > settings.MAX_UPLOAD_SIZE:
        delete_object(recording.storage_path)
        raise HTTPException(status_code=413, detail="Uploaded video exceeds the configured size limit.")
    if mime_type not in {"video/webm", "video/mp4"}:
        delete_object(recording.storage_path)
        raise HTTPException(status_code=415, detail="Uploaded object is not an accepted video type.")
    year_month = recording.created_at.strftime("%Y/%m")
    extension = ".webm" if mime_type == "video/webm" else ".mp4"
    prefix = cloud_storage_prefix()
    durable_key = (
        f"{prefix}/recordings/{year_month}/{recording.signer_id}/"
        f"{recording.public_id}{extension}"
    )
    staging_key = recording.storage_path
    try:
        promote_object(staging_key, durable_key)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Could not finalize the cloud upload: {exc}")
    recording = repo.update_recording(recording_id, {
        "storage_path": durable_key,
        "file_url": durable_key,
        "file_size": metadata["size"],
        "mime_type": mime_type,
        "recording_status": "uploaded",
        "orientation_status": "queued",
        "orientation_error": None,
        "cloud_storage_status": "uploaded",
        "cloud_storage_error": None,
    })
    if staging_key != durable_key:
        try:
            delete_object(staging_key)
        except Exception:
            pass  # Durable copy is committed; an orphaned staging object expires via lifecycle policy.
    status_label = (
        "Recording approved and uploaded"
        if recording.validation_status.value == "approved"
        else "Recording video uploaded"
    )
    log_activity(
        repo.db,
        actor_id=current_user.id,
        event_type="recording_uploaded",
        message=status_label,
        details=f"{recording.file_name} · {recording.capture_format or 'legacy recording'}",
        recording_id=recording.id,
    )
    background_tasks.add_task(_process_uploaded_recording, recording_id)
    return RecordingResponse.model_validate(recording)


@router.post("/{recording_id}/upload-failed", response_model=RecordingResponse)
def mark_upload_failed(
    recording_id: str,
    payload: RecordingUploadFailure,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user),
):
    recording = repo.get_recording_by_id(recording_id)
    if not recording:
        raise HTTPException(status_code=404, detail="Recording not found")
    if recording.cloud_storage_status == "uploaded":
        return RecordingResponse.model_validate(recording)
    if recording.storage_path:
        try:
            delete_object(recording.storage_path)
        except Exception:
            pass
    recording = repo.update_recording(recording_id, {
        "storage_path": None,
        "file_url": None,
        "file_size": None,
        "mime_type": None,
        "recording_status": "failed",
        "cloud_storage_status": "failed",
        "cloud_storage_error": payload.error,
    })
    return RecordingResponse.model_validate(recording)


@router.get("/{recording_id}/download-url")
def create_download_url(
    recording_id: str,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user),
):
    recording = repo.get_recording_by_id(recording_id)
    if not recording or not recording.storage_path:
        raise HTTPException(status_code=404, detail="Cloud video not found")
    try:
        return {"url": presign_download(recording.storage_path, expires_in=3600), "expires_in": 3600}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Cloud download is unavailable: {exc}")


@router.get("/{recording_id}/frames")
def list_orientation_frames(
    recording_id: str,
    skip: int = 0,
    limit: int = Query(default=100, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    recording = db.query(OrientationFrame).filter(OrientationFrame.recording_id == recording_id)
    if db.query(OrientationFrame.id).filter(OrientationFrame.recording_id == recording_id).first() is None:
        if db.query(Recording.id).filter(Recording.id == recording_id).first() is None:
            raise HTTPException(status_code=404, detail="Recording not found")
    return recording.order_by(OrientationFrame.timestamp_ms).offset(skip).limit(limit).all()


@router.get("/{recording_id}/video")
def get_video(
    recording_id: str,
    repo: RecordingRepository = Depends(get_recording_service),
    current_user: UserResponse = Depends(get_current_user)
):
    """Get video file for a recording"""
    recording = repo.get_recording_by_id(recording_id)
    if not recording or not recording.file_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found"
        )
    
    file_path = UPLOAD_DIR / Path(recording.file_url).name
    if not file_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video file not found on disk"
        )
    
    from fastapi.responses import FileResponse
    import mimetypes
    media_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    return FileResponse(file_path, media_type=media_type)
