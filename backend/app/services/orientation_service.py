"""Sample uploaded videos and derive head orientation plus hand/face landmarks."""

from __future__ import annotations

import json
import math
import statistics
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python.core.base_options import BaseOptions
from mediapipe.tasks.python import vision
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.orientation_frame import OrientationFrame
from app.models.recording import Recording


class VideoProcessingError(RuntimeError):
    pass


def _euler_degrees(matrix: np.ndarray) -> tuple[float, float]:
    """Convert MediaPipe's facial transform into yaw and pitch in degrees."""
    transform = np.asarray(matrix, dtype=float).reshape(4, 4)
    rotation = transform[:3, :3]
    yaw = math.degrees(math.atan2(-rotation[2, 0], math.hypot(rotation[0, 0], rotation[1, 0])))
    pitch = math.degrees(math.atan2(rotation[2, 1], rotation[2, 2]))
    return yaw, pitch


def _angle_bin(angle: float, negative: str, positive: str) -> str:
    magnitude = abs(angle)
    if magnitude <= 1:
        return "front"
    band = 15 if magnitude <= 15 else 30 if magnitude <= 30 else 45 if magnitude <= 45 else "over_45"
    direction = negative if angle < 0 else positive
    return f"{direction}_{band}"


def _orientation_label(capture_format: str | None, yaw: float | None, pitch: float | None) -> str:
    if capture_format == "vertical_sweep":
        if pitch is None:
            return "unclassified"
        return _angle_bin(pitch, "down", "up")
    if yaw is None:
        return "unclassified"
    return _angle_bin(yaw, "left", "right")


def _markers(recording: Recording) -> list[dict]:
    value = recording.cue_markers or []
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return []
    return sorted(
        [marker for marker in value if isinstance(marker, dict) and (
            isinstance(marker.get("timestamp_ms"), (int, float))
            or isinstance(marker.get("elapsed_seconds"), (int, float))
        )],
        key=lambda marker: marker.get("timestamp_ms", float(marker.get("elapsed_seconds", 0)) * 1000),
    )


def _marker_axis_sign(samples: list[dict], markers: list[dict], target: str, angle_key: str) -> float | None:
    """Use the guided, known direction to compensate for mirrored camera matrices."""
    hits: list[float] = []
    for index, marker in enumerate(markers):
        if marker.get("orientation_target") != target:
            continue
        start_ms = float(marker.get("timestamp_ms", float(marker.get("elapsed_seconds", 0)) * 1000))
        end_ms = float(markers[index + 1].get(
            "timestamp_ms", float(markers[index + 1].get("elapsed_seconds", 0)) * 1000
        )) if index + 1 < len(markers) else start_ms + 4000
        values = [sample[angle_key] for sample in samples if start_ms <= sample["timestamp_ms"] <= end_ms and sample[angle_key] is not None]
        if values:
            hits.append(statistics.median(values))
    if not hits:
        return None
    direction = statistics.median(hits)
    expected_sign = -1.0 if target == "turn_left_45" else 1.0
    return expected_sign if direction >= 0 else -expected_sign


