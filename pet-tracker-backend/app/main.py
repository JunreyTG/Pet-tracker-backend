import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.alerts import router as alerts_router
from app.api.devices import router as devices_router
from app.api.geofences import router as geofences_router
from app.api.health import router as health_router
from app.api.notifications import router as notifications_router
from app.api.pets import router as pets_router
from app.api.places import router as places_router
from app.api.telemetry import router as telemetry_router
from app.core.config import settings
from app.services.heartbeat_service import HeartbeatService, HeartbeatServiceError

logger = logging.getLogger(__name__)


async def _heartbeat_loop(stop_event: asyncio.Event) -> None:
    """Best-effort in-process heartbeat loop; use one worker or an external scheduler in production."""
    while not stop_event.is_set():
        try:
            result = HeartbeatService().check_devices_for_offline_status()
            if result.marked_offline_count:
                logger.info("Marked %s device(s) offline.", result.marked_offline_count)
        except HeartbeatServiceError as exc:
            logger.info("Heartbeat check failed: %s", exc.__class__.__name__)
        except Exception:
            logger.exception("Unexpected heartbeat check failure.")

        try:
            await asyncio.wait_for(stop_event.wait(), timeout=settings.device_heartbeat_check_interval_seconds)
        except TimeoutError:
            continue


@asynccontextmanager
async def lifespan(app: FastAPI):
    stop_event = asyncio.Event()
    heartbeat_task = asyncio.create_task(_heartbeat_loop(stop_event))
    app.state.heartbeat_task = heartbeat_task
    try:
        yield
    finally:
        stop_event.set()
        heartbeat_task.cancel()
        try:
            await heartbeat_task
        except asyncio.CancelledError:
            pass


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_origin_regex=settings.cors_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(alerts_router)
    app.include_router(pets_router)
    app.include_router(devices_router)
    app.include_router(telemetry_router)
    app.include_router(geofences_router)
    app.include_router(notifications_router)
    app.include_router(places_router)

    from fastapi.responses import FileResponse, RedirectResponse
    from pathlib import Path

    @app.get("/download-apk")
    def download_apk():
        if settings.apk_download_url:
            return RedirectResponse(settings.apk_download_url)

        candidates = [
            Path("pet-tracker-release.apk"),
            Path("../pet-tracker-release.apk"),
            Path(r"c:\Users\Admin\Desktop\Pet_tracker_system\pet-tracker-release.apk"),
        ]
        found = next((p for p in candidates if p.exists() and p.is_file()), None)
        if not found:
            from fastapi import HTTPException
            raise HTTPException(
                status_code=404,
                detail="APK not found. Please set APK_DOWNLOAD_URL or place pet-tracker-release.apk in root.",
            )
        return FileResponse(
            found,
            media_type="application/vnd.android.package-archive",
            filename="pet-tracker-release.apk",
        )

    from fastapi.staticfiles import StaticFiles

    web_dir = Path(__file__).resolve().parent.parent / "web"
    if web_dir.exists() and web_dir.is_dir():
        app.mount("/", StaticFiles(directory=str(web_dir), html=True), name="web")

    return app


app = create_app()
