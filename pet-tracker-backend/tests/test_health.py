from fastapi.testclient import TestClient
from google.api_core.exceptions import ServiceUnavailable

from app.api import health
from app.main import app
from app.services.heartbeat_service import HeartbeatCheckResult


client = TestClient(app)


def test_health_check() -> None:
    response = client.get("/health")


    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "message": "Pet tracker backend API is running",
    }


def test_readiness_uses_bounded_firestore_read(monkeypatch) -> None:
    class Probe:
        def document(self, path):
            assert path == "system/readiness"
            return self

        def get(self, *, retry, timeout):
            assert retry is None and timeout == 4

    monkeypatch.setattr(health, "get_firestore_client", Probe)
    response = client.get("/ready")
    assert response.json() == {"status": "ready", "database": "ok"}
    assert response.headers["Cache-Control"] == "no-store"


def test_readiness_returns_503_without_leaking_failure_details(monkeypatch) -> None:
    def unavailable():
        raise ServiceUnavailable("private details")

    monkeypatch.setattr(health, "get_firestore_client", unavailable)
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"detail": "Database is not ready."}
    assert response.headers["Cache-Control"] == "no-store"


def test_offline_scheduler_requires_configured_secret(monkeypatch) -> None:
    class Worker:
        def check_devices_for_offline_status(self):
            return HeartbeatCheckResult(5, 3, 2)

    url = "/internal/check-offline"
    monkeypatch.setattr(health, "HeartbeatService", Worker)
    monkeypatch.setattr(health.settings, "device_offline_check_secret", None)
    assert client.post(url).status_code == 404
    secret = "s" * 32
    monkeypatch.setattr(health.settings, "device_offline_check_secret", secret)
    assert client.post(url).status_code == 401
    response = client.post(url, headers={"Authorization": f"Bearer {secret}"})
    assert response.status_code == 200 and response.json()["marked_offline_count"] == 3
