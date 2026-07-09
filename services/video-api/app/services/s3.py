import boto3

from uuid import UUID
from botocore.client import Config
from app.core.config import settings

s3_client = boto3.client(
    "s3",
    region_name=settings.aws_region,
    config=Config(signature_version="s3v4"),
)


def generate_upload_url(
        video_id: UUID,
        filename: str,
        content_type: str,
) -> str:

    key = f"uploads/{video_id}/{filename}"

    return s3_client.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": settings.ingest_bucket,
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=3600
    )
