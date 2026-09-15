"""align video table with video model

Revision ID: f0558ce3e2ba
Revises: 5365de3c29bc
Create Date: 2026-09-15
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f0558ce3e2ba"
down_revision: Union[str, Sequence[str], None] = "5365de3c29bc"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Align the video table with the current Video model."""

    op.rename_table("video", "videos")

    op.alter_column(
        "videos",
        "description",
        existing_type=sa.String(length=2000),
        type_=sa.Text(),
        nullable=True,
    )


def downgrade() -> None:
    """Revert the video table alignment."""

    op.alter_column(
        "videos",
        "description",
        existing_type=sa.Text(),
        type_=sa.String(length=2000),
        nullable=False,
    )

    op.rename_table("videos", "video")