def process_recording(db: Session, recording: Recording, video_path: Path, uploads_dir: Path) -> int:
    """Create a sampled frame and landmark row for an uploaded recording."""
    face_model = Path(settings.FACE_LANDMARKER_MODEL)
    hand_model = Path(settings.HAND_LANDMARKER_MODEL)
    if not face_model.is_absolute():
        face_model = Path(__file__).resolve().parents[2] / face_model
    if not hand_model.is_absolute():
        hand_model = Path(__file__).resolve().parents[2] / hand_model
    if not face_model.is_file() or not hand_model.is_file():
        raise VideoProcessingError("MediaPipe face/hand model files are missing; run the backend model setup step.")

    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise VideoProcessingError("The uploaded video could not be decoded. Check its codec and file integrity.")
    fps = capture.get(cv2.CAP_PROP_FPS) or 0
    stride = max(1, round(fps / max(0.2, settings.ORIENTATION_SAMPLE_FPS))) if fps > 0 else 6
    samples: list[dict] = []
    frame_number = 0
    face_options = vision.FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(face_model)),
        running_mode=vision.RunningMode.IMAGE,
        num_faces=1,
        output_facial_transformation_matrixes=True,
    )
    hand_options = vision.HandLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(hand_model)),
        running_mode=vision.RunningMode.IMAGE,
        num_hands=2,
    )
    try:
        with vision.FaceLandmarker.create_from_options(face_options) as face_detector, \
                vision.HandLandmarker.create_from_options(hand_options) as hand_detector:
            while True:
                ok, frame = capture.read()
                if not ok:
                    break
                if frame_number % stride == 0:
                    timestamp_ms = int(capture.get(cv2.CAP_PROP_POS_MSEC))
                    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                    face_result = face_detector.detect(image)
                    hand_result = hand_detector.detect(image)
                    yaw = pitch = None
                    face_points = None
                    if face_result.face_landmarks:
                        face_points = [
                            [round(float(point.x), 6), round(float(point.y), 6), round(float(point.z), 6)]
                            for point in face_result.face_landmarks[0]
                        ]
                    if face_result.facial_transformation_matrixes:
                        yaw, pitch = _euler_degrees(face_result.facial_transformation_matrixes[0])
                    hands = []
                    for hand_index, points in enumerate(hand_result.hand_landmarks):
                        handedness = "unknown"
                        if hand_result.handedness and hand_index < len(hand_result.handedness):
                            categories = hand_result.handedness[hand_index]
                            if categories:
                                handedness = categories[0].category_name
                        hands.append({
                            "handedness": handedness,
                            "landmarks": [[round(float(point.x), 6), round(float(point.y), 6), round(float(point.z), 6)] for point in points],
                        })
                    ok, encoded = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 88])
                    if not ok:
                        raise VideoProcessingError("A sampled frame could not be encoded as JPEG.")
                    samples.append({
                        "timestamp_ms": timestamp_ms,
                        "yaw": yaw,
                        "pitch": pitch,
                        "face_landmarks": face_points,
                        "hand_landmarks": hands,
                        "jpeg": encoded.tobytes(),
                    })
                frame_number += 1
    finally:
        capture.release()

    if not samples:
        raise VideoProcessingError("No frames could be read from the uploaded video.")
    faces_detected = sum(sample["face_landmarks"] is not None for sample in samples)
    if faces_detected == 0:
        raise VideoProcessingError(
            "No signer face was detected. Check that the signer is visible, facing the camera, and well lit, then retake the video."
        )

    # Calibrate against the initial neutral/rest period when present. This
    # keeps face-angle labels relative to the signer without prompting them to
    # turn their head or body during sign-language capture.
    initial = [sample for sample in samples if sample["timestamp_ms"] <= 1000]
    for axis in ("yaw", "pitch"):
        values = [sample[axis] for sample in initial if sample[axis] is not None]
        baseline = statistics.median(values) if values else 0.0
        for sample in samples:
            if sample[axis] is not None:
                sample[axis] -= baseline

    markers = _markers(recording)
    yaw_sign = _marker_axis_sign(samples, markers, "turn_left_45", "yaw")
    pitch_sign = _marker_axis_sign(samples, markers, "look_up", "pitch")
    if yaw_sign is None:
        yaw_sign = 1.0
    if pitch_sign is None:
        pitch_sign = 1.0

    output_dir = uploads_dir / "processed" / recording.id
    output_dir.mkdir(parents=True, exist_ok=True)
    db.query(OrientationFrame).filter(OrientationFrame.recording_id == recording.id).delete(synchronize_session=False)
    for frame_index, sample in enumerate(samples):
        yaw = sample["yaw"] * yaw_sign if sample["yaw"] is not None else None
        pitch = sample["pitch"] * pitch_sign if sample["pitch"] is not None else None
        label = _orientation_label(recording.capture_format, yaw, pitch)
        image_name = f"frame_{frame_index:06d}.jpg"
        (output_dir / image_name).write_bytes(sample["jpeg"])
        db.add(OrientationFrame(
            recording_id=recording.id,
            frame_index=frame_index,
            timestamp_ms=sample["timestamp_ms"],
            yaw_degrees=round(yaw, 2) if yaw is not None else None,
            pitch_degrees=round(pitch, 2) if pitch is not None else None,
            orientation_label=label,
            face_landmarks=sample["face_landmarks"],
            hand_landmarks=sample["hand_landmarks"],
            image_url=f"/uploads/processed/{recording.id}/{image_name}",
        ))
    recording.processed_frame_count = len(samples)
    recording.orientation_error = None
    db.commit()
    return len(samples)
