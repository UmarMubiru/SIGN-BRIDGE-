from pathlib import Path
from types import SimpleNamespace
from zipfile import ZipFile
import io

import cv2
import numpy as np

from app.services.orientation_service import (
    _angle_bin,
    _euler_degrees,
    _marker_axis_sign,
    _orientation_label,
    process_recording,
)
from app.api.v1 import datasets
from app.core.config import settings
from app.services import object_storage_service


class _Query:
    def filter(self, *_args):
        return self

    def delete(self, **_kwargs):
        return 0


class _Session:
    def __init__(self):
        self.frames = []

    def query(self, _model):
        return _Query()

    def add(self, frame):
        self.frames.append(frame)

    def commit(self):
        pass


def test_orientation_zones_match_protocol_boundaries():
    assert _angle_bin(0.8, "left", "right") == "front"
    assert _angle_bin(-1.1, "left", "right") == "left_15"
    assert _angle_bin(-16, "left", "right") == "left_30"
    assert _angle_bin(-31, "left", "right") == "left_45"
    assert _angle_bin(46, "left", "right") == "right_over_45"
    assert _orientation_label("vertical_sweep", None, 22) == "up_30"


def test_rotation_matrix_converts_to_yaw_and_pitch():
    yaw, pitch = np.deg2rad(30), np.deg2rad(-12)
    ry = np.array([[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]])
    rx = np.array([[1, 0, 0], [0, np.cos(pitch), -np.sin(pitch)], [0, np.sin(pitch), np.cos(pitch)]])
    transform = np.eye(4)
    transform[:3, :3] = ry @ rx
    actual_yaw, actual_pitch = _euler_degrees(transform)
    assert abs(actual_yaw - 30) < 0.1
    assert abs(actual_pitch + 12) < 0.1


def test_guided_targets_correct_for_camera_mirroring():
    markers = [{"orientation_target": "turn_left_45", "timestamp_ms": 0},
               {"orientation_target": "return_center", "timestamp_ms": 1000}]
    positive_camera_yaw = [{"timestamp_ms": 200, "yaw": 32}]
    negative_camera_yaw = [{"timestamp_ms": 200, "yaw": -32}]
    assert _marker_axis_sign(positive_camera_yaw, markers, "turn_left_45", "yaw") == -1
    assert _marker_axis_sign(negative_camera_yaw, markers, "turn_left_45", "yaw") == 1


def test_uploaded_video_is_sampled_and_written_with_landmark_rows(tmp_path):
    video_path = tmp_path / "sweep.mp4"
    portrait = cv2.imread(str(Path(__file__).parent / "fixtures" / "mediapipe-portrait.jpg"))
    height, width = portrait.shape[:2]
    writer = cv2.VideoWriter(str(video_path), cv2.VideoWriter_fourcc(*"mp4v"), 10, (width, height))
    assert writer.isOpened(), "OpenCV MP4 encoding is required by the processing pipeline"
    for frame_index in range(20):
        writer.write(portrait)
    writer.release()

    recording = SimpleNamespace(
        id="smoke-recording",
        capture_format="horizontal_sweep",
        cue_markers=[{"orientation_target": "turn_left_45", "timestamp_ms": 500}],
        processed_frame_count=0,
        orientation_error=None,
    )
    db = _Session()
    frame_count = process_recording(db, recording, video_path, tmp_path / "uploads")

    assert frame_count >= 6
    assert recording.processed_frame_count == frame_count
    assert len(db.frames) == frame_count
    assert all(frame.orientation_label == "front" for frame in db.frames)
    assert all(len(frame.face_landmarks) == 478 for frame in db.frames)
    assert (tmp_path / "uploads" / "processed" / recording.id / "frame_000000.jpg").is_file()


def test_video_without_a_signer_face_is_rejected_by_processing(tmp_path):
    from app.services.orientation_service import VideoProcessingError

    video_path = tmp_path / "empty.mp4"
    writer = cv2.VideoWriter(str(video_path), cv2.VideoWriter_fourcc(*"mp4v"), 10, (96, 96))
    assert writer.isOpened()
    for _ in range(20):
        writer.write(np.zeros((96, 96, 3), dtype=np.uint8))
    writer.release()
    recording = SimpleNamespace(
        id="no-face-recording",
        capture_format="horizontal_sweep",
        cue_markers=[],
        processed_frame_count=0,
        orientation_error=None,
    )

    try:
        process_recording(_Session(), recording, video_path, tmp_path / "uploads")
        assert False, "Videos without a detected face must not be marked as successfully processed"
    except VideoProcessingError as error:
        assert "No signer face was detected" in str(error)


