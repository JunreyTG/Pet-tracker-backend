from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from google.api_core.exceptions import GoogleAPIError

from app.core.config import Settings
from app.models.entities import Device, DeviceStatus
from app.schemas.telemetry import DeviceTelemetryRequest
from app.services.heartbeat_service import HeartbeatService, HeartbeatServiceError
from app.services.telemetry_service import TelemetryService


def make_device(
    device_id: str = "PET-ESP32-001",
    status: DeviceStatus = DeviceStatus.ONLINE,
    last_seen: datetime | None = None,
    pet_id: str | None = "pet-1",
) -> Device:
    now = datetime.now(UTC)
    return Device(
        id=device_id,
        device_id=device_id,
        owner_id="owner-1",
        pet_id=pet_id,
        status=status,
        device_secret_hash="stored-hash",
        battery_level=None,
        current_location=None,
        last_seen=last_seen,
        last_location_update=None,
        created_at=now,
        updated_at=now,
    )


class FakeDeviceRepository:
    def __init__(self, devices: list[Device], should_fail: bool = False) -> None:
        self.devices = {device.device_id: device for device in devices}
        self.should_fail = should_fail
        self.queried_status: str | None = None
        self.updates: list[tuple[str, dict[str, Any]]] = []

    def query_by_status(self, status: str) -> list[Device]:
        if self.should_fail:
            raise GoogleAPIError("boom")
        self.queried_status = status
        return [device for device in self.devices.values() if device.status == status]

    def update_fields(self, device_id: str, payload: dict[str, Any]) -> Device:
        self.updates.append((device_id, payload))
        device = self.devices[device_id]
        self.devices[device_id] = device.model_copy(update=payload)
        return self.devices[device_id]


class FakeTelemetryDeviceRepository:
    def __init__(self) -> None:
        self.updated_payload: dict[str, Any] | None = None

    def update_fields(self, device_id: str, payload: dict[str, Any]) -> Device:
        self.updated_payload = payload
        return make_device(device_id=device_id, status=payload["status"])


class FakeTrackingHistoryRepository:
    def create(self, data) -> object:
        return data


class FakeGeofenceService:
    def evaluate_enabled_geofences_for_pet(self, pet_id: str, location) -> list[object]:
        return []


class FakeAlertService:
    def __init__(self) -> None:
        self.offline_devices = []
        self.online_devices = []

    def create_device_offline_alert(self, device: Device) -> object:
        self.offline_devices.append(device.device_id)
        return object()

    def create_device_online_alert(self, device: Device, location) -> object:
        self.online_devices.append(device.device_id)
        return object()


class FakeDeviceAuthenticationService:
    def verify_device_credentials(self, device_id: str, device_secret: str | None) -> Device:
        return make_device(device_id=device_id, status=DeviceStatus.OFFLINE)


def test_recent_last_seen_remains_online() -> None:
    now = datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    repository = FakeDeviceRepository([make_device(last_seen=now - timedelta(seconds=299))])
    result = HeartbeatService(repository, alert_service=FakeAlertService()).check_devices_for_offline_status(current_time=now)

    assert result.marked_offline_count == 0
    assert repository.updates == []


def test_last_seen_older_than_threshold_becomes_offline() -> None:
    now = datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    repository = FakeDeviceRepository([make_device(last_seen=now - timedelta(seconds=301))])
    result = HeartbeatService(repository, alert_service=FakeAlertService()).check_devices_for_offline_status(current_time=now)

    assert result.marked_offline_count == 1
    assert repository.updates == [("PET-ESP32-001", {"status": DeviceStatus.OFFLINE})]


def test_device_exactly_at_threshold_remains_online() -> None:
    now = datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    repository = FakeDeviceRepository([make_device(last_seen=now - timedelta(seconds=300))])

    HeartbeatService(repository).check_devices_for_offline_status(current_time=now)

    assert repository.updates == []


def test_device_without_last_seen_is_not_marked_offline() -> None:
    repository = FakeDeviceRepository([make_device(last_seen=None)])

    result = HeartbeatService(repository).check_devices_for_offline_status()

    assert result.marked_offline_count == 0
    assert repository.updates == []


def test_unregistered_devices_are_skipped() -> None:
    repository = FakeDeviceRepository([make_device(status=DeviceStatus.UNREGISTERED, last_seen=None)])

    result = HeartbeatService(repository).check_devices_for_offline_status()

    assert repository.queried_status == DeviceStatus.ONLINE
    assert result.checked_count == 0
    assert repository.updates == []


