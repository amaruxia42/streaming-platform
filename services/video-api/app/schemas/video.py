from uuid import UUID
from pydantic import BaseModel, Field

from app.models.video import VideoStatus


class VideoCreateRequest(BaseModel):

    title: str = Field(
        min_length=1,
        max_length=200,
    )

    description: str | None = None

    filename: str

    content_type: str


class VideoResponse(BaseModel):

    id: UUID
    title: str
    description: str | None = None
    status: VideoStatus


class VideoUploadResponse(BaseModel):

    video_id: UUID

    upload_url: str


class VideoStatusResponse(BaseModel):
    video_id: UUID

    status: VideoStatus


class VideoStatusUpdateRequest(BaseModel):
    status: VideoStatus
