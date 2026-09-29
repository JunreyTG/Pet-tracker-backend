from datetime import datetime

from pydantic import Field

from app.models.entities import DeviceStatus, FirestoreModel, Location


class DeviceRegisterRequest(FirestoreModel):
    device_id: str = Field(min_length=1, max_length=128)


class DeviceProvisioningRequest(DeviceRegisterRequest):
    backend_url: str | None = Field(default=None, min_length=1)


class DeviceAssignRequest(FirestoreModel):
    pet_id: str = Field(min_length=1)


class DeviceResponse(FirestoreModel):
    id: str
    device_id: str
    owner_id: str
    pet_id: str | None = None
    status: DeviceStatus
    battery_level: int | None = Field(default=None, ge=0, le=100)
    current_location: Location | None = None
    last_seen: datetime | None = None
    last_location_update: datetime | None = None
    low_battery_alert_active: bool = False
    created_at: datetime
    updated_at: datetime


class DeviceRegistrationResponse(DeviceResponse):
    device_secret: str


class DeviceProvisioningResponse(DeviceRegistrationResponse):
    backend_url: str
    telemetry_path: str
    telemetry_url: str
    setup_hotspot_ssid: str