def test_dataset_export_contains_frames_labels_and_landmarks(tmp_path, monkeypatch):
    upload_dir = tmp_path / "uploads"
    frame_dir = upload_dir / "processed" / "rec-1"
    frame_dir.mkdir(parents=True)
    (upload_dir / "clip.mp4").write_bytes(b"video")
    (frame_dir / "frame_000000.jpg").write_bytes(b"jpeg")
    monkeypatch.setattr(datasets, "UPLOAD_DIR", upload_dir)
    frame = SimpleNamespace(
        image_url="/uploads/processed/rec-1/frame_000000.jpg",
        frame_index=0,
        timestamp_ms=250,
        yaw_degrees=-16.2,
        pitch_degrees=1.2,
        orientation_label="left_30",
        face_landmarks=[[0.5, 0.5, 0.0]],
        hand_landmarks=[{"handedness": "Right", "landmarks": []}],
    )
    recording = SimpleNamespace(
        validation_status=SimpleNamespace(value="approved"),
        file_name="hello.mp4",
        capture_format="horizontal_sweep",
        repetition_no=1,
        file_url="/uploads/clip.mp4",
        mime_type="video/mp4",
        file_size=5,
        public_id="pub-1",
        id="rec-1",
        session_id="session-1",
        signer_id="signer-1",
        sign_id="sign-1",
        cue_markers=[{"timestamp_ms": 0, "orientation_target": "center"}],
        orientation_status="completed",
        processed_frame_count=1,
        cloud_storage_status="uploaded",
        storage_path="signbridge/videos/hello.mp4",
        orientation_frames=[frame],
    )

    payload = datasets._recordings_zip([recording], "test dataset")
    with ZipFile(io.BytesIO(payload)) as archive:
        names = set(archive.namelist())
        assert "frames/rec-1/frame_000000.jpg" in names
        assert "metadata/orientation_frames.csv" in names
        assert "metadata/landmarks.jsonl" in names
        assert b"left_30" in archive.read("metadata/orientation_frames.csv")
        assert b"handedness" in archive.read("metadata/landmarks.jsonl")


def test_api_exposes_upload_and_sampled_frames_routes():
    from app.main import app

    paths = app.openapi()["paths"]
    assert any(path.endswith("/recordings/{recording_id}/upload-url") and "post" in operations for path, operations in paths.items())
    assert any(path.endswith("/recordings/{recording_id}/complete-upload") and "post" in operations for path, operations in paths.items())
    assert any(path.endswith("/recordings/{recording_id}/upload-failed") and "post" in operations for path, operations in paths.items())
    assert any(path.endswith("/recordings/{recording_id}/upload-proxy") and "post" in operations for path, operations in paths.items())
    assert any(path.endswith("/recordings/{recording_id}/download-url") and "get" in operations for path, operations in paths.items())
    assert any(path.endswith("/recordings/{recording_id}/frames") and "get" in operations for path, operations in paths.items())
    assert not any(path.endswith("/recordings/{recording_id}/cloud-sync") for path in paths)


def test_recording_response_exposes_persisted_storage_path():
    from datetime import datetime
    from app.models.recording import Recording, RecordingStatus, ValidationStatus
    from app.schemas.recording import RecordingResponse

    recording = Recording(
        id="rec-path-test",
        public_id="public-path-test",
        client_id="client-path-test",
        session_id="session-test",
        signer_id="signer-test",
        sign_id="sign-test",
        repetition_no=1,
        capture_format="horizontal_sweep",
        cue_markers=[],
        camera_angle="Horizontal Sweep",
        lighting_condition="Daylight",
        background="Plain Wall",
        file_name="hello.webm",
        recording_status=RecordingStatus.UPLOADED,
        validation_status=ValidationStatus.PENDING,
        orientation_status="pending",
        processed_frame_count=0,
        cloud_storage_status="uploaded",
        storage_path="signbridge/recordings/2026/10/signer/hello.webm",
        file_url="signbridge/recordings/2026/10/signer/hello.webm",
        created_at=datetime.now(),
    )

    response = RecordingResponse.model_validate(recording)
    assert response.storage_path == "signbridge/recordings/2026/10/signer/hello.webm"
    assert response.cloud_object_key == response.storage_path


def test_object_storage_issues_short_lived_direct_upload_url(monkeypatch):
    observed = {}

    class FakeS3:
        def generate_presigned_url(self, operation, Params, ExpiresIn):
            observed.update(operation=operation, params=Params, expires=ExpiresIn)
            return "https://r2.example.test/presigned"

    monkeypatch.setattr(settings, "OBJECT_STORAGE_BUCKET", "signbridge-test")
    monkeypatch.setattr(settings, "OBJECT_STORAGE_ENDPOINT_URL", "https://s3.example.test")
    monkeypatch.setattr(settings, "AWS_ACCESS_KEY_ID", "access-key")
    monkeypatch.setattr(settings, "AWS_SECRET_ACCESS_KEY", "secret-key")
    monkeypatch.setattr(object_storage_service.boto3, "client", lambda *_args, **_kwargs: FakeS3())
    url = object_storage_service.presign_upload(
        "signbridge/staging/key.webm", "video/webm"
    )

    assert url.endswith("presigned")
    assert observed["operation"] == "put_object"
    assert observed["params"] == {
        "Bucket": "signbridge-test",
        "Key": "signbridge/staging/key.webm",
        "ContentType": "video/webm",
    }
    assert observed["expires"] == 900
