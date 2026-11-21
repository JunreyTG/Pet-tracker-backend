from datetime import datetime

from pydantic import Field, field_validator

from app.models.entities import DeviceStatus, FirestoreModel, Location

PT_DEVICE_ID_PATTERN = r"^PT-[0-9A-F]{12}$"


class DeviceRegisterRequest(FirestoreModel):
    device_id: str = Field(min_length=1, max_length=128)
    name: str | None = Field(default=None, min_length=1, max_length=40)

    @field_validator("name", mode="before")
    @classmethod
    def trim_name(cls, name: str | None) -> str | None:
        return name.strip() if isinstance(name, str) else name


class DeviceProvisioningRequest(DeviceRegisterRequest):
    backend_url: str | None = Field(default=None, min_length=1)


class DeviceAssignRequest(FirestoreModel):
    pet_id: str = Field(min_length=1)


class DeviceClaimRequest(FirestoreModel):
    device_id: str = Field(pattern=PT_DEVICE_ID_PATTERN)
    pet_id: str = Field(min_length=1, max_length=128, pattern=r"^[^/]+$")

    @field_validator("device_id", mode="before")
    @classmethod
    def normalize_id(cls, value: str) -> str:
        return value.strip().upper() if isinstance(value, str) else value


class DeviceResponse(FirestoreModel):
    id: str
    device_id: str
    owner_id: str
    name: str | None = None
    preconfigured: bool = False
    pet_id: str | None = None
    status: DeviceStatus
    battery_level: int | None = Field(default=None, ge=0, le=100)
    current_location: Location | None = None
    last_seen: datetime | None = None
    last_location_update: datetime | None = None
    setup_nonce: str | None = None
    gps_fix: bool | None = None
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
    setup_url: str | None = None
