from datetime import datetime

from pydantic import Field

from app.models.entities import FirestoreModel


class LocationHistoryResponse(FirestoreModel):
    id: str
    pet_id: str
    device_id: str
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    battery_level: int | None = Field(default=None, ge=0, le=100)
    recorded_at: datetime
