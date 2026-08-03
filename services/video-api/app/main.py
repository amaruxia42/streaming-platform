from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.core.logging import logger

from app.core.exceptions import VideoNotFoundError
from app.api.router import api_router

tags_metadata = [
    {
        "name": "Videos",
        "description": (
            "Operations for creating videos, retrieving metadata, "
            "managing upload status, and orchestrating video uploads."
        ),
    },
    {
        "name": "Health",
        "description": "Application health check endpoints.",
    },
]

app = FastAPI(
    title="Video API",
    description=(
        "REST API responsible for video metadata management, "
        "upload orchestration, and event-driven video processing."
    ),
    version="0.2.0",
    contact={
        "name": "Project Repository",
        "url": "https://github.com/amaruxia42/streaming-platform",
    },
    openapi_tags=tags_metadata,
)


@app.exception_handler(VideoNotFoundError)
async def video_not_found_exception_handler(
    request: Request,
    exc: VideoNotFoundError,
) -> JSONResponse:
    logger.warning(
        "Video %s not found during %s %s",
        exc.video_id,
        request.method,
        request.url.path,
    )
    return JSONResponse(
        status_code=404,
        content={
            "detail": "Video not found",
        },
    )

app.include_router(api_router)


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy"}