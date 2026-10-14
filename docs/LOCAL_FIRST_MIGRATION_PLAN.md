# SignBridge Local-First Migration Plan

**Status:** Repository audit complete; implementation not started.  
**Goal:** Make Windows collection work without a hosted API or cloud video storage, then add Android offline collection and dataset consolidation without losing the current cloud implementation.

## Recommendation

Proceed in phases, beginning with a Windows local-collection proof of concept. Keep the current Flutter Web/Android + FastAPI + Neon + R2 implementation intact until the local workflow passes its acceptance checks. Do not point the new local application at the existing Neon database or delete the existing R2 objects as part of this work.

For Windows Phase 1, first validate a **local FastAPI sidecar**: the Flutter Windows app talks to a FastAPI process bound only to `127.0.0.1`; that process uses a workspace-local SQLite database, local video/frame files, and the existing Python OpenCV/MediaPipe processor. This offers the best chance of retaining the existing REST client, backend validation, SQLAlchemy models, Python processing, and ZIP export code. It still requires a supported Windows camera plugin, a safe SQLite schema/migration path, and a distributable way to start and stop the Python process.

Treat that sidecar as a short technical spike, not an assumption. If SQLite portability or bundling the Python service proves too costly, compare it with a Flutter-native SQLite repository before building the full workflow. Do not attempt both implementations in parallel.

## Repository audit

### Work to retain

| Existing area | Reuse in local-first work |
| --- | --- |
| `client/lib/features/` | Existing auth, signer, sign, session, coverage, recording, review, records, and dataset screens as presentation starting points. Screens currently call the remote API, so retain their layouts while changing the data boundary. |
| `client/lib/core/constants/recording_protocol.dart` | Current three-format capture protocol and legacy format labels. Keep this as the protocol source of truth. |
| `client/lib/core/recording/` and recording/review models | Capture context, filenames, review rules, and status concepts, after checking which concepts need to be persisted locally. |
| `backend/app/models/` | Existing domain fields and relationships for users, signers, consent, signs and versions, sessions, recordings, frames, dataset versions, and activity. Use these as the local schema reference. |
| `backend/app/repositories/` and `backend/app/services/` | Existing validation and business rules where they are storage-provider independent. Separate those rules from PostgreSQL and R2 assumptions. |
| `backend/app/services/orientation_service.py` and `backend/models/*.task` | Python OpenCV/MediaPipe processing and its face/hand model assets for the Windows local processor. |
| `backend/app/api/v1/datasets.py` | ZIP export structure and metadata serialization as a starting point for a portable dataset bundle. |
| `backend/scripts/create_admin.py` | Possible basis for a local workspace owner setup; decide local identity behavior separately from the deferred hosted trusted-admin step. |

### Work that is currently cloud-dependent

- `client/lib/core/api_client.dart` is the Flutter app's data and workflow boundary. It makes HTTP calls for authentication, users, signers/consent, signs, sessions, recordings, reviews/validation, datasets, and activity. Local mode needs to redirect this boundary to a local service or replace it with local repositories.
- `backend/app/core/config.py` and `backend/app/core/database.py` currently require PostgreSQL in normal development and production. SQLite is explicitly test-only.
- No verified local SQLite migration path exists. The existing migration history includes raw DDL and data-repair SQL, so its behavior on SQLite must be proven before reuse. Local storage needs a tested schema/bootstrap and versioned upgrade plan; do not run the existing migration chain against a workspace SQLite file by assumption.
- `backend/app/services/object_storage_service.py` implements R2, presigned upload/download, object promotion, and cloud deletion. Local mode needs a filesystem storage adapter and must not expose R2 credentials to Flutter.
- `backend/app/api/v1/recordings.py` starts MediaPipe processing through FastAPI `BackgroundTasks`. That is not a durable queue. Local mode must recover queued or interrupted work after a process restart.
- `backend/app/api/v1/datasets.py` reads local paths for legacy files and downloads R2 objects for current cloud files. Local export/import should use workspace-relative paths and verify that referenced files exist.

### Client platform and persistence findings

