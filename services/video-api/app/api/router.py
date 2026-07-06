from fastapi import APIRouter
from app.api.routes.videos import router as videos_router

api_router = APIRouter()

api_router.include_router(
    videos_router,
    prefix="/videos",
    tags=["videos"]
)