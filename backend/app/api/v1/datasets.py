from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask
from sqlalchemy.orm import Session, selectinload
from typing import List
from datetime import datetime
import uuid
import zipfile
import io
import re
import csv
import json
import os
import tempfile
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from app.core.database import get_db
from app.core.auth_dependencies import get_current_user
from app.models.user import User
from app.models.dataset_version import DatasetVersion
from app.models.recording import Recording
from app.schemas.dataset_version import DatasetVersionCreate, DatasetVersionResponse
from app.api.v1.recordings import UPLOAD_DIR
from app.services.activity_service import log_activity
from app.services.object_storage_service import cloud_storage_enabled, download_object, object_metadata

router = APIRouter()
logger = logging.getLogger(__name__)


def _temporary_object_copy(object_key: str, suffix: str = "") -> Path:
    descriptor, name = tempfile.mkstemp(prefix="signbridge-export-", suffix=suffix)
    os.close(descriptor)
    path = Path(name)
    try:
        download_object(object_key, path)
    except Exception:
        path.unlink(missing_ok=True)
        raise
    return path


def _export_video_path(recording: Recording) -> tuple[Path | None, bool]:
    legacy_path = UPLOAD_DIR / Path(recording.file_url or "").name
    if legacy_path.is_file():
        return legacy_path, False
    if recording.storage_path and cloud_storage_enabled():
        suffix = Path(recording.file_name).suffix
        return _temporary_object_copy(recording.storage_path, suffix), True
    return None, False


def _recording_video_available(recording: Recording) -> bool:
    path = UPLOAD_DIR / Path(recording.file_url or "").name
    if path.is_file():
        return True
    if not recording.storage_path or not cloud_storage_enabled():
        return False
    try:
        return object_metadata(recording.storage_path)["size"] > 0
    except Exception:
        return False


def _export_frame_path(recording: Recording, image_url: str | None) -> tuple[Path | None, bool]:
    if not image_url:
        return None, False
    local_path = UPLOAD_DIR / "processed" / recording.id / Path(image_url).name
    if local_path.is_file():
        return local_path, False
    if not image_url.startswith("/uploads/") and cloud_storage_enabled():
        return _temporary_object_copy(image_url, ".jpg"), True
    return None, False


def _prepare_frame_assets(recording: Recording) -> dict[str, tuple[Path | None, bool]]:
    """Fetch frame images concurrently so large datasets do not stall on serial R2 reads."""
    jobs = [frame for frame in recording.orientation_frames if frame.image_url]
    if not jobs:
        return {}

    assets: dict[str, tuple[Path | None, bool]] = {}
    with ThreadPoolExecutor(max_workers=min(8, len(jobs))) as executor:
        futures = {
            executor.submit(_export_frame_path, recording, frame.image_url): frame
            for frame in jobs
        }
        for future in as_completed(futures):
            frame = futures[future]
            try:
                assets[frame.id] = future.result()
            except Exception:
                logger.warning(
                    "Could not include orientation frame %s in dataset export",
                    frame.id,
                    exc_info=True,
                )
                assets[frame.id] = (None, False)
    return assets