- The Flutter `windows/` runner scaffold exists, but `client/pubspec.yaml` includes `camera` and `camera_web`, not a Windows camera implementation. Windows camera capture must be proven with a supported plugin or native integration before promising parity.
- Android recording currently writes the captured file under the app documents directory, then follows the server/API workflow. It is not an offline-first metadata workflow today.
- The Web camera path reads the completed recording into a `Uint8List` in memory. That is unsuitable as the foundation for arbitrary-size local workspaces and should remain a connected-client path, not the Windows local-first target.
- `path_provider` is present. No Flutter SQLite package or local repository/database layer is present in `pubspec.yaml`.
- The current Python processor samples at a configurable 4 FPS by default and stores video files outside the database. Preserve that model. Do not put video bytes in SQLite.

## Target workspace and data rules

Each Windows workspace is a user-selected root folder with a versioned structure, for example:

```text
SignBridge_Workspace/
  workspace.json
  database.sqlite3
  videos/<recording-id>/<original-filename>
  frames/<recording-id>/<frame-index>.jpg
  exports/
  logs/
  backups/
```

The exact paths can change during implementation, but these rules should not:

1. Use stable UUIDs for workspace, signer, session, sign, recording, and frame identities. Filenames are labels, not primary keys.
2. Store normalized file paths relative to the workspace root; reject paths that escape that root during import or playback.
3. Save a capture to a temporary filename, close it, verify it exists and has non-zero size, compute its checksum, then atomically move it into its final path before marking it saved/approved.
4. Keep explicit recording and processing states. A restart must make `processing` work recoverable, not permanently stuck.
5. Delete a video and its derived frames as a coordinated operation. If metadata removal or file deletion fails, report the partial result and allow repair; never silently leave a broken approved record.
6. Include a manifest with schema/protocol version, stable IDs, relative paths, sizes, SHA-256 checksums, and metadata. Imports must validate all of these before changing the destination workspace.
7. On duplicate ID, do not overwrite. Offer skip, import-as-copy with a new ID, or stop and report the conflict. Record the decision in the import report.
8. Backups must copy a consistent database snapshot plus its referenced files. Warn on low disk space and show the most recent successful backup time.

The current capture protocol should be preserved as written in `recording_protocol.dart`: `standard_frontal`, `repeat_frontal`, and `contextual_utterance`. The older horizontal/vertical sweep values remain readable as legacy formats; they should not silently become the new protocol.

## Phased implementation

### Phase 0 — Windows feasibility spike

1. Select and validate Windows camera support against the existing capture/review UI on the actual Windows 11 laptop and webcam. Check video path behavior, camera disposal, device selection, and the existing capture protocol.
2. Prototype starting a local Python API process from the Flutter Windows app, binding only to loopback and shutting it down cleanly. Confirm its packaged runtime can import FastAPI, SQLAlchemy, OpenCV, MediaPipe, and the bundled model assets.
3. Build a fresh SQLite schema from the existing model/domain reference without using the PostgreSQL Alembic history. Check enums, JSON fields, foreign keys/cascades, and concurrent access.
4. Make one recording end to end: write video to the workspace, persist its metadata, process it, save frame/landmark outputs, close/reopen the app, and export it.

**Gate:** Continue with the sidecar only if the camera and packaging work on the target machine and SQLite can represent the needed model cleanly. Otherwise, revise the architecture before broad UI changes.

### Phase 1 — Windows local collection

1. Add a workspace selector/creator and workspace schema version.
2. Add a storage abstraction with local filesystem and current R2 implementations kept separate. Local mode must never call R2 or require network credentials.
3. Add local API/repository behavior for local identity, signers/consent, signs, sessions, recordings, review/validation, processing status, and dataset export.
4. Reuse the existing Flutter screens through the local service boundary where practical; avoid duplicating business rules in widgets.
5. Replace in-process fire-and-forget processing with a local recoverable worker. Use one processing job at a time initially; persist job state and reclaim stale work on startup.
6. Implement safe capture finalization, playback, retake, approval, recording/dataset deletion, disk-space warnings, and workspace backup.
7. Implement a portable export bundle and a validator/import preview. Phase 1 can export; import is required before Phase 3 consolidation.

