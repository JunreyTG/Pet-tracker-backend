from typing import Literal

from fastapi import APIRouter


router = APIRouter(tags=["health"])


@router.get("/health")
def health_check() -> dict[str, Literal["ok", "Pet tracker backend API is running"]]:
    return {
        "status": "ok",
        "message": "Pet tracker backend API is running",
    }