def test_disabled_devices_are_skipped() -> None:
    repository = FakeDeviceRepository([make_device(status=DeviceStatus.DISABLED, last_seen=datetime.now(UTC) - timedelta(hours=1))])
    result = HeartbeatService(repository).check_devices_for_offline_status()

    assert result.checked_count == 0
    assert repository.updates == []


def test_already_offline_devices_do_not_receive_repeated_updates() -> None:
    repository = FakeDeviceRepository([make_device(status=DeviceStatus.OFFLINE, last_seen=datetime.now(UTC) - timedelta(hours=1))])
    result = HeartbeatService(repository).check_devices_for_offline_status()

    assert result.checked_count == 0
    assert repository.updates == []


def test_heartbeat_checking_does_not_modify_last_seen() -> None:
    last_seen = datetime(2026, 1, 1, 9, 54, 59, tzinfo=UTC)
    repository = FakeDeviceRepository([make_device(last_seen=last_seen)])

    HeartbeatService(repository, alert_service=FakeAlertService()).check_devices_for_offline_status(
        current_time=datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    )

    assert "last_seen" not in repository.updates[0][1]


def test_offline_device_can_later_become_online_through_valid_telemetry() -> None:
    device_repository = FakeTelemetryDeviceRepository()
    telemetry_service = TelemetryService(
        device_authentication_service=FakeDeviceAuthenticationService(),
        device_repository=device_repository,
        tracking_history_repository=FakeTrackingHistoryRepository(),
        geofence_service=FakeGeofenceService(),
        alert_service=FakeAlertService(),
    )

    telemetry_service.receive_telemetry(
        DeviceTelemetryRequest(
            device_id="PET-ESP32-001",
            device_secret="raw-secret",
            latitude=14.5995,
            longitude=120.9842,
            battery_level=87,
        )
    )

    assert device_repository.updated_payload is not None
    assert device_repository.updated_payload["status"] is DeviceStatus.ONLINE


def test_offline_threshold_is_configurable() -> None:
    now = datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    repository = FakeDeviceRepository([make_device(last_seen=now - timedelta(seconds=61))])

    HeartbeatService(repository, offline_threshold_seconds=60, alert_service=FakeAlertService()).check_devices_for_offline_status(
        current_time=now
    )

    assert repository.updates == [("PET-ESP32-001", {"status": DeviceStatus.OFFLINE})]


def test_default_threshold_is_300_seconds() -> None:
    assert Settings().device_offline_threshold_seconds == 300


def test_time_comparison_uses_timezone_aware_utc_values() -> None:
    service = HeartbeatService(FakeDeviceRepository([]))
    naive_time = datetime(2026, 1, 1, 10, 0)

    utc_time = service._to_utc(naive_time)

    assert utc_time.tzinfo is UTC


def test_multiple_devices_can_be_checked() -> None:
    now = datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    repository = FakeDeviceRepository(
        [
            make_device(device_id="device-1", last_seen=now - timedelta(seconds=301)),
            make_device(device_id="device-2", last_seen=now - timedelta(seconds=10)),
            make_device(device_id="device-3", last_seen=now - timedelta(seconds=600)),
        ]
    )

    result = HeartbeatService(repository, alert_service=FakeAlertService()).check_devices_for_offline_status(current_time=now)

    assert result.checked_count == 3
    assert result.marked_offline_count == 2


def test_only_devices_requiring_status_transition_are_updated() -> None:
    now = datetime(2026, 1, 1, 10, 0, tzinfo=UTC)
    repository = FakeDeviceRepository(
        [
            make_device(device_id="device-1", last_seen=now - timedelta(seconds=301)),
            make_device(device_id="device-2", last_seen=now - timedelta(seconds=300)),
            make_device(device_id="device-3", last_seen=None),
        ]
    )

    HeartbeatService(repository, alert_service=FakeAlertService()).check_devices_for_offline_status(current_time=now)

    assert repository.updates == [("device-1", {"status": DeviceStatus.OFFLINE})]


def test_firestore_service_errors_are_handled_safely() -> None:
    service = HeartbeatService(FakeDeviceRepository([], should_fail=True))

    with pytest.raises(HeartbeatServiceError, match="Heartbeat check could not be completed"):
        service.check_devices_for_offline_status()
