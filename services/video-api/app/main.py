from fastapi import FastAPI

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

app.include_router(api_router)


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy"}