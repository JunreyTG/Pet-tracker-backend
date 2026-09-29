from typing import Literal

from fastapi import APIRouter


router = APIRouter(tags=["health"])


@router.get("/")
def root_status() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "Pet Tracker Backend API",
        "docs_url": "/docs",
        "health_url": "/health",
    }


@router.get("/health")
def health_check() -> dict[str, Literal["ok", "Pet tracker backend API is running"]]:
    return {
        "status": "ok",
        "message": "Pet tracker backend API is running",
    }
