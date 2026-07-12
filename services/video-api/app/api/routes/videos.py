from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException

from app.models.video import Video, VideoStatus
from app.schemas.video import (
    VideoCreateRequest,
    VideoResponse,
    VideoUploadResponse
)
from app.services.metadata import metadata_service
from app.services.s3 import generate_upload_url

router = APIRouter(prefix="/videos", tags=["Videos"])


@router.get(
    "/",
    response_model=list[VideoResponse],
)
async def list_videos():
    videos = metadata_service.list()

    return [
        VideoResponse(
            id=video.id,
            title=video.title,
            description=video.description,
            status=video.status,
        )
        for video in videos
    ]

@router.get(
    "/{video_id}",
    response_model=VideoResponse,
)
async def get_video(video_id: UUID):

    video = metadata_service.get(video_id)

    if video is None:
        raise HTTPException(
            status_code=404,
            detail="Video not found",
        )

    return VideoResponse(
        id=video.id,
        title=video.title,
        description=video.description,
        status=video.status,
    )


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