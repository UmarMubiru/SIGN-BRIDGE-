# SignBridge hosting setup

The application is prepared for this low-cost pilot stack:

- Cloudflare Pages for the Flutter web app
- Google Cloud Run for the FastAPI service
- Neon for PostgreSQL
- Cloudflare R2 for private videos and processed frames

The backend Dockerfile reads Cloud Run's `PORT`, the production settings validate the required database and R2 configuration, and Alembic owns the schema. The Flutter app accepts its public API URL through `SIGNBRIDGE_API_BASE_URL` at build time.

## Values and where they belong

Keep provider credentials out of source files, Flutter build arguments, and chat. The ignored `backend/.env` file is for local development and one-off migrations. For the hosted backend, put secrets in Google Secret Manager and expose them to Cloud Run as environment variables.

| Value | Get it from | Use it in |
| --- | --- | --- |
| `DATABASE_URL` | Neon pooled connection string | Cloud Run Secret Manager; local API if wanted |
| `MIGRATION_DATABASE_URL` | Neon direct connection string | Local one-off migration/admin commands |
| `SECRET_KEY` | Generate a fresh random value locally | Cloud Run Secret Manager and local `.env` |
| `OBJECT_STORAGE_BUCKET` | Existing private R2 bucket name | Cloud Run and local `.env` |
| `OBJECT_STORAGE_ENDPOINT_URL` | R2 account ID: `https://<account-id>.r2.cloudflarestorage.com` | Cloud Run and local `.env` |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | R2 API token scoped to the bucket with object read/write | Cloud Run Secret Manager and local `.env` |
| `BACKEND_CORS_ORIGINS` | Exact HTTPS origin assigned to the Pages site | Cloud Run and local `.env` |
| `SIGNBRIDGE_API_BASE_URL` | Cloud Run service URL plus `/api/v1` | Flutter release build only; this is public, not a secret |

## Provider setup order

1. **Neon:** create a PostgreSQL project. Copy the pooled connection string for `DATABASE_URL` and the direct connection string for `MIGRATION_DATABASE_URL`. Keep both private. The API uses the pooled URL; one-off Alembic runs use the direct URL.
2. **Cloudflare R2:** use the existing private bucket. In the Cloudflare dashboard, create an R2 API token scoped to that bucket with object read and write access. Copy the access key ID and secret once, and note the account ID and bucket name. Do not enable public bucket access.
3. **Google Cloud:** choose a Cloud Run region, enable billing, and enable Cloud Run, Cloud Build, Artifact Registry, and Secret Manager. Create a runtime service account and grant it access to the secrets used by the service. Store `DATABASE_URL`, `SECRET_KEY`, and both R2 keys in Secret Manager. Set the remaining non-secret environment values on the Cloud Run service.
4. **Cloudflare Pages:** create the `signbridge-web` Pages project. After its HTTPS URL exists, set that exact origin in `BACKEND_CORS_ORIGINS` and the R2 bucket's CORS configuration. Allow the app origin to issue `PUT` requests with the `Content-Type` header. Keep R2 private.
5. **Build the web client:** use the Cloud Run URL as public build configuration: `flutter build web --release --dart-define=SIGNBRIDGE_API_BASE_URL=https://<cloud-run-url>/api/v1`. Deploy `client/build/web` to the Pages project.

## Local configuration

`backend/.env` already exists and is ignored by Git. Edit it locally when you receive the provider values; do not replace secrets in Python or Dart source. For a production migration, set `APP_ENV=production`, `DATABASE_URL` to Neon’s pooled URL, and `MIGRATION_DATABASE_URL` to Neon’s direct URL. Set the R2 values and the exact Pages origin as well. For local development, keep `APP_ENV=development` and use a local PostgreSQL URL.

Generate a unique JWT secret in PowerShell from `backend/`, using the project's virtual environment:

```powershell
.\venv\Scripts\python.exe -c "import secrets; print(secrets.token_urlsafe(48))"
```

Save that output as `SECRET_KEY` in the local `.env` and as a Google Secret Manager secret for Cloud Run. Never reuse the example value.

## First administrator

Public registration now creates collector accounts only. Create the initial administrator from a trusted shell after the database migration and before inviting users. From `backend/`, run:

```powershell
.\venv\Scripts\python.exe scripts/create_admin.py --name "Administrator Name" --email admin@example.org
```

The script prompts for the password without echoing it and refuses to create a second administrator. For a hosted Neon database, temporarily set `$env:DATABASE_URL` in that PowerShell window to Neon’s direct connection string before running the script, then clear it with `Remove-Item Env:DATABASE_URL`. Do not expose the API before this step is complete.

## Cost and operating limits

The free tiers can suit a small pilot but do not guarantee a zero bill. Watch Cloud Run network egress and compute, Neon storage/compute/network usage, and R2 storage/operations. Add a Google Cloud budget alert before deployment. Avoid Render's free PostgreSQL for the live dataset because its free database expires after 30 days and its free web service sleeps when idle.

## Deployment order

1. Configure provider accounts and secrets.
2. From `backend/`, apply Alembic migrations once to the new Neon database with `.\venv\Scripts\python.exe -m alembic upgrade head`, using the direct migration URL.
3. Create the administrator using the script above.
4. Deploy the backend container to Cloud Run and confirm `/api/v1/health` reports a healthy database.
5. Create the Pages site and update backend CORS plus R2 CORS with its exact HTTPS origin.
6. Build and deploy Flutter Web with the Cloud Run API URL.
7. Verify login, permissions, recording uploads, authorized playback, dataset export, and deletion before collecting study data.
