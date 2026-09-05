from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class DeviceStatus(StrEnum):
    ONLINE = "online"
    OFFLINE = "offline"
    UNREGISTERED = "unregistered"
    DISABLED = "disabled"


class AlertType(StrEnum):
    GEOFENCE_EXIT = "geofence_exit"
    GEOFENCE_ENTER = "geofence_enter"
    LOW_BATTERY = "low_battery"
    DEVICE_OFFLINE = "device_offline"
    DEVICE_ONLINE = "device_online"


class GeofenceState(StrEnum):
    INSIDE = "inside"
    OUTSIDE = "outside"


class GeofenceTransitionType(StrEnum):
    ENTER = "enter"
    EXIT = "exit"
    NONE = "none"
    INITIAL = "initial"


class NotificationPlatform(StrEnum):
    ANDROID = "android"
    IOS = "ios"


class FirestoreModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Location(FirestoreModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class UserBase(FirestoreModel):
    display_name: str = Field(min_length=1)
    email: EmailStr


class UserCreate(UserBase):
    pass


class UserUpdate(FirestoreModel):
    display_name: str | None = Field(default=None, min_length=1)
    email: EmailStr | None = None


class User(UserBase):
    id: str
    created_at: datetime
    updated_at: datetime


class PetBase(FirestoreModel):
    owner_id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    species: str = Field(min_length=1)
    breed: str | None = None
    age: int | None = Field(default=None, ge=0)
    photo_url: str | None = None
    device_id: str | None = None


class PetCreate(PetBase):
    pass


class PetUpdate(FirestoreModel):
    name: str | None = Field(default=None, min_length=1)
    species: str | None = Field(default=None, min_length=1)
    breed: str | None = None
    age: int | None = Field(default=None, ge=0)
    photo_url: str | None = None
    device_id: str | None = None


class Pet(PetBase):
    id: str
    created_at: datetime
    updated_at: datetime


class DeviceBase(FirestoreModel):
    device_id: str = Field(min_length=1)
    owner_id: str = Field(min_length=1)
    pet_id: str | None = None
    status: DeviceStatus = DeviceStatus.UNREGISTERED
    device_secret_hash: str | None = None
    battery_level: int | None = Field(default=None, ge=0, le=100)
    current_location: Location | None = None
    last_seen: datetime | None = None
    last_location_update: datetime | None = None
    low_battery_alert_active: bool = False


class DeviceCreate(DeviceBase):
    pass


class DeviceUpdate(FirestoreModel):
    owner_id: str | None = Field(default=None, min_length=1)
    pet_id: str | None = None
    status: DeviceStatus | None = None
    device_secret_hash: str | None = None
    battery_level: int | None = Field(default=None, ge=0, le=100)
    current_location: Location | None = None
    last_seen: datetime | None = None
    last_location_update: datetime | None = None
    low_battery_alert_active: bool | None = None


class Device(DeviceBase):
    id: str
    created_at: datetime
    updated_at: datetime


class TrackingHistoryCreate(FirestoreModel):
    device_id: str = Field(min_length=1)
    pet_id: str = Field(min_length=1)
    owner_id: str = Field(min_length=1)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    battery_level: int | None = Field(default=None, ge=0, le=100)
    recorded_at: datetime | None = None


class TrackingHistory(TrackingHistoryCreate):
    id: str
    recorded_at: datetime


class GeofenceBase(FirestoreModel):
    owner_id: str = Field(min_length=1)
    pet_id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    center: Location
    radius_meters: float = Field(gt=0)
    enabled: bool = True
    last_state: GeofenceState | None = None
    last_state_changed_at: datetime | None = None
    last_checked_at: datetime | None = None


class GeofenceCreate(GeofenceBase):
    pass


class GeofenceUpdate(FirestoreModel):
    name: str | None = Field(default=None, min_length=1)
    center: Location | None = None
    radius_meters: float | None = Field(default=None, gt=0)
    enabled: bool | None = None
    last_state: GeofenceState | None = None
    last_state_changed_at: datetime | None = None
    last_checked_at: datetime | None = None


class Geofence(GeofenceBase):
    id: str
    created_at: datetime
    updated_at: datetime


class AlertCreate(FirestoreModel):
    owner_id: str = Field(min_length=1)
    pet_id: str | None = None
    device_id: str | None = None
    type: AlertType
    title: str = Field(min_length=1)
    message: str = Field(min_length=1)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    read: bool = False


class AlertUpdate(FirestoreModel):
    read: bool | None = None


class Alert(AlertCreate):
    id: str
    created_at: datetime


class NotificationTokenCreate(FirestoreModel):
    owner_id: str = Field(min_length=1)
    token: str = Field(min_length=1)
    platform: NotificationPlatform
    device_name: str | None = None
    active: bool = True
    last_used_at: datetime | None = None


class NotificationTokenUpdate(FirestoreModel):
    owner_id: str | None = Field(default=None, min_length=1)
    token: str | None = Field(default=None, min_length=1)
    platform: NotificationPlatform | None = None
    device_name: str | None = None
    active: bool | None = None
    last_used_at: datetime | None = None


class NotificationToken(NotificationTokenCreate):
    id: str
    created_at: datetime
    updated_at: datetime
