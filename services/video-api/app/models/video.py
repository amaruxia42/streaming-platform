from enum import Enum
from uuid import UUID
from dataclasses import dataclass


class VideoStatus(str, Enum):
    UPLOAD_PENDING = "UPLOAD_PENDING"
    UPLOADED = "UPLOADED"
    TRANSCODING = "TRANSCODING"
    READY = "READY"
    FAILED = "FAILED"


@dataclass
class Video:
    id: UUID
    title: str
    description: str
    filename: str
    content_type: str
    status: VideoStatus
