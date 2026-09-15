"""Shared pytest fixtures and test configuration."""

import os

os.environ["INGEST_BUCKET"] = "test-ingest-bucket"
os.environ["DATABASE_URL"] = (
    "postgresql+psycopg://postgres:postgres@localhost:5432/video_api"
)

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.db.dependancies import get_db
from app.db.session import SessionLocal
from app.models.video import Video


@pytest.fixture
def db():
    session = SessionLocal()

    try:
        session.query(Video).delete()
        session.commit()
        yield session
    finally:
        session.rollback()
        session.close()


@pytest.fixture
def client(db: Session):
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()