from enum import Enum
from uuid import UUID

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class VideoStatus(str, Enum):
    UPLOAD_PENDING = "UPLOAD_PENDING"
    UPLOADED = "UPLOADED"
    TRANSCODING = "TRANSCODING"
    READY = "READY"
    FAILED = "FAILED"



class Video(Base):
    __tablename__ = "videos"

    id: Mapped[UUID] = mapped_column(
        primary_key=True,
    )

    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )

    filename: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    content_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    status: Mapped[VideoStatus] = mapped_column(
        nullable=False,
    )
