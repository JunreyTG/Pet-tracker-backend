from fastapi import FastAPI

from app.api.auth import router as auth_router
from app.api.alerts import router as alerts_router
from app.api.devices import router as devices_router
from app.api.geofences import router as geofences_router
from app.api.health import router as health_router
from app.api.notifications import router as notifications_router
from app.api.pets import router as pets_router
from app.api.telemetry import router as telemetry_router
from app.core.config import settings


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
    )
    app.include_router(health_router)
    app.include_router(auth_router)
    app.include_router(alerts_router)
    app.include_router(pets_router)
    app.include_router(devices_router)
    app.include_router(telemetry_router)
    app.include_router(geofences_router)
    app.include_router(notifications_router)
    return app


app = create_app()
