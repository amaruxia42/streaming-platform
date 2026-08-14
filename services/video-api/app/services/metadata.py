from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.video import Video, VideoStatus
from app.core.exceptions import VideoNotFoundError


class MetadataService:

    def __init__(self, db: Session):
        self.db = db

    def create(self, video: Video) -> None:
        self.db.add(video)
        self.db.commit()
        self.db.refresh(video)

    def get(self, video_id: UUID) -> Video:
        video = self.db.get(Video, video_id)

        if video is None:
            raise VideoNotFoundError(video_id)

        return video

    def list(self) -> list[Video]:
        statement = select(Video)
        return list(self.db.scalars(statement).all())


    def update_status(
        self,
        video_id: UUID,
        status: VideoStatus
    ) -> None:

        video = self.get(video_id)
        video.status = status
        self.db.commit()
        self.db.refresh(video)

