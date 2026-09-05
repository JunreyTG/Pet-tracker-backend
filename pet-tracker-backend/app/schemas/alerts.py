from datetime import datetime

from pydantic import Field

from app.models.entities import AlertType, FirestoreModel


class AlertUpdateRequest(FirestoreModel):
    read: bool


class AlertResponse(FirestoreModel):
    id: str
    owner_id: str
    pet_id: str | None = None
    device_id: str | None = None
    type: AlertType
    title: str
    message: str
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    read: bool
    created_at: datetime
