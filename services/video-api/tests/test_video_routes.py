from unittest.mock import patch
from app.services.metadata import metadata_service
from uuid import uuid4


@patch("app.api.routes.videos.generate_upload_url")
def test_create_video(mock_generate_upload_url, client):

    payload = {
        "title": "My Test Video",
        "description": "Testing upload",
        "filename": "demo.mp4",
        "content_type": "video/mp4",
    }

    mock_generate_upload_url.return_value = (
        "https://example.com/upload"
    )
    
    response = client.post(
        "/videos/",
        json=payload,
    )
    
    assert response.status_code == 201

    body = response.json()

    assert "video_id" in body
    assert body["upload_url"] == "https://example.com/upload"

    mock_generate_upload_url.assert_called_once()

    assert len(metadata_service.list()) == 1

    
@patch("app.api.routes.videos.generate_upload_url")
def test_list_videos(mock_generate_upload_url, client):
    mock_generate_upload_url.return_value = (
        "https://example.com/upload"
    )

    payload = {
        "title": "My test video",
        "description": "Testing Upload",
        "filename": "demo.mp4",
        "content_type": "video/mp4",
    }

    create_response = client.post(
        "/videos/",
        json=payload,
    )

    assert create_response.status_code == 201

    response = client.get("/videos/")

    assert response.status_code == 200

    body = response.json()

    assert len(body) == 1

    assert body[0]["title"] == payload["title"]
    assert body[0]["description"] == payload["description"]
    assert body[0]["status"] == "UPLOAD_PENDING"


@patch("app.api.routes.videos.generate_upload_url")
def test_get_video(mock_generate_upload_url, client):
    mock_generate_upload_url.return_value = "https://example.com/upload"

    payload = {
        "title": "My test video",
        "description": "Testing Video Retrieval",
        "filename": "demo.mp4",
        "content_type": "video/mp4",
    }

    create_response = client.post(
        "/videos/", 
        json=payload,
        )
    
    assert create_response.status_code == 201

    create_body = create_response.json()
    video_id = create_body["video_id"]

    response = client.get(f"/videos/{video_id}")

    assert response.status_code == 200

    body = response.json()

    assert body["id"] == str(video_id)
    assert body["title"] == payload["title"]
    assert body["description"] == payload["description"]
    assert body["status"] == "UPLOAD_PENDING"


def test_get_video_not_found(client):

    video_id = uuid4()
    response = client.get(f"/videos/{video_id}")

    assert response.status_code == 404
    assert response.json() == {"detail": "Video not found"}