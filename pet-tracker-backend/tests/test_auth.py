from datetime import UTC, datetime
from typing import Any

from fastapi.testclient import TestClient

from app.main import app
from app.models.auth import AuthenticatedUser
from app.services import auth_service


client = TestClient(app)


class FakeSnapshot:
    def __init__(self, exists: bool, data: dict[str, Any] | None = None) -> None:
        self.exists = exists
        self._data = data or {}

    def to_dict(self) -> dict[str, Any]:
        return self._data.copy()


class FakeDocument:
    def __init__(self, exists: bool, data: dict[str, Any] | None = None) -> None:
        self.exists = exists
        self.data = data or {}
        self.set_calls: list[tuple[dict[str, Any], bool]] = []

    def get(self) -> FakeSnapshot:
        return FakeSnapshot(self.exists, self.data)

    def set(self, payload: dict[str, Any], merge: bool = False) -> None:
        self.set_calls.append((payload.copy(), merge))
        if merge:
            self.data.update(payload)
        else:
            self.data = payload.copy()
        self.exists = True


class FakeCollection:
    def __init__(self, document: FakeDocument) -> None:
        self._document = document

    def document(self, document_id: str) -> FakeDocument:
        self.document_id = document_id
        return self._document


class FakeClient:
    def __init__(self, document: FakeDocument) -> None:
        self.collection_name: str | None = None
        self.collection_ref = FakeCollection(document)

    def collection(self, collection_name: str) -> FakeCollection:
        self.collection_name = collection_name
        return self.collection_ref


def test_auth_me_requires_authorization_header() -> None:
    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401


def test_auth_me_rejects_malformed_authorization_header() -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Token abc"})

    assert response.status_code == 401


def test_auth_me_rejects_token_with_extra_whitespace() -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer abc def"})

    assert response.status_code == 401


def test_auth_me_rejects_invalid_token() -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid"})

    assert response.status_code == 401


def test_auth_me_returns_authenticated_user_information(monkeypatch) -> None:
    def fake_verify(token: str) -> AuthenticatedUser:
        assert token == "valid-token"
        return AuthenticatedUser(uid="user-1", email="owner@example.com", display_name="Owner")

    def fake_sync(user: AuthenticatedUser) -> dict[str, Any]:
        return {
            "uid": user.uid,
            "email": user.email,
            "display_name": user.display_name,
        }

    monkeypatch.setattr(auth_service, "verify_access_token", fake_verify)
    monkeypatch.setattr("app.api.auth.sync_current_user_profile", fake_sync)

    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer valid-token"})

    assert response.status_code == 200
    assert response.json() == {
        "uid": "user-1",
        "email": "owner@example.com",
        "display_name": "Owner",
    }


def test_register_returns_token_and_user(monkeypatch) -> None:
    def fake_register(name: str, email: str, password: str) -> AuthenticatedUser:
        assert (name, email, password) == ("Owner", "owner@example.com", "secret123")
        return AuthenticatedUser(uid="user-1", email=email, display_name=name)

    monkeypatch.setattr("app.api.auth.register_with_password", fake_register)
    monkeypatch.setattr("app.api.auth.create_access_token", lambda user: f"token-for-{user.uid}")

    response = client.post(
        "/api/v1/auth/register",
        json={"name": "Owner", "email": "owner@example.com", "password": "secret123"},
    )

    assert response.status_code == 201
    assert response.json() == {
        "access_token": "token-for-user-1",
        "token_type": "bearer",
        "user": {"uid": "user-1", "email": "owner@example.com", "display_name": "Owner"},
    }


def test_login_returns_token_and_user(monkeypatch) -> None:
    def fake_authenticate(email: str, password: str) -> AuthenticatedUser:
        assert (email, password) == ("owner@example.com", "secret123")
        return AuthenticatedUser(uid="user-1", email=email, display_name="Owner")

    monkeypatch.setattr("app.api.auth.authenticate_with_password", fake_authenticate)
    monkeypatch.setattr("app.api.auth.create_access_token", lambda user: f"token-for-{user.uid}")

    response = client.post(
        "/api/v1/auth/login",
        json={"email": "owner@example.com", "password": "secret123"},
    )

    assert response.status_code == 200
    assert response.json()["access_token"] == "token-for-user-1"
    assert response.json()["user"]["email"] == "owner@example.com"


def test_health_remains_public() -> None:
    response = client.get("/health")

    assert response.status_code == 200


def test_user_profile_synchronization_creates_user_document() -> None:
    document = FakeDocument(exists=False)
    service = auth_service.UserProfileService(client=FakeClient(document))
    user = AuthenticatedUser(uid="firebase-user-1", email="owner@example.com", display_name="Owner")

    profile = service.sync_user_profile(user)

    assert profile == {
        "uid": "firebase-user-1",
        "email": "owner@example.com",
        "display_name": "Owner",
    }
    assert document.set_calls[0][1] is True
    assert document.data["email"] == "owner@example.com"
    assert document.data["display_name"] == "Owner"
    assert "created_at" in document.data
    assert "updated_at" in document.data


def test_user_profile_synchronization_updates_without_destroying_unrelated_data() -> None:
    created_at = datetime.now(UTC)
    document = FakeDocument(
        exists=True,
        data={
            "display_name": "Old Name",
            "email": "old@example.com",
            "created_at": created_at,
            "unrelated_field": "preserved",
        },
    )
    service = auth_service.UserProfileService(client=FakeClient(document))
    user = AuthenticatedUser(uid="firebase-user-1", email="new@example.com", display_name="New Name")

    profile = service.sync_user_profile(user)

    assert profile == {
        "uid": "firebase-user-1",
        "email": "new@example.com",
        "display_name": "New Name",
    }
    assert document.set_calls[0][1] is True
    assert document.data["created_at"] == created_at
    assert document.data["unrelated_field"] == "preserved"
    assert document.data["email"] == "new@example.com"
    assert document.data["display_name"] == "New Name"
