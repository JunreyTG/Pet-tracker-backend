from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.auth import AuthenticatedUser
from app.models.entities import (
    Alert,
    AlertCreate,
    AlertType,
    Device,
    DeviceStatus,
    GeofenceState,
    GeofenceTransitionType,
    Location,
    Pet,
)
from app.schemas.alerts import AlertUpdateRequest
from app.schemas.geofences import GeofenceTransitionResult
from app.schemas.telemetry import DeviceTelemetryRequest
from app.services.alert_service import AlertNotFoundError, AlertService, get_alert_service
from app.services.auth_service import get_current_user
from app.services.device_service import DeviceAuthenticationError
from app.services.heartbeat_service import HeartbeatService
from app.services.telemetry_service import TelemetryService


client = TestClient(app)


def make_alert(
    alert_id: str = "alert-1",
    owner_id: str = "owner-1",
    pet_id: str | None = "pet-1",
    device_id: str | None = "PET-ESP32-001",
    type: AlertType = AlertType.LOW_BATTERY,
    read: bool = False,
) -> Alert:
    return Alert(
        id=alert_id,
        owner_id=owner_id,
        pet_id=pet_id,
        device_id=device_id,
        type=type,
        title="Low Battery",
        message="Max's tracker battery is low (18%).",
        latitude=14.5995,
        longitude=120.9842,
        read=read,
        created_at=datetime.now(UTC),
    )


def make_device(
    status: DeviceStatus = DeviceStatus.ONLINE,
    pet_id: str | None = "pet-1",
    low_battery_alert_active: bool = False,
    last_seen: datetime | None = None,
) -> Device:
    now = datetime.now(UTC)
    return Device(
        id="PET-ESP32-001",
        device_id="PET-ESP32-001",
        owner_id="owner-1",
        pet_id=pet_id,
        status=status,
        device_secret_hash="hash",
        battery_level=30,
        current_location=Location(latitude=14.5995, longitude=120.9842),
        last_seen=last_seen or now,
        last_location_update=now,
        low_battery_alert_active=low_battery_alert_active,
        created_at=now,
        updated_at=now,
    )


def make_pet() -> Pet:
    now = datetime.now(UTC)
    return Pet(id="pet-1", owner_id="owner-1", name="Max", species="dog", created_at=now, updated_at=now)


class FakeAlertApiService:
    def __init__(self) -> None:
        self.alerts = [
            make_alert("alert-1", read=False, type=AlertType.LOW_BATTERY),
            make_alert("alert-2", read=True, type=AlertType.GEOFENCE_EXIT),
            make_alert("alert-3", owner_id="owner-2"),
        ]
        self.deleted: tuple[str, str] | None = None

    def list_alerts(self, owner_id: str, pet_id=None, alert_type=None, read=None) -> list[Alert]:
        alerts = [alert for alert in self.alerts if alert.owner_id == owner_id]
        if pet_id is not None:
            alerts = [alert for alert in alerts if alert.pet_id == pet_id]
        if alert_type is not None:
            alerts = [alert for alert in alerts if alert.type == alert_type]
        if read is not None:
            alerts = [alert for alert in alerts if alert.read is read]
        return alerts

    def get_alert(self, owner_id: str, alert_id: str) -> Alert:
        for alert in self.alerts:
            if alert.id == alert_id and alert.owner_id == owner_id:
                return alert
        raise AlertNotFoundError("Alert was not found.")

    def update_alert(self, owner_id: str, alert_id: str, data: AlertUpdateRequest) -> Alert:
        alert = self.get_alert(owner_id, alert_id)
        return alert.model_copy(update={"read": data.read})

    def delete_alert(self, owner_id: str, alert_id: str) -> None:
        self.get_alert(owner_id, alert_id)
        self.deleted = (owner_id, alert_id)


class FakeAlertRepository:
    def __init__(self) -> None:
        self.created: list[AlertCreate] = []
        self.alerts = {"alert-1": make_alert(), "alert-2": make_alert("alert-2", owner_id="owner-2")}
        self.deleted_id: str | None = None

    def create(self, data: AlertCreate) -> Alert:
        self.created.append(data)
        return make_alert(alert_id=f"alert-{len(self.created)}", owner_id=data.owner_id, pet_id=data.pet_id, device_id=data.device_id, type=data.type, read=data.read)

    def query_by_owner(self, owner_id: str) -> list[Alert]:
        return [alert for alert in self.alerts.values() if alert.owner_id == owner_id]

    def get(self, alert_id: str) -> Alert | None:
        return self.alerts.get(alert_id)

    def update(self, alert_id: str, data) -> Alert | None:
        alert = self.alerts.get(alert_id)
        if alert is None:
            return None
        updated = alert.model_copy(update=data.model_dump(exclude_unset=True))
        self.alerts[alert_id] = updated
        return updated

    def delete(self, alert_id: str) -> None:
        self.deleted_id = alert_id


