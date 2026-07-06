from fastapi import FastAPI
from api.router import api_router

app = FastAPI(
    title="Video API",
    description="Video metadata and upload orchestration service",
    version="0.1.0"
)

app.include_router(api_router)

@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy"
    }