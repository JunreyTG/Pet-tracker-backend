from pydantic import Field

from app.models.entities import FirestoreModel


class DeviceTelemetryRequest(FirestoreModel):
    device_id: str = Field(min_length=1, description="Public tracker device identifier.")
    device_secret: str = Field(min_length=1, description="Device credential returned once at registration.")
    latitude: float = Field(ge=-90, le=90, description="GPS latitude in decimal degrees.")
    longitude: float = Field(ge=-180, le=180, description="GPS longitude in decimal degrees.")
    battery_level: int = Field(ge=0, le=100, description="Tracker battery percentage.")


class DeviceTelemetryResponse(FirestoreModel):
    message: str