class FakePetRepository:
    def get(self, pet_id: str) -> Pet | None:
        return make_pet() if pet_id == "pet-1" else None


class FakeHeartbeatDeviceRepository:
    def __init__(self, devices: list[Device]) -> None:
        self.devices = devices
        self.updates: list[tuple[str, dict[str, Any]]] = []

    def query_by_status(self, status: str) -> list[Device]:
        return [device for device in self.devices if device.status == status]

    def update_fields(self, device_id: str, payload: dict[str, Any]) -> Device:
        self.updates.append((device_id, payload))
        return self.devices[0].model_copy(update=payload)


class FakeTelemetryDeviceRepository:
    def __init__(self) -> None:
        self.updates: list[tuple[str, dict[str, Any]]] = []

    def update_fields(self, device_id: str, payload: dict[str, Any]) -> Device:
        self.updates.append((device_id, payload))
        return make_device()


class FakeTelemetryHistoryRepository:
    def __init__(self) -> None:
        self.created = []

    def create(self, data):
        self.created.append(data)
        return data


class FakeTelemetryAuthService:
    def __init__(self, device: Device | None = None, reject: bool = False) -> None:
        self.device = device or make_device()
        self.reject = reject

    def verify_device_credentials(self, device_id: str, device_secret: str | None) -> Device:
        if self.reject:
            raise DeviceAuthenticationError("Invalid device credentials.")
        return self.device


class FakeTelemetryGeofenceService:
    def __init__(self, transitions: list[GeofenceTransitionResult] | None = None) -> None:
        self.transitions = transitions or []
        self.called = False

    def evaluate_enabled_geofences_for_pet(self, pet_id: str, location: Location) -> list[GeofenceTransitionResult]:
        self.called = True
        return self.transitions


@pytest.fixture(autouse=True)
def clear_dependency_overrides() -> None:
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def fake_api_service() -> FakeAlertApiService:
    service = FakeAlertApiService()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="owner-1", email="owner@example.com")
    app.dependency_overrides[get_alert_service] = lambda: service
    return service


def telemetry_service(device: Device, alert_service: AlertService, geofence_service=None) -> tuple[TelemetryService, FakeTelemetryDeviceRepository, FakeTelemetryHistoryRepository]:
    device_repository = FakeTelemetryDeviceRepository()
    history_repository = FakeTelemetryHistoryRepository()
    service = TelemetryService(
        device_authentication_service=FakeTelemetryAuthService(device=device),
        device_repository=device_repository,
        tracking_history_repository=history_repository,
        geofence_service=geofence_service or FakeTelemetryGeofenceService(),
        alert_service=alert_service,
        low_battery_threshold_percent=20,
    )
    return service, device_repository, history_repository


def test_device_offline_creates_one_alert_and_repeated_checks_do_not_duplicate() -> None:
    device = make_device(last_seen=datetime(2026, 1, 1, 9, 54, 59, tzinfo=UTC))
    device_repository = FakeHeartbeatDeviceRepository([device])
    alert_repository = FakeAlertRepository()
    service = HeartbeatService(device_repository, alert_service=AlertService(alert_repository, FakePetRepository()))
    service.check_devices_for_offline_status(current_time=datetime(2026, 1, 1, 10, 0, tzinfo=UTC))
    device_repository.devices[0] = device.model_copy(update={"status": DeviceStatus.OFFLINE})
    service.check_devices_for_offline_status(current_time=datetime(2026, 1, 1, 10, 10, tzinfo=UTC))
    assert [alert.type for alert in alert_repository.created] == [AlertType.DEVICE_OFFLINE]


def test_device_online_after_offline_creates_one_alert_and_online_to_online_does_not() -> None:
    alert_repository = FakeAlertRepository()
    alert_service = AlertService(alert_repository, FakePetRepository())
    service, _, _ = telemetry_service(make_device(status=DeviceStatus.OFFLINE), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=80))
    service, _, _ = telemetry_service(make_device(status=DeviceStatus.ONLINE), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=80))
    assert [alert.type for alert in alert_repository.created] == [AlertType.DEVICE_ONLINE]


