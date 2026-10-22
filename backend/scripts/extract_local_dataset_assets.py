"""Extract sampled JPG frames and MediaPipe landmarks for local ZIP exports."""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path

import cv2
import mediapipe as mp
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions


def _yaw_pitch(matrix: object) -> tuple[float | None, float | None]:
    if matrix is None:
        return None, None
    values = [float(value) for row in matrix for value in row]
    yaw = math.degrees(math.atan2(-values[8], math.hypot(values[0], values[4])))
    pitch = math.degrees(math.atan2(values[9], values[10]))
    return yaw, pitch


def _points(points: object) -> list[list[float]] | None:
    if not points:
        return None
    return [[round(float(p.x), 6), round(float(p.y), 6), round(float(p.z), 6)] for p in points]


def _progress(
    processed: int,
    total: int,
    recording_index: int,
    recording_count: int,
    file_name: str,
) -> None:
    print(json.dumps({
        "stage": "extractingFrames",
        "processedFrames": processed,
        "totalFrames": total,
        "recordingIndex": recording_index,
        "recordingCount": recording_count,
        "fileName": file_name,
    }), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--recordings-json", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--face-model", required=True, type=Path)
    parser.add_argument("--hand-model", required=True, type=Path)
    parser.add_argument("--sample-fps", type=float, default=1.0)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    frame_rows: list[dict[str, object]] = []
    landmark_rows: list[dict[str, object]] = []
    face_options = vision.FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(args.face_model)),
        running_mode=vision.RunningMode.IMAGE,
        num_faces=1,
        output_facial_transformation_matrixes=True,
    )
    hand_options = vision.HandLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(args.hand_model)),
        running_mode=vision.RunningMode.IMAGE,
        num_hands=2,
    )

    with args.recordings_json.open(encoding="utf-8") as source:
        recordings = json.load(source)

    plans = []
    total_frames = 0
    for recording in recordings:
        video_path = Path(recording["video_path"])
        capture = cv2.VideoCapture(str(video_path))
        if not capture.isOpened():
            raise RuntimeError(f"Could not decode video {video_path.name}.")
        fps = capture.get(cv2.CAP_PROP_FPS) or 0
        frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        stride = max(1, round(fps / max(0.1, args.sample_fps))) if fps > 0 else 6
        expected_samples = math.ceil(frame_count / stride) if frame_count > 0 else 0
        capture.release()
        plans.append((recording, stride, expected_samples))
        total_frames += expected_samples

    processed_frames = 0
    _progress(0, total_frames, 0, len(plans), "")

    with vision.FaceLandmarker.create_from_options(face_options) as face_detector, \
            vision.HandLandmarker.create_from_options(hand_options) as hand_detector:
        for recording_index, (recording, stride, _) in enumerate(plans, start=1):
            recording_id = str(recording["recording_id"])
            video_path = Path(recording["video_path"])
            capture = cv2.VideoCapture(str(video_path))
            if not capture.isOpened():
                raise RuntimeError(f"Could not decode video {video_path.name}.")
            output_dir = args.output_dir / "frames" / recording_id
            output_dir.mkdir(parents=True, exist_ok=True)
            frame_number = 0
            sample_index = 0
            try:
                while True:
                    ok, frame = capture.read()
                    if not ok:
                        break
                    if frame_number % stride == 0:
                        timestamp_ms = int(capture.get(cv2.CAP_PROP_POS_MSEC))
                        image = mp.Image(
                            image_format=mp.ImageFormat.SRGB,
                            data=cv2.cvtColor(frame, cv2.COLOR_BGR2RGB),
                        )
                        face_result = face_detector.detect(image)
                        hand_result = hand_detector.detect(image)
                        face_landmarks = (
                            _points(face_result.face_landmarks[0])
                            if face_result.face_landmarks
                            else None
                        )
                        matrix = (
                            face_result.facial_transformation_matrixes[0]
                            if face_result.facial_transformation_matrixes
                            else None
                        )
                        yaw, pitch = _yaw_pitch(matrix) if matrix is not None else (None, None)
                        hands = []
                        for index, points in enumerate(hand_result.hand_landmarks):
                            categories = hand_result.handedness[index] if index < len(hand_result.handedness) else []
                            handedness = categories[0].category_name if categories else "unknown"
                            hands.append({"handedness": handedness, "landmarks": _points(points) or []})

                        frame_name = f"frame_{sample_index:06d}.jpg"
                        frame_path = output_dir / frame_name
                        if not cv2.imwrite(str(frame_path), frame, [cv2.IMWRITE_JPEG_QUALITY, 88]):
                            raise RuntimeError(f"Could not write extracted frame {frame_name}.")
                        image_path = f"frames/{recording_id}/{frame_name}"
                        row = {
                            "recording_id": recording_id,
                            "file_name": video_path.name,
                            "frame_index": sample_index,
                            "timestamp_ms": timestamp_ms,
                            "yaw_degrees": round(yaw, 2) if yaw is not None else "",
                            "pitch_degrees": round(pitch, 2) if pitch is not None else "",
                            "orientation_label": "unclassified",
                            "image_path": image_path,
                        }
                        frame_rows.append(row)
                        landmark_rows.append({
                            "recording_id": recording_id,
                            "frame_index": sample_index,
                            "timestamp_ms": timestamp_ms,
                            "face_landmarks": face_landmarks,
                            "hand_landmarks": hands,
                        })
                        sample_index += 1
                        processed_frames += 1
                        _progress(
                            processed_frames,
                            total_frames,
                            recording_index,
                            len(plans),
                            video_path.name,
                        )
                    frame_number += 1
            finally:
                capture.release()
            if sample_index == 0:
                raise RuntimeError(f"No frames could be read from {video_path.name}.")

    csv_path = args.output_dir / "orientation_frames.csv"
    columns = [
        "recording_id", "file_name", "frame_index", "timestamp_ms", "yaw_degrees",
        "pitch_degrees", "orientation_label", "image_path",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=columns)
        writer.writeheader()
        writer.writerows(frame_rows)
    jsonl_path = args.output_dir / "landmarks.jsonl"
    with jsonl_path.open("w", encoding="utf-8", newline="\n") as target:
        for row in landmark_rows:
            target.write(json.dumps(row, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
