from uuid import UUID, uuid4

from fastapi import APIRouter, HTTPException

from app.core.exceptions import VideoNotFoundError
from app.core.logging import logger
from app.models.video import Video, VideoStatus
from app.schemas.video import (
    VideoCreateRequest,
    VideoResponse,
    VideoStatusUpdateRequest,
    VideoStatusResponse,
    VideoUploadResponse,
)
from app.services.metadata import metadata_service
from app.services.s3 import generate_upload_url

router = APIRouter(
    prefix="/videos",
    tags=["Videos"],
)


@router.get(
    "/",
    summary="List videos",
    description=(
        "Returns all video metadata currently stored by the Video API."
    ),
    response_model=list[VideoResponse],
    responses={
        200: {
            "description": "Video list returned successfully.",
        },
    },
)
async def list_videos():
    videos = metadata_service.list()

    logger.info(
        "Retrieved %d videos",
        len(videos),
    )

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
    summary="Get a video",
    description=(
        "Retrieves the metadata for a specific video using its unique "
        "identifier."
    ),
    response_model=VideoResponse,
    responses={
        200: {
            "description": "Video metadata returned successfully.",
        },
        404: {
            "description": "Video not found.",
        },
    },
)
async def get_video(video_id: UUID):

    try:
        video = metadata_service.get(video_id)

    except VideoNotFoundError:
        logger.warning(
            "Video %s not found",
            video_id,
        )

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


@router.patch(
    "/{video_id}/status",
    summary="Update video status",
    description=(
        "Updates the processing status of a specific video."
    ),
    response_model=VideoStatusResponse,
    responses={
        200: {
            "description": "Video status updated successfully.",
        },
        404: {
            "description": "Video not found.",
        },
    },
)
async def update_video_status(
    video_id: UUID,
    request: VideoStatusUpdateRequest,
):
    try:
        metadata_service.update_status(
            video_id=video_id,
            status=request.status,
        )

    except VideoNotFoundError:
        logger.warning(
            "Video %s not found",
            video_id,
        )
        raise HTTPException(
            status_code=404,
            detail="Video not found",
        )

    logger.info(
        "Updated video %s status to %s",
        video_id,
        request.status,
    )

    return VideoStatusResponse(
        video_id=video_id,
        status=request.status,
    )


@router.post(
    "/",
    summary="Create a new video",
    description=(
        "Creates a new video metadata record and returns a pre-signed "
        "Amazon S3 upload URL that clients can use to upload the source "
        "video directly into the ingest bucket."
    ),
    response_model=VideoUploadResponse,
    status_code=201,
    responses={
        201: {
            "description": "Video created successfully.",
        },
    },
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
    logger.info("Created video %s", video.id)

    upload_url = generate_upload_url(
        video_id=video_id,
        filename=request.filename,
        content_type=request.content_type,
    )

    logger.info("Generated upload URL for video %s", video.id)

    return VideoUploadResponse(
        video_id=video_id,
        upload_url=upload_url,
    )