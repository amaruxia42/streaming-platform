from unittest.mock import patch
from app.services.metadata import metadata_service


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