def test_geofence_exit_enter_alerts_and_initial_states_do_not_alert() -> None:
    alert_repository = FakeAlertRepository()
    alert_service = AlertService(alert_repository, FakePetRepository())
    transitions = [
        GeofenceTransitionResult(geofence_id="g1", pet_id="pet-1", geofence_name="Home", previous_state=GeofenceState.INSIDE, current_state=GeofenceState.OUTSIDE, transition_detected=True, transition_type=GeofenceTransitionType.EXIT),
        GeofenceTransitionResult(geofence_id="g2", pet_id="pet-1", geofence_name="Park", previous_state=GeofenceState.OUTSIDE, current_state=GeofenceState.INSIDE, transition_detected=True, transition_type=GeofenceTransitionType.ENTER),
        GeofenceTransitionResult(geofence_id="g3", pet_id="pet-1", geofence_name="Yard", previous_state=None, current_state=GeofenceState.OUTSIDE, transition_detected=False, transition_type=GeofenceTransitionType.INITIAL),
        GeofenceTransitionResult(geofence_id="g4", pet_id="pet-1", geofence_name="Porch", previous_state=None, current_state=GeofenceState.INSIDE, transition_detected=False, transition_type=GeofenceTransitionType.INITIAL),
    ]
    service, _, _ = telemetry_service(make_device(), alert_service, FakeTelemetryGeofenceService(transitions))
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=80))
    assert [alert.type for alert in alert_repository.created] == [AlertType.GEOFENCE_EXIT, AlertType.GEOFENCE_ENTER]
    assert "Max has left Home." == alert_repository.created[0].message
    assert "Max has returned to Park." == alert_repository.created[1].message


def test_low_battery_duplicate_prevention_and_recovery_reset() -> None:
    alert_repository = FakeAlertRepository()
    alert_service = AlertService(alert_repository, FakePetRepository())
    service, device_repository, _ = telemetry_service(make_device(low_battery_alert_active=False), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=20))
    service, _, _ = telemetry_service(make_device(low_battery_alert_active=True), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=18))
    service, recovery_repository, _ = telemetry_service(make_device(low_battery_alert_active=True), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=30))
    service, _, _ = telemetry_service(make_device(low_battery_alert_active=False), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=19))
    assert [alert.type for alert in alert_repository.created] == [AlertType.LOW_BATTERY, AlertType.LOW_BATTERY]
    assert any(update[1].get("low_battery_alert_active") is True for update in device_repository.updates)
    assert any(update[1].get("low_battery_alert_active") is False for update in recovery_repository.updates)


def test_alert_data_contains_trusted_fields_read_false_location_timestamp_and_message() -> None:
    alert_repository = FakeAlertRepository()
    AlertService(alert_repository, FakePetRepository()).create_low_battery_alert(make_device(), 18, Location(latitude=1, longitude=2))
    alert = alert_repository.created[0]
    assert alert.owner_id == "owner-1"
    assert alert.pet_id == "pet-1"
    assert alert.device_id == "PET-ESP32-001"
    assert alert.type is AlertType.LOW_BATTERY
    assert alert.read is False
    assert alert.latitude == 1
    assert alert.longitude == 2
    assert "18%" in alert.message
    assert not hasattr(alert, "created_at")


def test_alert_api_security_filters_and_crud(fake_api_service: FakeAlertApiService) -> None:
    assert client.get("/api/v1/alerts").status_code == 200
    assert len(client.get("/api/v1/alerts?read=false").json()) == 1
    assert len(client.get("/api/v1/alerts?type=geofence_exit").json()) == 1
    assert len(client.get("/api/v1/alerts?pet_id=pet-1").json()) == 2
    assert client.get("/api/v1/alerts/alert-1").status_code == 200
    assert client.get("/api/v1/alerts/alert-3").status_code == 404
    assert client.patch("/api/v1/alerts/alert-1", json={"read": True}).json()["read"] is True
    assert client.patch("/api/v1/alerts/alert-1", json={"read": False}).json()["read"] is False
    assert client.patch("/api/v1/alerts/alert-3", json={"read": True}).status_code == 404
    assert client.delete("/api/v1/alerts/alert-3").status_code == 404
    assert client.delete("/api/v1/alerts/alert-1").status_code == 204


