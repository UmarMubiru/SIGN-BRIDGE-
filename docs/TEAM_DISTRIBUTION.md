# SignBridge team distribution

## Current release preparation state

- Initial version convention: `0.1.0` (Android version code `1`, from `client/pubspec.yaml`).
- Android package identity: `com.umarmubiru.signbridge`; this replaces the generated `com.example.signbridge` placeholder before team distribution. Android treats this as a different app. Existing installs of the placeholder package remain separate and this app cannot read their private app storage. Before removing an old development install, export/back up any workspace stored only in its app-managed directory. Future updates must keep the new package ID and signing key.
- GitHub remote: `origin` is configured as `https://github.com/UmarMubiru/SIGN-BRIDGE-.git`; this preparation does not push or publish.
- The repository contains a manual GitHub Actions workflow at `.github/workflows/build-release-artifacts.yml`. It builds Windows and Android artifacts and retains them as workflow artifacts. It never creates a GitHub Release.
- The team release is local-only: cloud authentication is disabled unless `SIGNBRIDGE_ENABLE_CLOUD_AUTH=true` is explicitly passed at build time. Leave it unset for this release; account, login, and registration routes are then omitted.
- Do not distribute an artifact until the platform build, signature status, checksum, and relevant manual tests have been reviewed.

## Optional cloud API

When cloud authentication is enabled for development, debug builds with no API define use localhost (`http://localhost:8000/api/v1` on Windows and `http://10.0.2.2:8000/api/v1` on an Android emulator). Profile and release builds with no URL are explicitly unconfigured; they do not fall back to localhost. The current team release leaves cloud authentication disabled, and local workspace operations remain available.

After FastAPI has been deployed to Cloud Run and its health and authentication routes have been verified, set the public API URL at build time:

```powershell
flutter build windows --release --dart-define=SIGNBRIDGE_API_BASE_URL=https://<verified-cloud-run-service>/api/v1
flutter build apk --release --dart-define=SIGNBRIDGE_API_BASE_URL=https://<verified-cloud-run-service>/api/v1
```

The URL is public client configuration, not a secret. Never put Neon, R2, JWT, or other credentials into Flutter build arguments. Leave the API URL unset until there is a real verified service URL.

## Windows installer

Requirements: Flutter 3.47.5, Visual Studio with the Desktop development with C++ workload and Windows SDK, and Inno Setup 6.

From `client/`, run:

```powershell
./scripts/build_windows_installer.ps1
```

If and only if a verified API URL is ready, pass it explicitly:

```powershell
./scripts/build_windows_installer.ps1 -ApiBaseUrl 'https://<verified-cloud-run-service>/api/v1'
```

The installer is created at `client/build/installer/SignBridge-Setup-0.1.0-Windows-x64.exe`; its `.sha256` sidecar is generated alongside it. The installer is per-user, includes the full Flutter release bundle, offers a checked-by-default desktop shortcut, adds a Start Menu shortcut, and supports uninstall. It only manages files under its application directory. Workspaces should be kept in user-selected locations outside that directory.

## Android release signing

`client/android/app/build.gradle.kts` uses a release key only when `client/android/key.properties` exists and is complete. That file and keystore are ignored by Git. Without them, the Gradle release variant is unsigned; it is not a team-installable production release and must be labelled test-only.

Create a key once on a secure machine and keep at least two protected backups of the keystore and passwords:

```powershell
keytool -genkeypair -v -keystore client/android/app/signbridge-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias signbridge
Copy-Item client/android/key.properties.example client/android/key.properties
```

Edit the ignored `key.properties` locally with the correct store password, key alias, and key password. Keep `storeFile=app/signbridge-release.jks`. Do not generate a different key for each collector; future Android updates to the same application identity must use the same signing key.

For GitHub Actions signing, configure these repository secrets only after the team has safely created and backed up the release key:

- `SIGNBRIDGE_RELEASE_KEYSTORE_BASE64`
- `SIGNBRIDGE_RELEASE_STORE_PASSWORD`
- `SIGNBRIDGE_RELEASE_KEY_ALIAS`
- `SIGNBRIDGE_RELEASE_KEY_PASSWORD`

