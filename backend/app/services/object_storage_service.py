"""Private S3-compatible object storage used as the durable video store."""

from pathlib import Path
import mimetypes
from functools import lru_cache

import boto3

from app.core.config import settings


def cloud_storage_enabled() -> bool:
    return bool(
        settings.OBJECT_STORAGE_BUCKET.strip()
        and settings.OBJECT_STORAGE_ENDPOINT_URL
        and settings.AWS_ACCESS_KEY_ID
        and settings.AWS_SECRET_ACCESS_KEY
    )


@lru_cache(maxsize=1)
def _client():
    kwargs = {"region_name": settings.OBJECT_STORAGE_REGION}
    if settings.OBJECT_STORAGE_ENDPOINT_URL:
        kwargs["endpoint_url"] = settings.OBJECT_STORAGE_ENDPOINT_URL
    if settings.AWS_ACCESS_KEY_ID and settings.AWS_SECRET_ACCESS_KEY:
        kwargs["aws_access_key_id"] = settings.AWS_ACCESS_KEY_ID
        kwargs["aws_secret_access_key"] = settings.AWS_SECRET_ACCESS_KEY
        if settings.AWS_SESSION_TOKEN:
            kwargs["aws_session_token"] = settings.AWS_SESSION_TOKEN
    # boto3 uses the standard credential provider chain (IAM role, environment,
    # shared credentials/config files, or web identity).
    return boto3.client("s3", **kwargs)


def require_cloud_storage() -> None:
    if not cloud_storage_enabled():
        raise RuntimeError(
            "Cloud object storage is not configured. Set the R2 bucket, endpoint, "
            "access key, and secret key in the backend environment."
        )


def presign_upload(
    object_key: str,
    content_type: str,
    expires_in: int = 900,
) -> str:
    require_cloud_storage()
    return _client().generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.OBJECT_STORAGE_BUCKET,
            "Key": object_key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )


def presign_download(object_key: str, expires_in: int = 900) -> str:
    require_cloud_storage()
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.OBJECT_STORAGE_BUCKET, "Key": object_key},
        ExpiresIn=expires_in,
    )


def object_metadata(object_key: str) -> dict:
    require_cloud_storage()
    response = _client().head_object(
        Bucket=settings.OBJECT_STORAGE_BUCKET, Key=object_key
    )
    return {
        "size": response["ContentLength"],
        "content_type": response.get("ContentType") or "application/octet-stream",
    }


def download_object(object_key: str, destination: Path) -> None:
    require_cloud_storage()
    destination.parent.mkdir(parents=True, exist_ok=True)
    _client().download_file(settings.OBJECT_STORAGE_BUCKET, object_key, str(destination))


def upload_local_file(path: Path, object_key: str, content_type: str) -> None:
    require_cloud_storage()
    _client().upload_file(
        str(path),
        settings.OBJECT_STORAGE_BUCKET,
        object_key,
        ExtraArgs={"ContentType": content_type or mimetypes.guess_type(path.name)[0] or "application/octet-stream"},
    )


def upload_stream(file_object, object_key: str, content_type: str) -> None:
    """Stream an already-spooled request file to the private object store."""
    require_cloud_storage()
    _client().upload_fileobj(
        file_object,
        settings.OBJECT_STORAGE_BUCKET,
        object_key,
        ExtraArgs={"ContentType": content_type},
    )


def promote_object(source_key: str, destination_key: str) -> None:
    """Copy a completed staging upload to its durable, non-presigned key."""
    require_cloud_storage()
    client = _client()
    client.copy_object(
        Bucket=settings.OBJECT_STORAGE_BUCKET,
        Key=destination_key,
        CopySource={"Bucket": settings.OBJECT_STORAGE_BUCKET, "Key": source_key},
        MetadataDirective="COPY",
    )


def delete_object(object_key: str) -> None:
    if cloud_storage_enabled() and object_key:
        _client().delete_object(Bucket=settings.OBJECT_STORAGE_BUCKET, Key=object_key)
