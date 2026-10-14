# SignBridge Data Collection Tool

Cross-platform data collection system for USL (Ugandan Sign Language) video collection, supporting Android and Web/PC platforms with shared PostgreSQL metadata and Cloudflare R2 video storage.

## Architecture

### Cross-Platform Client (Flutter)
- **Android**: Primary field client using phone/tablet camera
- **Web**: PC client using built-in laptop camera or connected USB webcam
- **State Management**: Riverpod
- **Record Persistence**: FastAPI-backed PostgreSQL; authentication tokens use secure device storage
- **Video Storage**: Cloudflare R2, with direct app uploads using short-lived signed URLs

### Backend (FastAPI)
- **Framework**: FastAPI with Python
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy 2.x with Alembic migrations
- **Authentication**: JWT access + refresh tokens with RBAC
- **Storage**: Cloudflare R2 for durable videos and processed frame images

## Brand Colors

- Primary Background: `#12141C`
- Secondary Surface: `#1B1E2A`
- Gold: `#E8A93B`
- Teal: `#2FA0A0`
- Ivory: `#F3F1EA`

## Technology Stack

### Client
- Flutter/Dart
- Riverpod for state management
- Camera plugin for video capture
- Dio for HTTP requests
- flutter_secure_storage for secure token storage

### Backend
- Python 3.11+
- FastAPI
- PostgreSQL
- SQLAlchemy 2.x
- Alembic for migrations
- Pydantic for validation
- JWT for authentication

## Getting Started

### Prerequisites
- Flutter SDK (3.16+)
- Python 3.11+
- PostgreSQL 15+
- Docker (optional, for containerized deployment)

### Backend Setup

1. Navigate to backend directory:
```bash
cd backend
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. Start PostgreSQL database (using Docker Compose):
```bash
cd ..
docker-compose up -d postgres
```

6. Run database migrations:
```bash
cd backend
alembic upgrade head
```

7. Start the backend server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`
API documentation: `http://localhost:8000/docs`

### Client Setup

1. Navigate to client directory:
```bash
cd client
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run on Android:
```bash
flutter run -d android
```

For a physical Android phone, connect the phone and PC to the same Wi-Fi and
point the client at the PC's LAN address (not `localhost`). For example:
```bash
flutter run -d <device-id> --dart-define=SIGNBRIDGE_API_BASE_URL=http://<PC-LAN-IP>:8000/api/v1
```
The Android emulator uses `10.0.2.2` automatically when no API URL is defined.
Local HTTP is enabled only for Android debug builds; release builds should use
the deployed HTTPS API URL.

4. Run on Web:
```bash
flutter run -d chrome
```

## Collection Protocol

### Target Scope
- 10 adviser-approved signs
- Three complementary video samples per sign
- Venue: Makerere University / MUDSA
- Protocol: SignBridge USL collection protocol v2

### Recording Conditions
- **Lighting**: DAYLIGHT, INDOOR_ARTIFICIAL, LOW_LIGHT_DIM
- **Background**: PLAIN_WALL_LIGHT, PLAIN_WALL_DARK, TEXTURED_CLUTTERED

### Sign-language video collection protocol

SignBridge uses a project protocol informed by the [W3C sign-language recording guidance](https://www.w3.org/WAI/media/av/sign-languages/) and [UNICEF's sign-language recording guide](https://www.unicef.org/accessibletextbooksforall/stories/sign-language-recording-guide). These sources emphasize clear lighting and contrast, a fixed eye-level camera, and keeping the face, hands, and complete signing space visible. They do not prescribe one universal capture protocol for every sign language; a fluent Deaf Ugandan Sign Language adviser should review prompts and collection procedures before formal research collection.

Each sign has three frontal video samples:

1. `standard_frontal`: one isolated, natural performance.
2. `repeat_frontal`: one second, independent natural performance using the same camera position.
3. `contextual_utterance`: the sign in a short natural phrase or exchange, using a context/prompt agreed with a fluent USL signer. The prompt or concise context note is saved in recording remarks.

For all three, keep the camera fixed at eye level and frame the signer from below the waist to above the head, with room to both sides for the full signing space. Keep the face and both hands visible; use even light and clothing/background contrast. Sign at a natural pace with natural facial and body movement. The app does not instruct signers to turn their heads or bodies for camera-angle sweeps. Context prompts should be linguistically appropriate and reviewed by a fluent USL adviser. Historical `horizontal_sweep`, `vertical_sweep`, and `natural_performance` recordings remain readable as legacy records; they do not count as the new protocol's three samples.

After upload, the backend samples frames at 4 FPS by default, estimates head yaw/pitch, extracts face and hand landmarks, and stores JPEG frames plus labels. The Recordings screen shows processing status and processed frame count. Dataset ZIPs include the original videos, `metadata/recordings.json`, `metadata/orientation_frames.csv`, `metadata/landmarks.jsonl`, and extracted `frames/`.

Backend setup installs the pinned MediaPipe and OpenCV packages from `backend/requirements.txt`. The required Face Landmarker and Hand Landmarker task assets are included under `backend/models/`. Apply migrations before starting the API:

```bash
cd backend
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

