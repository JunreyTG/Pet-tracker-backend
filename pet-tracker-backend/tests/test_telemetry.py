from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.entities import Device, DeviceStatus, TrackingHistoryCreate
from app.schemas.telemetry import DeviceTelemetryRequest
from app.services.device_service import DeviceAuthenticationError
from app.services.telemetry_service import DeviceNotAssignedError, TelemetryService, get_telemetry_service


client = TestClient(app)


def make_device(
    device_id: str = "PET-ESP32-001",
    owner_id: str = "owner-1",
    pet_id: str | None = "pet-1",
) -> Device:
    now = datetime.now(UTC)
    return Device(
        id=device_id,
        device_id=device_id,
        owner_id=owner_id,
        pet_id=pet_id,
        status=DeviceStatus.UNREGISTERED,
        device_secret_hash="stored-hash",
        battery_level=None,
        current_location=None,
        last_seen=None,
        last_location_update=None,
        created_at=now,
        updated_at=now,
    )


class FakeDeviceAuthenticationService:
    def __init__(self, device: Device | None = None, should_reject: bool = False) -> None:
        self.device = device or make_device()
        self.should_reject = should_reject
        self.seen_credentials: tuple[str, str | None] | None = None

    def verify_device_credentials(self, device_id: str, device_secret: str | None) -> Device:
        self.seen_credentials = (device_id, device_secret)
        if self.should_reject:
            raise DeviceAuthenticationError("Invalid device credentials.")
        return self.device


class FakeDeviceRepository:
    def __init__(self) -> None:
        self.updated_device_id: str | None = None
        self.updated_payload: dict[str, Any] | None = None

    def update_fields(self, device_id: str, payload: dict[str, Any]) -> Device:
        self.updated_device_id = device_id
        self.updated_payload = payload
        return make_device(device_id=device_id)


class FakeTrackingHistoryRepository:
    def __init__(self) -> None:
        self.created: TrackingHistoryCreate | None = None

    def create(self, data: TrackingHistoryCreate) -> TrackingHistoryCreate:
        self.created = data
        return data


class FakeGeofenceService:
    def __init__(self) -> None:
        self.evaluated: tuple[str, Any] | None = None

    def evaluate_enabled_geofences_for_pet(self, pet_id: str, location: Any) -> list[Any]:
        self.evaluated = (pet_id, location)
        return []


class FakeTelemetryRouteService:
    def __init__(self, should_reject: bool = False, unassigned: bool = False) -> None:
        self.should_reject = should_reject
        self.unassigned = unassigned
        self.received: DeviceTelemetryRequest | None = None

    def receive_telemetry(self, data: DeviceTelemetryRequest) -> None:
        self.received = data
        if self.should_reject:
            raise DeviceAuthenticationError("Invalid device credentials.")
        if self.unassigned:
            raise DeviceNotAssignedError("Device is not assigned to a pet.")


@pytest.fixture(autouse=True)
def clear_dependency_overrides() -> None:
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


def telemetry_payload(**overrides: Any) -> dict[str, Any]:
    payload = {
        "device_id": "PET-ESP32-001",
        "device_secret": "raw-secret",
        "latitude": 14.5995,
        "longitude": 120.9842,
        "battery_level": 87,
    }
    payload.update(overrides)
    return payload


def test_valid_telemetry_succeeds() -> None:
    service = FakeTelemetryRouteService()
    app.dependency_overrides[get_telemetry_service] = lambda: service

    response = client.post("/api/v1/device/telemetry", json=telemetry_payload())

    assert response.status_code == 200
    assert response.json() == {"message": "Telemetry received successfully"}


def test_invalid_device_secret_returns_401() -> None:
    service = FakeTelemetryRouteService(should_reject=True)
    app.dependency_overrides[get_telemetry_service] = lambda: service

    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(device_secret="wrong"))

    assert response.status_code == 401


def test_unknown_device_returns_401() -> None:
    service = FakeTelemetryRouteService(should_reject=True)
    app.dependency_overrides[get_telemetry_service] = lambda: service

    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(device_id="UNKNOWN"))

    assert response.status_code == 401


def test_invalid_latitude_is_rejected() -> None:
    app.dependency_overrides[get_telemetry_service] = lambda: FakeTelemetryRouteService()
    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(latitude=200))

    assert response.status_code == 422



def test_invalid_longitude_is_rejected() -> None:
    app.dependency_overrides[get_telemetry_service] = lambda: FakeTelemetryRouteService()
    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(longitude=-300))

    assert response.status_code == 422



def test_invalid_battery_level_is_rejected() -> None:
    app.dependency_overrides[get_telemetry_service] = lambda: FakeTelemetryRouteService()
    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(battery_level=150))

    assert response.status_code == 422



