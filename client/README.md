# SignBridge client

The Flutter desktop client is local-first. Create a workspace on a local or removable drive before collecting data. The workspace holds `workspace.json`, `database.sqlite3`, `videos/`, `exports/`, and `backups/`. Participant and recording metadata stays in SQLite; original videos stay as files referenced by workspace-relative paths.

## Windows local workflow

From this directory:

```powershell
flutter pub get
flutter run -d windows
```

Select **Create New Workspace** and choose a parent directory, then enter the workspace folder name. For example, choose `D:\datasets` as the parent and `USL_Field_Collection` as the name. Reopen by selecting `D:\datasets\USL_Field_Collection` itself; SignBridge validates `workspace.json` and the database before opening it.

Create a participant/session when those are part of the study protocol. For continuous collection, use the workspace screen's continuous recording action. Review and play the captured video, select an event type, set an explicit consent state, then approve and save locally. Find saved events under **Workspace recordings**. In the recording viewer, add utterance timestamp ranges, speaker attribution, gloss, translation, uncertainty notes, and revisions. Search the library by file name, type, status, path, or checksum.

## Backup and portable copy

From the active workspace card, choose **Create Verified Backup** or **Export Portable Workspace** and select a destination outside the workspace. Both create a complete workspace folder copy, checkpoint the SQLite write-ahead log, compare each copied file's SHA-256 checksum, and write a `copy-manifest.json`. Open the copied workspace by selecting the copied folder itself. This is a self-contained folder copy, not a compressed or filtered/anonymized dataset archive. Keep more than one backup on separate storage; deleting the workspace or its videos can permanently delete research data.

On Android, workspaces currently live under app-managed storage at `Documents/SignBridge/Workspaces`. Copy the workspace out before uninstalling or clearing app data. Android camera, export-picker, playback, and restart behavior still require device validation.

### Restore a workspace copy safely

Close SignBridge before restoring. Keep the original workspace and backup untouched. Copy the complete backup folder to a new location (do not merge it over an existing workspace), then choose **Open Existing Workspace** and select the copied folder containing `workspace.json`. Confirm the expected recordings appear and play, and retain the original backup until the restored copy has been checked. Selecting a copy only changes which folder is active; it does not overwrite the original. If a copied video or database is missing, stop and restore from another verified copy rather than continuing collection in the incomplete workspace.

## Scope and cloud

Local collection, approval, playback, annotation, and workspace copies do not require sign-in or internet. Cloud sign-in and cloud-only account/dataset operations remain optional. The app does not automatically synchronize or upload a local workspace. The web client does not support these desktop workspace filesystem operations.

The camera capture path depends on the platform camera plugin and device/driver support. A preview can work while the Windows plugin rejects starting video capture. Do not treat a successful build as a physical camera test.
