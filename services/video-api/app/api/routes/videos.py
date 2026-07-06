from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def list_videos():
    return {
        "message": "Video catalogue endpoint not implemented"
    }