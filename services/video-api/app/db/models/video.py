from uuid import UUID
from sqlalchemy import String, Enum
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.video import VideoStatus

class Video(Base):
    __tablename__ = "video"

    id: Mapped[UUID] = mapped_column(
        primary_key=True,
    )

    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    description: Mapped[str] = mapped_column(
        String(2000),
        nullable=False,
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
        Enum(VideoStatus),
        nullable=False,
    )