def test_client_cannot_override_server_controlled_alert_fields(fake_api_service: FakeAlertApiService) -> None:
    payload = {"read": True, "owner_id": "owner-2"}
    assert client.patch("/api/v1/alerts/alert-1", json=payload).status_code == 422
    assert client.patch("/api/v1/alerts/alert-1", json={"type": "device_offline"}).status_code == 422
    assert client.patch("/api/v1/alerts/alert-1", json={"pet_id": "pet-2"}).status_code == 422
    assert client.patch("/api/v1/alerts/alert-1", json={"device_id": "device-2"}).status_code == 422


def test_unauthenticated_alert_api_access_is_rejected() -> None:
    assert client.get("/api/v1/alerts").status_code == 401
    assert client.get("/api/v1/alerts/alert-1").status_code == 401
    assert client.patch("/api/v1/alerts/alert-1", json={"read": True}).status_code == 401
    assert client.delete("/api/v1/alerts/alert-1").status_code == 401


def test_missing_alert_returns_404(fake_api_service: FakeAlertApiService) -> None:
    assert client.get("/api/v1/alerts/missing").status_code == 404


def test_invalid_telemetry_and_failed_authentication_create_no_alerts() -> None:
    alert_repository = FakeAlertRepository()
    alert_service = AlertService(alert_repository, FakePetRepository())
    with pytest.raises(Exception):
        DeviceTelemetryRequest(device_id="d", device_secret="s", latitude=999, longitude=0, battery_level=10)
    service = TelemetryService(
        device_authentication_service=FakeTelemetryAuthService(reject=True),
        device_repository=FakeTelemetryDeviceRepository(),
        tracking_history_repository=FakeTelemetryHistoryRepository(),
        geofence_service=FakeTelemetryGeofenceService(),
        alert_service=alert_service,
    )
    with pytest.raises(DeviceAuthenticationError):
        service.receive_telemetry(DeviceTelemetryRequest(device_id="d", device_secret="s", latitude=1, longitude=2, battery_level=10))
    assert alert_repository.created == []


def test_disabled_and_unregistered_devices_do_not_generate_heartbeat_alerts() -> None:
    alert_repository = FakeAlertRepository()
    heartbeat = HeartbeatService(
        FakeHeartbeatDeviceRepository([
            make_device(status=DeviceStatus.DISABLED),
            make_device(status=DeviceStatus.UNREGISTERED),
        ]),
        alert_service=AlertService(alert_repository, FakePetRepository()),
    )
    heartbeat.check_devices_for_offline_status()
    assert alert_repository.created == []


def test_offline_state_does_not_create_geofence_alert_without_new_gps_telemetry() -> None:
    alert_repository = FakeAlertRepository()
    heartbeat = HeartbeatService(
        FakeHeartbeatDeviceRepository([make_device(last_seen=datetime(2026, 1, 1, 9, 0, tzinfo=UTC))]),
        alert_service=AlertService(alert_repository, FakePetRepository()),
    )
    heartbeat.check_devices_for_offline_status(current_time=datetime(2026, 1, 1, 10, 0, tzinfo=UTC))
    assert [alert.type for alert in alert_repository.created] == [AlertType.DEVICE_OFFLINE]


def test_multiple_geofences_can_independently_create_enter_exit_alerts() -> None:
    alert_repository = FakeAlertRepository()
    alert_service = AlertService(alert_repository, FakePetRepository())
    transitions = [
        GeofenceTransitionResult(geofence_id="g1", pet_id="pet-1", geofence_name="Home", previous_state=GeofenceState.INSIDE, current_state=GeofenceState.OUTSIDE, transition_detected=True, transition_type=GeofenceTransitionType.EXIT),
        GeofenceTransitionResult(geofence_id="g2", pet_id="pet-1", geofence_name="Park", previous_state=GeofenceState.OUTSIDE, current_state=GeofenceState.INSIDE, transition_detected=True, transition_type=GeofenceTransitionType.ENTER),
    ]
    service, _, _ = telemetry_service(make_device(), alert_service, FakeTelemetryGeofenceService(transitions))
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=80))
    assert [alert.type for alert in alert_repository.created] == [AlertType.GEOFENCE_EXIT, AlertType.GEOFENCE_ENTER]


def test_openapi_documents_alert_endpoints() -> None:
    paths = client.get("/openapi.json").json()["paths"]
    assert "/api/v1/alerts" in paths
    assert "/api/v1/alerts/{alert_id}" in paths
