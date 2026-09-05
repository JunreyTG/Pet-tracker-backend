from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from firebase_admin import messaging

from app.main import app
from app.models.auth import AuthenticatedUser
from app.models.entities import Alert, AlertCreate, AlertType, DeviceStatus, NotificationPlatform, NotificationToken
from app.models.entities import Location
from app.schemas.notifications import NotificationTokenRegisterRequest
from app.schemas.telemetry import DeviceTelemetryRequest
from app.services.alert_service import AlertService
from app.services.auth_service import get_current_user
from app.services.device_service import DeviceAuthenticationError
from app.services.heartbeat_service import HeartbeatService
from app.services.notification_service import (
    NotificationService,
    NotificationTokenNotFoundError,
    get_notification_service,
    notification_token_id,
)
from app.services.telemetry_service import TelemetryService


client = TestClient(app)


def make_token(
    token_id: str | None = None,
    owner_id: str = "owner-1",
    token: str = "raw-fcm-token",
    active: bool = True,
    platform: NotificationPlatform = NotificationPlatform.ANDROID,
) -> NotificationToken:
    now = datetime.now(UTC)
    return NotificationToken(
        id=token_id or notification_token_id(token),
        owner_id=owner_id,
        token=token,
        platform=platform,
        device_name="Phone",
        active=active,
        created_at=now,
        updated_at=now,
        last_used_at=now,
    )


def make_alert(type: AlertType = AlertType.LOW_BATTERY, owner_id: str = "owner-1") -> Alert:
    return Alert(
        id="alert-1",
        owner_id=owner_id,
        pet_id="pet-1",
        device_id="PET-ESP32-001",
        type=type,
        title="Low Battery",
        message="Max's tracker battery is low (18%).",
        latitude=14.5995,
        longitude=120.9842,
        read=False,
        created_at=datetime.now(UTC),
    )


class FakeNotificationTokenRepository:
    def __init__(self) -> None:
        self.tokens: dict[str, NotificationToken] = {}
        self.created_count = 0
        self.updated: list[tuple[str, dict[str, Any]]] = []

    def get(self, token_id: str) -> NotificationToken | None:
        return self.tokens.get(token_id)

    def create(self, data, token_id: str) -> NotificationToken:
        self.created_count += 1
        token = make_token(token_id=token_id, owner_id=data.owner_id, token=data.token, active=data.active, platform=data.platform)
        token = token.model_copy(update={"device_name": data.device_name})
        self.tokens[token_id] = token
        return token

    def update_fields(self, token_id: str, payload: dict[str, Any]) -> NotificationToken | None:
        self.updated.append((token_id, payload))
        token = self.tokens.get(token_id)
        if token is None:
            return None
        clean_payload = {key: value for key, value in payload.items() if not key.endswith("_at")}
        updated = token.model_copy(update=clean_payload)
        self.tokens[token_id] = updated
        return updated

    def update(self, token_id: str, data) -> NotificationToken | None:
        return self.update_fields(token_id, data.model_dump(exclude_unset=True))

    def query_by_owner(self, owner_id: str) -> list[NotificationToken]:
        return [token for token in self.tokens.values() if token.owner_id == owner_id]

    def query_active_by_owner(self, owner_id: str) -> list[NotificationToken]:
        return [token for token in self.query_by_owner(owner_id) if token.active]


class FakeNotificationApiService:
    def __init__(self) -> None:
        self.repository = FakeNotificationTokenRepository()
        self.service = NotificationService(self.repository)
        self.repository.tokens["owner-token"] = make_token(token_id="owner-token", owner_id="owner-1")
        self.repository.tokens["other-token"] = make_token(token_id="other-token", owner_id="owner-2")

    def register_token(self, owner_id: str, data: NotificationTokenRegisterRequest) -> NotificationToken:
        return self.service.register_token(owner_id, data)

    def list_tokens(self, owner_id: str) -> list[NotificationToken]:
        return self.service.list_tokens(owner_id)

    def deactivate_token(self, owner_id: str, token_id: str) -> None:
        return self.service.deactivate_token(owner_id, token_id)


@pytest.fixture(autouse=True)
def clear_dependency_overrides() -> None:
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def fake_api_service() -> FakeNotificationApiService:
    service = FakeNotificationApiService()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="owner-1", email="owner@example.com")
    app.dependency_overrides[get_notification_service] = lambda: service
    return service


def test_authenticated_user_can_register_token_and_owner_is_derived(fake_api_service: FakeNotificationApiService) -> None:
    response = client.post(
        "/api/v1/notifications/tokens",
        json={"token": "new-token", "platform": "android", "device_name": "My Phone"},
    )
    assert response.status_code == 201
    token_id = response.json()["token_id"]
    assert fake_api_service.repository.tokens[token_id].owner_id == "owner-1"
    assert "token" not in response.json()