def _recordings_zip(
    recordings: list[Recording],
    title: str,
    details: str = "",
    output=None,
) -> bytes | None:
    owns_buffer = output is None
    buffer = io.BytesIO() if owns_buffer else output
    manifest = [title, f"Export Date: {datetime.utcnow().isoformat()}Z", details, "", "Recordings:"]
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
        used_names: set[str] = set()
        recording_metadata = []
        frame_csv = io.StringIO()
        frame_writer = csv.DictWriter(frame_csv, fieldnames=[
            "recording_id", "file_name", "frame_index", "timestamp_ms", "yaw_degrees",
            "pitch_degrees", "orientation_label", "image_path",
        ])
        frame_writer.writeheader()
        landmarks_jsonl = []
        for recording in recordings:
            status_value = getattr(recording.validation_status, "value", recording.validation_status)
            label = (
                f"{recording.file_name} ({recording.capture_format or f'Legacy {recording.repetition_no}'}, {status_value})"
            )
            if not recording.file_url and not recording.storage_path:
                manifest.append(f"- {label} - NO FILE URL")
                continue

            video_path, remove_video_copy = _export_video_path(recording)
            if video_path is None:
                manifest.append(f"- {label} - FILE NOT FOUND")
                continue

            safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", Path(recording.file_name).name)
            if not safe_name:
                safe_name = f"{recording.public_id}.mp4"
            if safe_name in used_names:
                safe_name = f"{recording.public_id}_{safe_name}"
            used_names.add(safe_name)
            try:
                archive.write(video_path, f"videos/{safe_name}")
            finally:
                if remove_video_copy:
                    video_path.unlink(missing_ok=True)
            manifest.append(f"- {label} - included as videos/{safe_name}")
            frame_assets = _prepare_frame_assets(recording)
            recording_metadata.append({
                "recording_id": recording.id,
                "public_id": recording.public_id,
                "file_name": recording.file_name,
                "mime_type": recording.mime_type,
                "file_size": recording.file_size,
                "session_id": recording.session_id,
                "signer_id": recording.signer_id,
                "sign_id": recording.sign_id,
                "capture_format": recording.capture_format,
                "remarks": recording.remarks,
                "cue_markers": recording.cue_markers or [],
                "orientation_status": recording.orientation_status,
                "processed_frame_count": recording.processed_frame_count,
                "cloud_storage_status": recording.cloud_storage_status,
                "storage_path": recording.storage_path,
            })
            for frame in recording.orientation_frames:
                frame_name = Path(frame.image_url).name if frame.image_url else None
                frame_path, remove_frame_copy = frame_assets.get(frame.id, (None, False))
                image_path = f"frames/{recording.id}/{frame_name}" if frame_path and frame_path.is_file() else ""
                if image_path:
                    try:
                        archive.write(frame_path, image_path)
                    finally:
                        if remove_frame_copy:
                            frame_path.unlink(missing_ok=True)
                frame_writer.writerow({
                    "recording_id": recording.id,
                    "file_name": recording.file_name,
                    "frame_index": frame.frame_index,
                    "timestamp_ms": frame.timestamp_ms,
                    "yaw_degrees": frame.yaw_degrees,
                    "pitch_degrees": frame.pitch_degrees,
                    "orientation_label": frame.orientation_label,
                    "image_path": image_path,
                })
                landmarks_jsonl.append(json.dumps({
                    "recording_id": recording.id,
                    "frame_index": frame.frame_index,
                    "timestamp_ms": frame.timestamp_ms,
                    "face_landmarks": frame.face_landmarks,
                    "hand_landmarks": frame.hand_landmarks,
                }, separators=(",", ":")))

        archive.writestr("manifest.txt", "\n".join(manifest))
        archive.writestr("metadata/recordings.json", json.dumps(recording_metadata, indent=2))
        archive.writestr("metadata/orientation_frames.csv", frame_csv.getvalue())
        archive.writestr("metadata/landmarks.jsonl", "\n".join(landmarks_jsonl))
    return buffer.getvalue() if owns_buffer else None


def _zip_file_response(recordings: list[Recording], title: str, details: str, file_name: str):
    handle = tempfile.NamedTemporaryFile(prefix="signbridge-export-", suffix=".zip", delete=False)
    path = Path(handle.name)
    try:
        with handle:
            _recordings_zip(recordings, title, details, output=handle)
    except Exception:
        path.unlink(missing_ok=True)
        raise
    return FileResponse(
        path,
        media_type="application/zip",
        filename=file_name,
        background=BackgroundTask(lambda: path.unlink(missing_ok=True)),
    )


