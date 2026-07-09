from uuid import uuid4

from fastapi import APIRouter

from app.models.video import Video, VideoStatus
from app.schemas.video import VideoCreateRequest, VideoUploadResponse
from app.services.metadata import metadata_service
from app.services.s3 import generate_upload_url

router = APIRouter(prefix="/videos", tags=["Videos"])


@router.post(
    "/",
    response_model=VideoUploadResponse,
    status_code=201,
)
async def create_video(request: VideoCreateRequest):

    video_id = uuid4()

    video = Video(
        id=video_id,
        title=request.title,
        description=request.description,
        filename=request.filename,
        content_type=request.content_type,
        status=VideoStatus.UPLOAD_PENDING,
    )

    metadata_service.create(video)

    upload_url = generate_upload_url(
        video_id=video_id,
        filename=request.filename,
        content_type=request.content_type,
    )

    return VideoUploadResponse(
        video_id=video_id,
        upload_url=upload_url,
    )