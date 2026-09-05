from app.schemas.devices import DeviceAssignRequest, DeviceRegisterRequest, DeviceRegistrationResponse, DeviceResponse
from app.schemas.alerts import AlertResponse, AlertUpdateRequest
from app.schemas.geofences import GeofenceCreateRequest, GeofenceResponse, GeofenceTransitionResult, GeofenceUpdateRequest
from app.schemas.notifications import (
    NotificationTokenRegisterRequest,
    NotificationTokenRegisterResponse,
    NotificationTokenResponse,
)
from app.schemas.pets import PetCreateRequest, PetResponse, PetUpdateRequest
from app.schemas.telemetry import DeviceTelemetryRequest, DeviceTelemetryResponse

__all__ = [
    "DeviceAssignRequest",
    "DeviceRegisterRequest",
    "DeviceRegistrationResponse",
    "DeviceResponse",
    "AlertResponse",
    "AlertUpdateRequest",
    "DeviceTelemetryRequest",
    "DeviceTelemetryResponse",
    "GeofenceCreateRequest",
    "GeofenceResponse",
    "GeofenceTransitionResult",
    "GeofenceUpdateRequest",
    "NotificationTokenRegisterRequest",
    "NotificationTokenRegisterResponse",
    "NotificationTokenResponse",
    "PetCreateRequest",
    "PetResponse",
    "PetUpdateRequest",
]
