# Local workspaces, copies, and dataset exports

## Where local data lives

A workspace is a folder containing `workspace.json`, `database.sqlite3`, `videos/`, `exports/`, and `backups/`. Video files stay as ordinary files under relative paths in `videos/`; SQLite stores recording metadata, participant and consent records, sessions, signs, and annotations. SignBridge keeps the active workspace path in application settings. Local collection does not require sign-in, an API server, or an internet connection.

## Windows

Use **Workspace → Create New Workspace** and choose a parent folder on a drive you control. To move or protect a workspace, use **Create Verified Backup** or **Export Portable Workspace**, and choose a destination outside the active workspace. The operation creates a new copy folder and checks copied-file SHA-256 values. To reopen a copy, choose **Open Existing Workspace** and select its folder.

Do not edit `database.sqlite3` while SignBridge is open. Keep the entire workspace folder together when moving it. The relative video paths allow a verified copy to be reopened at a different location.

## Android

New workspaces are stored under SignBridge's app-managed documents directory. Android may remove this data when SignBridge is uninstalled or its app data is cleared. Before uninstalling, use **Create Verified Backup** or **Export Portable Workspace** and select a folder you control, such as a user-selected Documents folder or removable drive.

To restore, install SignBridge, open **Workspace**, and choose **Restore Workspace from Folder**. Select the workspace folder itself, not its parent. SignBridge copies it back into app-managed storage, checks the copy manifest when present, validates the workspace manifest and SQLite database, and verifies every referenced video path, size, and stored SHA-256 before activating it. The source folder is left unchanged. A cancelled or invalid restore leaves the current workspace selected.

The Android picker uses the Storage Access Framework. The destination provider must support creating folders and files; access to removable volumes depends on the Android document provider.

## Portable datasets and analysis outputs

The **Create Dataset ZIP** action is the portable export. It works from local workspace files without Python or the repository checkout. It includes selected videos, `manifest.txt`, recording metadata in JSON and CSV, and annotation metadata in JSON and CSV. Annotation times, glosses, translations, language tags, revision links, speaker attribution status, and uncertainty status are preserved. Speaker references are pseudonyms local to each recording. Participant names, demographic fields, consent documents, annotation-note text, annotator/reviewer labels, and free-form participant or speaker notes are omitted. Recording consent status remains in the recording metadata.

The portable ZIP does not contain extracted frame images or MediaPipe landmarks. The separate analyzed-export code path samples video at approximately one frame per second, writes JPG frames plus orientation CSV and landmark JSONL, and currently requires the repository's Python/OpenCV/MediaPipe environment and model files. It is a development-checkout capability for Windows, Linux, and macOS; it is not available from a packaged Windows install or Android. Do not describe analyzed exports as available to installed collectors until a supported bundled or native processing runtime is selected and verified.
