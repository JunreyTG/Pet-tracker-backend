from hmac import compare_digest
from typing import Literal

from fastapi import APIRouter, Header, HTTPException, Response
from google.api_core.exceptions import GoogleAPIError

from app.core.config import settings
from app.firebase.admin import FirebaseInitializationError
from app.firebase.firestore import get_firestore_client
from app.services.heartbeat_service import HeartbeatCheckResult, HeartbeatService, HeartbeatServiceError


router = APIRouter(tags=["health"])


@router.get("/health")
def health_check() -> dict[str, Literal["ok", "Pet tracker backend API is running"]]:
    return {
        "status": "ok",
        "message": "Pet tracker backend API is running",
    }


@router.get("/ready")
def readiness_check(response: Response) -> dict[str, str]:
    """Check Firestore read access. The probe document need not exist."""
    response.headers["Cache-Control"] = "no-store"
    try:
        get_firestore_client().document("system/readiness").get(retry=None, timeout=4)
    except (FirebaseInitializationError, GoogleAPIError) as exc:
        raise HTTPException(
            status_code=503, detail="Database is not ready.", headers={"Cache-Control": "no-store"}
        ) from exc
    return {"status": "ready", "database": "ok"}


@router.post("/internal/check-offline", include_in_schema=False)
def run_offline_check(authorization: str | None = Header(default=None)) -> HeartbeatCheckResult:
    secret = settings.device_offline_check_secret
    if not secret:
        raise HTTPException(status_code=404, detail="Offline scheduler is not configured.")
    if not compare_digest((authorization or "").encode(), f"Bearer {secret}".encode()):
        raise HTTPException(status_code=401, detail="Invalid scheduler credentials.")
    try:
        return HeartbeatService().check_devices_for_offline_status()
    except HeartbeatServiceError as exc:
        raise HTTPException(status_code=503, detail="Offline check unavailable.") from exc