For local verification, install `backend/requirements-dev.txt` and run `pytest` from `backend/`. `ORIENTATION_SAMPLE_FPS` can tune frame sampling; `FACE_LANDMARKER_MODEL` and `HAND_LANDMARKER_MODEL` can point to alternate compatible MediaPipe task models.

### Private Cloudflare R2 video storage

New videos upload directly from Flutter to a private Cloudflare R2 bucket using a short-lived presigned PUT URL. The backend reserves a unique staging key, verifies the uploaded object and size, then copies it to a permanent key under `recordings/YYYY/MM/{signer-id}/`. PostgreSQL stores that object path, verified MIME type, file size, and processing status; it does not store video bytes or a permanent download URL. Playback uses a temporary presigned GET URL issued after an authenticated SignBridge API request.

Orientation processing downloads the source video to temporary working storage, writes sampled JPEGs back to R2, and removes local copies. Dataset ZIP exports fetch source objects from R2 when there is no legacy local copy. R2 is the durable store; backend disk is a working cache only.

Copy `backend/.env.example` to `backend/.env`. Set `OBJECT_STORAGE_BUCKET`, `OBJECT_STORAGE_REGION=auto`, `OBJECT_STORAGE_ENDPOINT_URL=https://<ACCOUNT_ID>.r2.cloudflarestorage.com`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY`. Create an R2 API token limited to this bucket with object read/write permissions. Keep the secret only in the backend environment, never in Flutter. Apply migrations with `alembic upgrade head` before starting the API.

For hosted Web and Android builds, point the client at the deployed API using `--dart-define=SIGNBRIDGE_API_BASE_URL=https://<your-api-host>/api/v1`. The storage credentials remain backend-only.

For web uploads, configure R2 bucket CORS to allow `PUT` from the deployed SignBridge web origin (and localhost during development), and allow the `Content-Type` request header. Keep the bucket private and do not enable public `r2.dev` access. Add an object lifecycle rule to expire objects under `{OBJECT_STORAGE_PREFIX}/staging/` after one day so abandoned uploads do not consume the study quota. R2's current no-cost allowance includes 10 GB-month of Standard storage, request quotas, and free egress; usage above the allowance is billed. Monitor usage and set a budget alert. Failed transfers can be retried from the still-open review screen.

### Hosting deployment target

For the provider setup sequence and the exact credential destinations, see [docs/HOSTING_SETUP.md](docs/HOSTING_SETUP.md).

The deployment uses four services for separate jobs:

- **Cloudflare Pages:** static Flutter Web application (`client/build/web`).
- **Google Cloud Run:** FastAPI container. It honors Cloud Run's `PORT`, runs without the development reloader, and should scale to zero with a low maximum instance count for the study deployment.
- **Neon:** hosted PostgreSQL for users and relational metadata. Use the Neon pooled connection URL for the running API and the direct connection URL for one-off Alembic migrations.
- **Cloudflare R2:** private videos and extracted frame images. Video bytes are uploaded directly from the app to R2; they do not pass through Neon or need to be persisted on the API container.

Create a Neon PostgreSQL project and use the same database for both the migration step and Cloud Run. Set the following backend values in Cloud Run (store `DATABASE_URL`, `SECRET_KEY`, and R2 access keys as Google Secret Manager secrets):

```text
APP_ENV=production
DATABASE_URL=<Neon pooled PostgreSQL URL, with SSL required>
SECRET_KEY=<unique random value of at least 32 characters>
BACKEND_CORS_ORIGINS=["https://<your-pages-project>.pages.dev"]
OBJECT_STORAGE_BUCKET=<private R2 bucket name>
OBJECT_STORAGE_REGION=auto
OBJECT_STORAGE_ENDPOINT_URL=https://<account-id>.r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=<R2 access key secret>
AWS_SECRET_ACCESS_KEY=<R2 secret access key secret>
```

`APP_ENV=production` makes the API reject SQLite, the example JWT secret, missing R2 credentials, and localhost-only CORS settings at startup. Do not put database or R2 secrets in Flutter build arguments; the API URL is public configuration, but storage and database credentials must stay on the backend.

For a local migration run, put Neon’s **pooled** URL in `DATABASE_URL` and its **direct** URL in `MIGRATION_DATABASE_URL` in the ignored `backend/.env` file. Add the production `APP_ENV`, secret, R2, and CORS values there as well. The API uses `DATABASE_URL`; Alembic prefers `MIGRATION_DATABASE_URL` when it is set.

Run migrations **once against the target Neon database before deploying the API** from `backend/`:

```bash
alembic upgrade head
```

This applies the repository's migration chain through its current head. It changes the PostgreSQL schema; it does not copy old SQLite or other PostgreSQL users/data. Each database tracks its own applied revision in `alembic_version`, so always verify the Neon database itself after migration. Cloud Run uses Neon’s pooled URL to that same project. Do not run Alembic on every API container startup.

Build and publish the web client to Cloudflare Pages after the Cloud Run API URL is known:

```bash
cd client
flutter build web --release --dart-define=SIGNBRIDGE_API_BASE_URL=https://<cloud-run-service-url>/api/v1
npx wrangler pages deploy build/web --project-name=signbridge-web
```

Create the `signbridge-web` Pages project before the first deploy, and use its exact HTTPS origin in `BACKEND_CORS_ORIGINS` and the R2 bucket CORS rule. Android release builds must use the same `SIGNBRIDGE_API_BASE_URL` define. Never include database or R2 credentials in Flutter builds.

For local Docker Compose development, `docker compose up --build` now waits for PostgreSQL, runs `alembic upgrade head` in a one-shot migration container, and only then starts the API. It uses the Compose PostgreSQL service; running `alembic upgrade head` directly from the host instead uses `DATABASE_URL` loaded from `backend/.env`. The running app requires PostgreSQL in development and production; SQLite is allowed only when explicitly using `APP_ENV=test`.

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Refresh access token
- `GET /api/v1/auth/me` - Get current user

### Signers
- `GET /api/v1/signers` - List signers
- `POST /api/v1/signers` - Create signer
- `GET /api/v1/signers/{id}/consent` - Get consent
- `POST /api/v1/signers/{id}/consent` - Record consent

### Signs
- `GET /api/v1/signs` - List approved signs
- `POST /api/v1/signs` - Create sign (admin)

### Sessions
- `GET /api/v1/sessions` - List collection sessions
- `POST /api/v1/sessions` - Create session
- `PATCH /api/v1/sessions/{id}` - Update/complete session

### Recordings
- `GET /api/v1/recordings` - List recordings
- `POST /api/v1/recordings` - Create recording
- `GET /api/v1/recordings/{id}` - Get recording details
- `POST /api/v1/recordings/{id}/upload-url` - Reserve an object and issue a short-lived upload URL
- `POST /api/v1/recordings/{id}/complete-upload` - Verify and finalize an object upload
- `GET /api/v1/recordings/{id}/download-url` - Issue a short-lived playback URL
- `POST /api/v1/recordings/{id}/review` - Technical quality review
- `POST /api/v1/recordings/{id}/validation` - Sign correctness validation

### Coverage
- `GET /api/v1/coverage` - Overall coverage
- `GET /api/v1/coverage/signs/{id}` - Sign-specific coverage
- `GET /api/v1/coverage/orientations` - Preset/orientation coverage

### Sync
- `POST /api/v1/sync/push` - Push offline changes
- `POST /api/v1/sync/pull` - Pull server changes

### Export
- `POST /api/v1/exports` - Create dataset export
- `GET /api/v1/exports/{id}` - Get export status

### Health
- `GET /api/v1/health` - Health check

## Recording Upload Flow

1. SignBridge creates a pending metadata row through the authenticated API.
2. The API reserves a unique private R2 staging key and returns a short-lived presigned upload URL.
3. Flutter uploads the video bytes directly to R2; API credentials never reach the client.
4. The API verifies object existence, size, and MIME metadata, promotes it to its permanent key, then records the storage path in PostgreSQL.
5. Background processing reads a temporary copy from R2 and writes processed frame images back to R2.
6. Retries reuse the same recording ID and do not create duplicate metadata rows.

## Dataset Export Structure

```
SignBridge_Dataset_vX.Y/
├── videos/
│   ├── S001_HELLO_01.mp4
│   └── ...
├── metadata/
│   ├── recordings.csv
│   ├── recordings.json
│   ├── signers.csv
│   ├── signs.csv
│   └── validations.csv
├── manifest.json
└── README.txt
```

## Development Phases

The project follows a phased implementation approach where each phase includes:
- Client + Backend + Database/Storage + Tests
- Each phase must pass its gate before proceeding

Current Phase: **Phase 0 - Repository setup, architecture, and brand lock**

## Testing

### Backend Tests
```bash
cd backend
pytest
```

### Flutter Tests
```bash
cd client
flutter test
```

### Integration Tests
```bash
cd client
flutter test integration_test/
```

## Documentation

- Collection Protocol: `docs/collection_protocol_v1.md`
- Data Dictionary: `docs/data_dictionary.md`
- API Documentation: `docs/api.md`
- Deployment Guide: `docs/deployment.md`
- Backup/Restore: `docs/backup_restore.md`
- Test Plan: `docs/test_plan.md`

## License

Proprietary - SignBridge Project
