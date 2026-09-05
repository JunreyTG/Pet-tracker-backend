from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from app.models.entities import (
    AlertCreate,
    AlertType,
    DeviceCreate,
    DeviceStatus,
    GeofenceCreate,
    Location,
    PetCreate,
    TrackingHistoryCreate,
    UserCreate,
)


def test_user_requires_valid_email() -> None:
    user = UserCreate(display_name="Owner", email="owner@example.com")

    assert user.email == "owner@example.com"

    with pytest.raises(ValidationError):
        UserCreate(display_name="Owner", email="not-an-email")


@pytest.mark.parametrize("latitude", [-90, 0, 90])
def test_location_accepts_valid_latitude(latitude: float) -> None:
    location = Location(latitude=latitude, longitude=120.5)

    assert location.latitude == latitude


@pytest.mark.parametrize("latitude", [-90.1, 90.1])
def test_location_rejects_invalid_latitude(latitude: float) -> None:
    with pytest.raises(ValidationError):
        Location(latitude=latitude, longitude=0)


@pytest.mark.parametrize("longitude", [-180, 0, 180])
def test_location_accepts_valid_longitude(longitude: float) -> None:
    location = Location(latitude=45.1, longitude=longitude)

    assert location.longitude == longitude


@pytest.mark.parametrize("longitude", [-180.1, 180.1])
def test_location_rejects_invalid_longitude(longitude: float) -> None:
    with pytest.raises(ValidationError):
        Location(latitude=0, longitude=longitude)


@pytest.mark.parametrize("battery_level", [0, 50, 100])
def test_device_accepts_valid_battery_percentage(battery_level: int) -> None:
    device = DeviceCreate(
        device_id="tracker-1",
        owner_id="owner-1",
        status=DeviceStatus.ONLINE,
        battery_level=battery_level,
    )

    assert device.battery_level == battery_level


@pytest.mark.parametrize("battery_level", [-1, 101])
def test_device_rejects_invalid_battery_percentage(battery_level: int) -> None:
    with pytest.raises(ValidationError):
        DeviceCreate(device_id="tracker-1", owner_id="owner-1", battery_level=battery_level)


def test_pet_represents_at_most_one_device() -> None:
    pet = PetCreate(
        owner_id="owner-1",
        name="Milo",
        species="cat",
        device_id="tracker-1",
    )

    assert pet.device_id == "tracker-1"
    assert isinstance(pet.device_id, str)


def test_geofence_requires_positive_radius() -> None:
    geofence = GeofenceCreate(
        owner_id="owner-1",
        pet_id="pet-1",
        name="Home",
        center=Location(latitude=10, longitude=20),
        radius_meters=25,
    )

    assert geofence.radius_meters == 25

    with pytest.raises(ValidationError):
        GeofenceCreate(
            owner_id="owner-1",
            pet_id="pet-1",
            name="Home",
            center=Location(latitude=10, longitude=20),
            radius_meters=0,
        )


def test_tracking_history_validates_location_and_battery() -> None:
    recorded_at = datetime.now(UTC)
    history = TrackingHistoryCreate(
        device_id="tracker-1",
        pet_id="pet-1",
        owner_id="owner-1",
        latitude=12.5,
        longitude=77.6,
        battery_level=80,
        recorded_at=recorded_at,
    )

    assert history.recorded_at == recorded_at

    with pytest.raises(ValidationError):
        TrackingHistoryCreate(
            device_id="tracker-1",
            pet_id="pet-1",
            owner_id="owner-1",
            latitude=91,
            longitude=77.6,
            battery_level=80,
        )


def test_alert_type_is_represented_as_enum() -> None:
    alert = AlertCreate(
        owner_id="owner-1",
        pet_id="pet-1",
        device_id="tracker-1",
        type=AlertType.LOW_BATTERY,
        title="Low battery",
        message="Tracker battery is low.",
        latitude=1.2,
        longitude=3.4,
    )

    assert alert.type is AlertType.LOW_BATTERY
    assert alert.read is False

    with pytest.raises(ValidationError):
        AlertCreate(
            owner_id="owner-1",
            type="unsupported",
            title="Unknown",
            message="Unsupported alert type.",
        )
