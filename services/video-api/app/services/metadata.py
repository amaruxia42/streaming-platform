from uuid import UUID

from app.models.video import Video, VideoStatus
from app.core.exceptions import VideoNotFoundError


class MetadataService:

    def __init__(self):
        self.videos: dict[UUID, Video] = {}

    def create(self, video: Video) -> None:
        self.videos[video.id] = video

    def get(self, video_id: UUID) -> Video:
        video = self.videos.get(video_id)

        if video is None:
            raise VideoNotFoundError(video_id)

        return video


    def list(self) -> list[Video]:
        return list(self.videos.values())


    def update_status(
            self,
            video_id: UUID,
            status: VideoStatus
    ) -> None:

        video = self.videos.get(video_id)
        video.status = status
        


metadata_service = MetadataService()
