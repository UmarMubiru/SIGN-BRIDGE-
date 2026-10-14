# MediaPipe task models

These assets are used by `app/services/orientation_service.py` after recording upload:

- `face_landmarker.task` estimates face mesh and head transform.
- `hand_landmarker.task` extracts hand keypoints.

Source downloads:

- https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
- https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task

The files are stored here so local and Docker deployments work without downloading model weights at API startup. MediaPipe is distributed under Apache 2.0; see https://github.com/google-ai-edge/mediapipe/blob/master/LICENSE.