def test_unassigned_device_cannot_submit_usable_tracking_data() -> None:
    service = FakeTelemetryRouteService(unassigned=True)
    app.dependency_overrides[get_telemetry_service] = lambda: service

    response = client.post("/api/v1/device/telemetry", json=telemetry_payload())

    assert response.status_code == 409


def test_valid_telemetry_updates_current_device_location() -> None:
    device_repository = FakeDeviceRepository()
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(),
        device_repository=device_repository,
        tracking_history_repository=FakeTrackingHistoryRepository(),
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert device_repository.updated_payload is not None
    assert device_repository.updated_payload["current_location"] == {
        "latitude": 14.5995,
        "longitude": 120.9842,
    }


def test_valid_telemetry_updates_battery_level() -> None:
    device_repository = FakeDeviceRepository()
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(),
        device_repository=device_repository,
        tracking_history_repository=FakeTrackingHistoryRepository(),
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload(battery_level=70)))

    assert device_repository.updated_payload is not None
    assert device_repository.updated_payload["battery_level"] == 70


def test_valid_telemetry_updates_last_seen_and_last_location_update() -> None:
    device_repository = FakeDeviceRepository()
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(),
        device_repository=device_repository,
        tracking_history_repository=FakeTrackingHistoryRepository(),
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert device_repository.updated_payload is not None
    assert "last_seen" in device_repository.updated_payload
    assert "last_location_update" in device_repository.updated_payload


def test_valid_telemetry_sets_device_status_online() -> None:
    device_repository = FakeDeviceRepository()
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(),
        device_repository=device_repository,
        tracking_history_repository=FakeTrackingHistoryRepository(),
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert device_repository.updated_payload is not None
    assert device_repository.updated_payload["status"] is DeviceStatus.ONLINE


def test_valid_telemetry_creates_tracking_history() -> None:
    history_repository = FakeTrackingHistoryRepository()
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(),
        device_repository=FakeDeviceRepository(),
        tracking_history_repository=history_repository,
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert history_repository.created is not None
    assert history_repository.created.device_id == "PET-ESP32-001"
    assert history_repository.created.latitude == 14.5995
    assert history_repository.created.longitude == 120.9842


def test_tracking_history_receives_owner_id_from_device_record() -> None:
    history_repository = FakeTrackingHistoryRepository()
    auth_service = FakeDeviceAuthenticationService(device=make_device(owner_id="real-owner"))
    service = TelemetryService(
        device_authentication_service=auth_service,
        device_repository=FakeDeviceRepository(),
        tracking_history_repository=history_repository,
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert history_repository.created is not None
    assert history_repository.created.owner_id == "real-owner"


def test_tracking_history_receives_pet_id_from_device_record() -> None:
    history_repository = FakeTrackingHistoryRepository()
    auth_service = FakeDeviceAuthenticationService(device=make_device(pet_id="real-pet"))
    service = TelemetryService(
        device_authentication_service=auth_service,
        device_repository=FakeDeviceRepository(),
        tracking_history_repository=history_repository,
        geofence_service=FakeGeofenceService(),
    )

    service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert history_repository.created is not None
    assert history_repository.created.pet_id == "real-pet"


def test_esp32_cannot_override_owner_id() -> None:
    app.dependency_overrides[get_telemetry_service] = lambda: FakeTelemetryRouteService()
    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(owner_id="fake-owner"))

    assert response.status_code == 422


def test_esp32_cannot_override_pet_id() -> None:
    app.dependency_overrides[get_telemetry_service] = lambda: FakeTelemetryRouteService()
    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(pet_id="fake-pet"))

    assert response.status_code == 422


def test_failed_authentication_does_not_create_tracking_history() -> None:
    history_repository = FakeTrackingHistoryRepository()
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(should_reject=True),
        device_repository=FakeDeviceRepository(),
        tracking_history_repository=history_repository,
        geofence_service=FakeGeofenceService(),
    )

    with pytest.raises(DeviceAuthenticationError):
        service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload()))

    assert history_repository.created is None


def test_raw_device_secret_is_not_returned_in_response() -> None:
    app.dependency_overrides[get_telemetry_service] = lambda: FakeTelemetryRouteService()

    response = client.post("/api/v1/device/telemetry", json=telemetry_payload(device_secret="super-secret"))

    assert response.status_code == 200
    assert "super-secret" not in response.text
    assert "device_secret" not in response.json()


def test_raw_device_secret_is_not_logged(caplog) -> None:
    service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(should_reject=True),
        device_repository=FakeDeviceRepository(),
        tracking_history_repository=FakeTrackingHistoryRepository(),
        geofence_service=FakeGeofenceService(),
    )

    with pytest.raises(DeviceAuthenticationError):
        service.receive_telemetry(DeviceTelemetryRequest(**telemetry_payload(device_secret="super-secret")))

    assert "super-secret" not in caplog.text


def test_openapi_documents_telemetry_endpoint() -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    assert "/api/v1/device/telemetry" in response.json()["paths"]
