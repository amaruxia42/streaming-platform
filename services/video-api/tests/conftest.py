"""Shared pytest fixtures and test configuration."""

import os

os.environ["INGEST_BUCKET"] = "test-ingest-bucket"

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.metadata import metadata_service


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture(autouse=True)
def clear_metadata():
    metadata_service.clear()