from datetime import datetime

from pydantic import Field

from app.models.entities import FirestoreModel, GeofenceState, GeofenceTransitionType, Location


class GeofenceCreateRequest(FirestoreModel):
    pet_id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    center: Location
    radius_meters: float = Field(gt=0)
    enabled: bool = True


class GeofenceUpdateRequest(FirestoreModel):
    name: str | None = Field(default=None, min_length=1)
    center: Location | None = None
    radius_meters: float | None = Field(default=None, gt=0)
    enabled: bool | None = None


class GeofenceResponse(FirestoreModel):
    id: str
    owner_id: str
    pet_id: str
    name: str
    center: Location
    radius_meters: float
    enabled: bool
    last_state: GeofenceState | None = None
    last_state_changed_at: datetime | None = None
    last_checked_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class GeofenceTransitionResult(FirestoreModel):
    geofence_id: str
    pet_id: str
    geofence_name: str
    previous_state: GeofenceState | None
    current_state: GeofenceState
    transition_detected: bool
    transition_type: GeofenceTransitionType