@router.post("/", response_model=DatasetVersionResponse, status_code=status.HTTP_201_CREATED)
def create_dataset_version(
    dataset: DatasetVersionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new dataset version."""
    export_config = dataset.export_config or {}
    recording_ids = export_config.get("recording_ids", [])
    if not isinstance(recording_ids, list) or not recording_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Select at least one recording with an uploaded video before creating a dataset.",
        )
    selected_recordings = db.query(Recording).filter(Recording.id.in_(recording_ids)).all()
    selected_by_id = {recording.id: recording for recording in selected_recordings}
    missing_ids = [recording_id for recording_id in recording_ids if recording_id not in selected_by_id]
    unavailable_videos = [
        recording.file_name
        for recording in selected_recordings
        if not (recording.file_url or recording.storage_path)
        or not _recording_video_available(recording)
    ]
    if missing_ids or unavailable_videos:
        problems = []
        if missing_ids:
            problems.append(f"recordings not found: {', '.join(missing_ids)}")
        if unavailable_videos:
            problems.append(f"uploaded video files not found: {', '.join(unavailable_videos)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot create dataset because " + "; ".join(problems),
        )

    # Check if version number already exists
    existing = db.query(DatasetVersion).filter(
        DatasetVersion.version_number == dataset.version_number
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Version number already exists"
        )
    
    # Create dataset version
    db_dataset = DatasetVersion(
        id=str(uuid.uuid4()),
        version_number=dataset.version_number,
        name=dataset.name,
        description=dataset.description,
        created_by=current_user.id,
        created_at=datetime.utcnow(),
        total_recordings=dataset.total_recordings,
        included_recordings=dataset.included_recordings,
        excluded_recordings=dataset.excluded_recordings,
        export_config=dataset.export_config
    )
    
    db.add(db_dataset)
    db.commit()
    db.refresh(db_dataset)
    log_activity(
        db,
        actor_id=current_user.id,
        event_type="dataset_created",
        message="Dataset created",
        details=f"{db_dataset.name} · {len(recording_ids)} selected recordings",
    )
    
    return db_dataset


@router.get("/", response_model=List[DatasetVersionResponse])
def list_dataset_versions(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List all dataset versions."""
    datasets = db.query(DatasetVersion).order_by(
        DatasetVersion.created_at.desc()
    ).offset(skip).limit(limit).all()
    return datasets


@router.get("/{dataset_id}", response_model=DatasetVersionResponse)
def get_dataset_version(
    dataset_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific dataset version by ID."""
    dataset = db.query(DatasetVersion).filter(
        DatasetVersion.id == dataset_id
    ).first()
    if not dataset:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dataset version not found"
        )
    return dataset


@router.get("/version/{version_number}", response_model=DatasetVersionResponse)
def get_dataset_by_version_number(
    version_number: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific dataset version by version number."""
    dataset = db.query(DatasetVersion).filter(
        DatasetVersion.version_number == version_number
    ).first()
    if not dataset:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dataset version not found"
        )
    return dataset


@router.get("/{dataset_id}/download")
def download_dataset(
    dataset_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Download a dataset ZIP containing only its selected recordings."""
    dataset = db.query(DatasetVersion).filter(
        DatasetVersion.id == dataset_id
    ).first()
    if not dataset:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dataset version not found"
        )
    
    export_config = dataset.export_config or {}
    recording_ids = export_config.get("recording_ids", [])
    if not isinstance(recording_ids, list) or not recording_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This dataset has no saved recording selections. Create a new dataset with recordings selected.",
        )

    recordings_by_id = {
        recording.id: recording
        for recording in db.query(Recording)
        .options(selectinload(Recording.orientation_frames))
        .filter(Recording.id.in_(recording_ids))
        .all()
    }
    recordings = [recordings_by_id[recording_id] for recording_id in recording_ids if recording_id in recordings_by_id]
    missing_ids = [recording_id for recording_id in recording_ids if recording_id not in recordings_by_id]
    unavailable_videos = [
        recording.file_name
        for recording in recordings
        if not (recording.file_url or recording.storage_path)
        or not _recording_video_available(recording)
    ]
    if missing_ids or unavailable_videos:
        problems = []
        if missing_ids:
            problems.append(f"recordings no longer exist: {', '.join(missing_ids)}")
        if unavailable_videos:
            problems.append(f"video files are missing: {', '.join(unavailable_videos)}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot export this dataset because " + "; ".join(problems),
        )
    details = (
        f"Dataset: {dataset.name}\nVersion: {dataset.version_number}\n"
        f"Description: {dataset.description or 'N/A'}\nCreated: {dataset.created_at}\n"
        f"Selected recordings: {len(recording_ids)}\n"
        f"Selected recording rows found: {len(recordings)}\n"
        "All selected video files were found."
    )
    safe_name = re.sub(r"[^A-Za-z0-9._-]", "_", f"{dataset.name}_{dataset.version_number}")
    # R2 reads and ZIP creation may take a while. Release the PostgreSQL
    # connection before doing that work so downloads do not starve API reads.
    db.close()
    return _zip_file_response(
        recordings,
        f"Dataset: {dataset.name} ({dataset.version_number})",
        details,
        f"{safe_name}.zip",
    )


@router.get("/recordings/download-all")
def download_all_recordings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Download all recordings as ZIP file."""
    recordings = db.query(Recording).options(
        selectinload(Recording.orientation_frames)
    ).all()
    db.close()
    return _zip_file_response(
        recordings,
        "All Recordings",
        f"Total recordings: {len(recordings)}",
        "all_recordings.zip",
    )
