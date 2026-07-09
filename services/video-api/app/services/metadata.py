from uuid import UUID
from app.models.video import Video, VideoStatus


class MetadataService:

    def __init__(self):
        self.videos: dict[UUID, Video] = {}

    def create(self, video: Video) -> None:
        self.videos[video.id] = video

    def get(self, video_id: UUID) -> Video | None:
        return self.videos.get(video_id)

    def list(self) -> list[Video]:
        return list(self.videos.values())

    def update_status(
            self,
            video_id: UUID,
            status: VideoStatus
    ) -> None:

        if video_id in self.videos:
            self.videos[video_id].status = status


metadata_service = MetadataService()