The workflow labels the Android artifact signed only when all four values are present and `apksigner` verifies the APK. Otherwise it labels the output unsigned/test-only. The private key and passwords must never be committed or attached to a release.

### Local Windows Android build note

The development PC's Android build environment had two Windows path issues. Java's `Selector.open()` and Gradle failed to establish a loopback connection with the current temporary directory; the same JDK probe succeeded when `TEMP` and `TMP` pointed to the short `D:\SIGN BRIDGE\tmp` path. Kotlin incremental compilation also failed when dependency sources were under `C:` while the project was under `D:`. A clean isolated source copy with the Pub cache on `D:` built successfully. Flutter doctor reported Flutter 3.47.5, Android SDK 36, and Android Studio JDK 25; the project uses Gradle 9.3.1 and Android Gradle Plugin 9.1.0. No Java/Gradle/Kotlin downgrade was made. The GitHub Android job uses Ubuntu, avoiding these Windows-only path interactions.

## Manual artifact build via GitHub Actions

1. After the reviewed code has been pushed to the repository with approval, open **Actions → Build SignBridge distribution artifacts → Run workflow**.
2. Leave `api_base_url` blank unless a verified production API URL is available.
3. Download the Windows installer and Android APK from the completed run's **Artifacts** section.
4. Verify each SHA-256 sidecar, inspect the Android signature status, and complete the manual installation checks below.
5. The workflow does not publish a GitHub Release.

## First GitHub Release after approval

1. Confirm the release code and artifacts have been reviewed and that no workspace data, credentials, `.env`, keystore, or generated binaries are staged in source control.
2. Confirm the Android APK is signed with the backed-up long-term release key. Do not publish an unsigned test APK as the team release.
3. Run `Get-FileHash <artifact> -Algorithm SHA256` on each final artifact and write a `SHA256SUMS.txt` with the filenames and hashes.
4. Copy `docs/RELEASE_NOTES_TEMPLATE.md`, replace placeholders and limitations with verified facts, and update `CHANGELOG.md`.
5. In GitHub, create a draft release for tag `v0.1.0` from the approved commit. Attach the Windows installer, signed Android APK, and checksum file.
6. Review the draft release notes, signatures, and hashes with the team. Publish only after explicit approval.

No release tag or draft is created by this local preparation.

## Instructions for the four collectors

### Windows

1. Download the installer and checksum from the approved GitHub Release; compare the checksum before running it.
2. Run the installer as the current Windows user. No fixed workspace path or environment variable is required.
3. Launch SignBridge from Start Menu or the optional desktop shortcut.
4. Create a separate workspace in a user-controlled folder (for example, under Documents or on the study drive). Use a unique name for the collection/team member.
5. Record and approve videos; they and their metadata remain inside that workspace. Sign in only if optional cloud account services have been configured.
6. Make and verify workspace backups on separate storage. Do not store workspaces inside the SignBridge installation folder.

### Android

1. Download the signed APK and checksum from the approved GitHub Release and verify the hash.
2. Install it using the Android package installer; approve installs from that download source if Android requests it.
3. Create a workspace in SignBridge. Android stores it in app-managed storage by default.
4. Use **Create Verified Backup** or **Export Portable Workspace** to a folder you control before uninstalling or clearing SignBridge app data. Android may remove app-managed workspace data in those cases.
5. Validate a restored workspace before deleting or retiring any other copy.

## Verification still required before claiming team readiness

- Test the Windows installer install, launch, upgrade, and uninstall on a clean Windows account or another PC; verify workspaces are preserved.
- Test camera recording, approval, playback, restart, and reopening on actual Windows camera hardware.
- Test Android APK installation and camera/recording/approval/playback on a real supported device.
- Test Android SAF folder restore/export with at least one target document provider and removable storage if the team will use it.
- Verify dataset ZIP creation from the installed Windows app. The basic portable ZIP is designed to work without Python; the advanced frame/landmark processing path remains dependent on the development Python/OpenCV/MediaPipe setup.
- Test offline local collection and ensure an unavailable cloud service does not block it.