@pytest.mark.parametrize(
    "payload",
    [
        {"platform": "android"},
        {"token": "", "platform": "android"},
        {"token": "   ", "platform": "android"},
        {"token": "x", "platform": "web"},
        {"token": "x", "platform": "android", "owner_id": "owner-2"},
    ],
)
def test_invalid_registration_payloads_are_rejected(fake_api_service: FakeNotificationApiService, payload: dict[str, Any]) -> None:
    assert client.post("/api/v1/notifications/tokens", json=payload).status_code == 422


def test_duplicate_token_updates_and_reactivates_without_duplicate_record(fake_api_service: FakeNotificationApiService) -> None:
    token_id = notification_token_id("duplicate-token")
    fake_api_service.repository.tokens[token_id] = make_token(token_id=token_id, token="duplicate-token", active=False)
    response = client.post("/api/v1/notifications/tokens", json={"token": "duplicate-token", "platform": "ios"})
    assert response.status_code == 201
    assert fake_api_service.repository.created_count == 0
    assert fake_api_service.repository.tokens[token_id].active is True
    assert fake_api_service.repository.tokens[token_id].platform is NotificationPlatform.IOS


def test_multiple_tokens_can_belong_to_same_owner(fake_api_service: FakeNotificationApiService) -> None:
    client.post("/api/v1/notifications/tokens", json={"token": "token-a", "platform": "android"})
    client.post("/api/v1/notifications/tokens", json={"token": "token-b", "platform": "ios"})
    assert len(fake_api_service.service.list_tokens("owner-1")) == 3


def test_token_access_is_owner_scoped_and_raw_tokens_are_not_returned(fake_api_service: FakeNotificationApiService) -> None:
    response = client.get("/api/v1/notifications/tokens")
    assert response.status_code == 200
    assert [token["token_id"] for token in response.json()] == ["owner-token"]
    assert "token" not in response.json()[0]


def test_owner_can_delete_own_token_but_not_another_owners_token(fake_api_service: FakeNotificationApiService) -> None:
    assert client.delete("/api/v1/notifications/tokens/owner-token").status_code == 204
    assert fake_api_service.repository.tokens["owner-token"].active is False
    assert client.delete("/api/v1/notifications/tokens/other-token").status_code == 404


def test_unauthenticated_notification_token_api_is_rejected() -> None:
    assert client.get("/api/v1/notifications/tokens").status_code == 401
    assert client.post("/api/v1/notifications/tokens", json={"token": "x", "platform": "android"}).status_code == 401
    assert client.delete("/api/v1/notifications/tokens/token-id").status_code == 401


def test_registering_token_owned_by_another_user_is_rejected() -> None:
    repository = FakeNotificationTokenRepository()
    token_id = notification_token_id("shared-token")
    repository.tokens[token_id] = make_token(token_id=token_id, owner_id="owner-2", token="shared-token")
    with pytest.raises(NotificationTokenNotFoundError):
        NotificationService(repository).register_token(
            "owner-1", NotificationTokenRegisterRequest(token="shared-token", platform="android")
        )


def test_fcm_delivery_sends_to_active_owner_tokens_only(monkeypatch) -> None:
    repository = FakeNotificationTokenRepository()
    repository.tokens["active-a"] = make_token("active-a", token="token-a")
    repository.tokens["active-b"] = make_token("active-b", token="token-b")
    repository.tokens["inactive"] = make_token("inactive", token="token-c", active=False)
    repository.tokens["other"] = make_token("other", owner_id="owner-2", token="token-d")
    sent = []
    monkeypatch.setattr("app.services.notification_service.initialize_firebase_app", lambda: object())
    monkeypatch.setattr(messaging, "send", lambda message: sent.append(message) or "message-id")
    NotificationService(repository).send_alert_notification(make_alert())
    assert [message.token for message in sent] == ["token-a", "token-b"]


def test_fcm_message_uses_alert_title_body_and_string_data(monkeypatch) -> None:
    repository = FakeNotificationTokenRepository()
    repository.tokens["active"] = make_token("active")
    sent = []
    monkeypatch.setattr("app.services.notification_service.initialize_firebase_app", lambda: object())
    monkeypatch.setattr(messaging, "send", lambda message: sent.append(message) or "message-id")
    NotificationService(repository).send_alert_notification(make_alert(AlertType.DEVICE_OFFLINE))
    message = sent[0]
    assert message.notification.title == "Low Battery"
    assert message.notification.body == "Max's tracker battery is low (18%)."
    assert message.data == {
        "alert_id": "alert-1",
        "type": "device_offline",
        "pet_id": "pet-1",
        "device_id": "PET-ESP32-001",
    }
    assert all(isinstance(value, str) for value in message.data.values())
    assert "device_secret" not in message.data


def test_invalid_fcm_token_is_deactivated_and_raw_token_not_logged(monkeypatch, caplog) -> None:
    repository = FakeNotificationTokenRepository()
    repository.tokens["active"] = make_token("active", token="very-secret-fcm-token")
    monkeypatch.setattr("app.services.notification_service.initialize_firebase_app", lambda: object())

    def fail_send(message):
        raise messaging.UnregisteredError("invalid")

    monkeypatch.setattr(messaging, "send", fail_send)
    NotificationService(repository).send_alert_notification(make_alert())
    assert repository.tokens["active"].active is False
    assert "very-secret-fcm-token" not in caplog.text