**Acceptance:** A collector can create a workspace, create signer/session records, capture and review video, approve/save it, process it, close/reopen the app, play it back, delete it with its derived outputs, and export a valid bundle while offline. Interrupted capture/processing and a missing video produce recoverable, visible states.

### Phase 2 — Android offline collection

1. Add an Android-local metadata store and workspace/export model; do not assume Android's private app directory is a user-managed folder.
2. Save recordings and metadata locally before offering any network action. A network failure must not discard a completed recording.
3. Implement a retryable export/share flow using the same manifest and bundle format as Windows.
4. Start with capture, review, local metadata, and export. Treat on-device MediaPipe as a separate feasibility item: the current Python processing service is not available in the Flutter app. Add Android inference only after choosing and testing a native MediaPipe integration against the current model outputs.

**Acceptance:** Android can complete and retain a recording offline, restart without losing its metadata, export the bundle, and import/export round-trip with the Windows validator without ID collisions or broken file paths.

### Phase 3 — Dataset consolidation

Build a local consolidation workflow that previews imports, validates protocol/schema versions, checks files and hashes, reports duplicate IDs and conflicting metadata, and never silently overwrites. Produce a consolidated dataset with provenance linking each recording to its source workspace/export and collector.

**Acceptance:** Importing the same bundle twice is safe and produces an explicit duplicate report; a corrupted/missing file is rejected or quarantined without partially corrupting the destination; a successful consolidation exports a verifiable dataset bundle.

### Phase 4 — Optional distribution and sync

Use a static site for instructions and download links if useful. Cloudflare Pages Free has a 25 MiB per-file asset limit, so host larger installers through GitHub Releases or another deliberate file host. Keep R2/Neon/API synchronization optional and out of the local core. If remote sync is later added, define conflict resolution, consent/access rules, deletion propagation, audit logging, and backups first.

## Data retention and transition

- Keep the current cloud code and provider resources unchanged throughout local development. Do not run local migrations on Neon.
- The new workspace format is a separate data store; it is not an automatic migration of the existing Neon database or R2 objects.
- Before any cloud retirement decision, export and verify existing records and videos, then document what is retained and who can access it.
- Do not put real research recordings into the new workflow until capture finalization, backup/restore, interrupted-job recovery, and export validation pass on the target devices.

## Main risks and decisions

| Risk/decision | Current view | Mitigation/gate |
| --- | --- | --- |
| Windows webcam implementation | Not included in the declared Flutter camera dependencies. | Feasibility spike on the target laptop before UI migration. |
| Local SQLite compatibility | Existing runtime forbids SQLite outside tests and PostgreSQL migrations include raw SQL. | New local schema/migration path; keep hosted migration chain separate. |
| Python sidecar installation | Retains processing code but adds packaging, process lifecycle, and localhost security work. | Prototype bundling and startup first; bind to loopback; use an unprivileged local process. |
| Processing interruptions | Current API starts work in-process without a durable queue. | Persistent job states, single worker, startup recovery, idempotent outputs. |
| Android local processing | No MediaPipe inference implementation exists in Flutter. | Make offline capture/export the first Android target; evaluate inference separately. |
| Loss of device/workspace | Local-first has no automatic central copy. | Encrypted, verified backups and export reminders; document researcher responsibility. |
| Multi-collector data sharing | Local workspaces are independent until consolidation. | Shared versioned manifest, duplicate policy, provenance, import preview. |
| Installer distribution | Static-site asset size limits may block large installers. | Keep the landing/docs on Pages; host large releases separately. |

## Files reviewed

- Flutter app: `client/lib/core/api_client.dart`, `client/lib/core/services/camera_service.dart`, `client/lib/core/video/`, `client/lib/core/constants/recording_protocol.dart`, and `client/lib/features/`.
- Backend: `backend/app/core/`, `backend/app/api/v1/`, `backend/app/models/`, `backend/app/repositories/`, `backend/app/services/`, `backend/alembic/versions/`, `backend/models/`, and `backend/scripts/`.
- Project and hosting notes: `README.md`, `docs/HOSTING_SETUP.md`, `client/pubspec.yaml`, and `backend/requirements.txt`.
