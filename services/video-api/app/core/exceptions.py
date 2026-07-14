from uuid import UUID

class VideoNotFoundError(Exception):
    """Raised when a video could not be found."""

    def __init__(self, video_id: UUID) -> None:
        self.video_id = video_id
        super().__init__(f"Video {video_id} could not be found.")