def test_fcm_failure_does_not_fail_alert_creation_or_delete_alert(monkeypatch) -> None:
    class FailingNotificationService:
        def send_alert_notification(self, alert: Alert) -> None:
            from app.services.notification_service import NotificationDeliveryError

            raise NotificationDeliveryError("failed")

    class AlertRepository:
        def __init__(self) -> None:
            self.created = []

        def create(self, data: AlertCreate) -> Alert:
            self.created.append(data)
            return make_alert(data.type)

    from tests.test_alerts import FakePetRepository

    repository = AlertRepository()
    alert = AlertService(repository, FakePetRepository(), notification_service=FailingNotificationService()).create_low_battery_alert(
        make_device_for_alerts(), 18, Location(latitude=1, longitude=2)
    )
    assert alert.type is AlertType.LOW_BATTERY
    assert len(repository.created) == 1


def make_device_for_alerts(
    status: DeviceStatus = DeviceStatus.ONLINE,
    low_battery_alert_active: bool = False,
    last_seen: datetime | None = None,
):
    from tests.test_alerts import make_device

    return make_device(status=status, low_battery_alert_active=low_battery_alert_active, last_seen=last_seen)


class CapturingNotificationService:
    def __init__(self) -> None:
        self.alerts: list[Alert] = []

    def send_alert_notification(self, alert: Alert) -> None:
        self.alerts.append(alert)


def test_alert_service_triggers_fcm_for_all_alert_types() -> None:
    from tests.test_alerts import FakeAlertRepository, FakePetRepository

    notification_service = CapturingNotificationService()
    alert_service = AlertService(FakeAlertRepository(), FakePetRepository(), notification_service=notification_service)
    device = make_device_for_alerts(status=DeviceStatus.OFFLINE)
    location = Location(latitude=1, longitude=2)
    alert_service.create_device_offline_alert(device)
    alert_service.create_device_online_alert(device, location)
    alert_service.create_low_battery_alert(device, 18, location)
    assert [alert.type for alert in notification_service.alerts] == [
        AlertType.DEVICE_OFFLINE,
        AlertType.DEVICE_ONLINE,
        AlertType.LOW_BATTERY,
    ]


def test_duplicate_low_battery_online_and_offline_events_do_not_send_duplicate_fcm() -> None:
    from tests.test_alerts import FakeAlertRepository, FakeHeartbeatDeviceRepository, FakePetRepository, telemetry_service

    notification_service = CapturingNotificationService()
    alert_service = AlertService(FakeAlertRepository(), FakePetRepository(), notification_service=notification_service)
    service, _, _ = telemetry_service(make_device_for_alerts(low_battery_alert_active=True), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=18))
    service, _, _ = telemetry_service(make_device_for_alerts(status=DeviceStatus.ONLINE), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=80))
    heartbeat = HeartbeatService(FakeHeartbeatDeviceRepository([make_device_for_alerts(status=DeviceStatus.OFFLINE)]), alert_service=alert_service)
    heartbeat.check_devices_for_offline_status()
    assert notification_service.alerts == []


def test_initial_geofence_state_does_not_send_notification_and_cross_owner_isolation() -> None:
    repository = FakeNotificationTokenRepository()
    repository.tokens["other"] = make_token("other", owner_id="owner-2")
    assert NotificationService(repository).token_repository.query_active_by_owner("owner-1") == []


def test_fcm_failure_does_not_break_telemetry_or_heartbeat_processing() -> None:
    class FailingNotificationService:
        def send_alert_notification(self, alert: Alert) -> None:
            from app.services.notification_service import NotificationDeliveryError

            raise NotificationDeliveryError("failed")

    from tests.test_alerts import FakeAlertRepository, FakeHeartbeatDeviceRepository, FakePetRepository, telemetry_service

    alert_service = AlertService(FakeAlertRepository(), FakePetRepository(), notification_service=FailingNotificationService())
    service, _, _ = telemetry_service(make_device_for_alerts(status=DeviceStatus.OFFLINE), alert_service)
    service.receive_telemetry(DeviceTelemetryRequest(device_id="PET-ESP32-001", device_secret="s", latitude=1, longitude=2, battery_level=80))
    heartbeat = HeartbeatService(FakeHeartbeatDeviceRepository([make_device_for_alerts(last_seen=datetime(2026, 1, 1, 9, 0, tzinfo=UTC))]), alert_service=alert_service)
    heartbeat.check_devices_for_offline_status(current_time=datetime(2026, 1, 1, 10, 0, tzinfo=UTC))


def test_openapi_documents_notification_endpoints() -> None:
    paths = client.get("/openapi.json").json()["paths"]
    assert "/api/v1/notifications/tokens" in paths
    assert "/api/v1/notifications/tokens/{token_id}" in paths
