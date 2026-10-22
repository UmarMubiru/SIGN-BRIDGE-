# SignBridge v0.1.0

Local-first video collection and annotation for the SignBridge team.

## Downloads

- Windows: `SignBridge-Setup-0.1.0-Windows-x64.exe`
- Android: attach only the release-signed `app-release.apk` after verifying its SHA-256. Label unsigned builds as test-only and do not distribute them as team releases.
- Publish a `SHA256SUMS.txt` file beside the installers.

## Installation

### Windows

1. Download the Windows installer and checksum file from this release.
2. Verify the installer hash with `Get-FileHash .\SignBridge-Setup-0.1.0-Windows-x64.exe -Algorithm SHA256` and compare it with the published value.
3. Run the installer. It installs per-user under Local AppData; administrator rights are not required.
4. Launch SignBridge from Start Menu or the optional desktop shortcut.
5. Create a workspace in a user-controlled folder. Keep workspace folders outside the application install directory.

### Android

1. Download the signed APK and checksum file from this release.
2. Verify the APK SHA-256 before installation.
3. Install the APK using Android's package installer. Android may require approval to install from the browser or file manager used to download it.
4. Create a workspace in SignBridge, then create a verified backup outside app storage before uninstalling or clearing app data.

## Local-first behavior

Workspace databases, videos, annotations, and backups stay local. Cloud sign-in, registration, and account routes are disabled in this release. Local collection does not require a network connection.

## Cloud account configuration

Cloud sign-in is disabled by default and is not part of this local-only release. A later cloud-enabled build must explicitly enable `SIGNBRIDGE_ENABLE_CLOUD_AUTH` and supply a verified public API base URL.

## Known limitations

- List only limitations confirmed for the actual release build and tested devices.
- Identify any camera, Android folder-provider, frame-extraction, or landmark-processing limitations by platform.

## Checksums

Include the SHA-256 value for each attached binary. Never attach signing keys or `.env` files.
