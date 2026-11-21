import re
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Any

from fastapi.testclient import TestClient
from firebase_admin import firestore

from app.main import app
from app.models.auth import AuthenticatedUser
from app.services import auth_service, email_account_service
from app.services.pet_service import get_pet_service


client = TestClient(app)
UNVERIFIED = {
    "phone": None,
    "location": None,
    "bio": None,
    "email_verified": False,
    "email_verification_required": False,
    "email_alerts_enabled": False,
}


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

    def get(self, transaction=None, **kwargs) -> FakeSnapshot:
        return FakeSnapshot(self.exists, self.data)

    def set(self, payload: dict[str, Any], merge: bool = False) -> None:
        self.set_calls.append((payload.copy(), merge))
        if merge:
            self.data.update(payload)
        else:
            self.data = payload.copy()
        self.exists = True

    def update(self, payload: dict[str, Any]) -> None:
        assert self.exists
        for field, value in payload.items():
            if value is firestore.DELETE_FIELD:
                self.data.pop(field, None)
            else:
                self.data[field] = value

    def create(self, payload: dict[str, Any]) -> None:
        assert not self.exists
        self.set(payload)


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

    def transaction(self):
        return self

    def update(self, document, payload):
        document.update(payload)


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
    monkeypatch.setattr(auth_service, "get_firestore_client", lambda: FakeClient(FakeDocument(True)))
    monkeypatch.setattr("app.api.auth.sync_current_user_profile", fake_sync)

    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer valid-token"})

    assert response.status_code == 200
    assert response.json() == {
        "uid": "user-1",
        "email": "owner@example.com",
        "display_name": "Owner",
        **UNVERIFIED,
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
        "user": {"uid": "user-1", "email": "owner@example.com", "display_name": "Owner", **UNVERIFIED},
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
        **UNVERIFIED,
    }
    assert document.set_calls[0][1] is True
    assert document.data["email"] == "owner@example.com"
    assert document.data["display_name"] == "Owner"
    assert "created_at" in document.data
    assert "updated_at" in document.data


def test_user_profile_is_authoritative_over_older_token_claims() -> None:
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
        "email": "old@example.com",
        "display_name": "Old Name",
        **UNVERIFIED,
    }
    assert not document.set_calls
    assert document.data["created_at"] == created_at
    assert document.data["unrelated_field"] == "preserved"
    assert document.data["email"] == "old@example.com"
    assert document.data["display_name"] == "Old Name"


def test_profile_write_survives_reload_and_keeps_email_read_only(monkeypatch) -> None:
    document = FakeDocument(True, {"email": "owner@example.com", "display_name": "Before", "password_hash": "keep"})
    monkeypatch.setattr(auth_service, "get_firestore_client", lambda: FakeClient(document))
    token = auth_service.create_access_token(AuthenticatedUser(uid="owner", email="owner@example.com", display_name="Before"))
    headers = {"Authorization": f"Bearer {token}"}
    response = client.patch("/api/v1/auth/me", json={"display_name": "  Updated  "}, headers=headers)
    assert response.status_code == 200 and response.json()["display_name"] == "Updated"
    assert client.get("/api/v1/auth/me", headers=headers).json()["display_name"] == "Updated"
    assert client.patch("/api/v1/auth/me", json={"display_name": "Different", "email": "other@example.com"}, headers=headers).status_code == 422
    assert document.data["email"] == "owner@example.com" and document.data["password_hash"] == "keep"


def test_profile_update_stores_contact_details_and_clears_empty_values(monkeypatch) -> None:
    document = FakeDocument(True, {"email": "owner@example.com", "display_name": "Owner"})
    monkeypatch.setattr(auth_service, "get_firestore_client", lambda: FakeClient(document))
    token = auth_service.create_access_token(AuthenticatedUser(uid="owner", email="owner@example.com", display_name="Owner"))
    headers = {"Authorization": f"Bearer {token}"}

    response = client.patch(
        "/api/v1/auth/me",
        json={"phone": " 0917 555 1234 ", "location": "Bongao, Tawi-Tawi", "bio": "Dog dad and weekend hiker."},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["phone"] == "0917 555 1234"
    assert response.json()["location"] == "Bongao, Tawi-Tawi"
    assert response.json()["bio"] == "Dog dad and weekend hiker."
    assert document.data["phone"] == "0917 555 1234"
    assert document.data["location"] == "Bongao, Tawi-Tawi"
    assert document.data["bio"] == "Dog dad and weekend hiker."

    cleared = client.patch("/api/v1/auth/me", json={"phone": ""}, headers=headers)
    assert cleared.status_code == 200 and cleared.json()["phone"] is None
    assert "phone" not in document.data

    assert client.patch("/api/v1/auth/me", json={}, headers=headers).status_code == 422
    assert client.patch("/api/v1/auth/me", json={"bio": "x" * 301}, headers=headers).status_code == 422


def test_password_change_validates_current_password_and_revokes_previous_sessions(monkeypatch) -> None:
    salt, digest = auth_service.create_password_hash("original-pass")
    document = FakeDocument(True, {
        "email": "owner@example.com", "display_name": "Owner", "password_salt": salt, "password_hash": digest,
    })
    store = FakeClient(document)
    monkeypatch.setattr(auth_service, "get_firestore_client", lambda: store)
    monkeypatch.setattr(auth_service.firestore, "transactional", lambda fn: fn)

    def login(password):
        return client.post("/api/v1/auth/login", json={"email": "owner@example.com", "password": password})

    previous = login("original-pass").json()["access_token"]
    headers = {"Authorization": f"Bearer {previous}"}
    url = "/api/v1/auth/password"
    response = client.post(url, json={"current_password": "incorrect", "new_password": "replacement-pass"}, headers=headers)
    assert response.status_code == 400
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200
    response = client.post(url, json={"current_password": "original-pass", "new_password": "replacement-pass"}, headers=headers)
    assert response.status_code == 204
    assert document.data["password_salt"] != salt
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    assert login("original-pass").status_code == 401
    fresh = login("replacement-pass").json()["access_token"]
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {fresh}"}).status_code == 200


def test_registration_does_not_require_email_and_verification_enables_optional_alerts(monkeypatch) -> None:
    document = FakeDocument(False)
    store = FakeClient(document)
    monkeypatch.setattr(auth_service, "get_firestore_client", lambda: store)
    monkeypatch.setattr(email_account_service, "get_firestore_client", lambda: store)
    monkeypatch.setattr(firestore, "transactional", lambda fn: fn)
    monkeypatch.setattr(email_account_service, "email_delivery_configured", lambda: False)
    monkeypatch.setitem(app.dependency_overrides, get_pet_service, lambda: SimpleNamespace(list_pets=lambda owner: []))
    delivered = []

    def capture(recipient, subject, text, *, idempotency_key):
        delivered.append((recipient, re.search(r"\b[0-9A-F]{16}\b", text)[0]))

    monkeypatch.setattr(email_account_service, "send_email", capture)
    payload = {"name": "Owner", "email": "owner@example.com", "password": "test-password"}
    assert client.post("/api/v1/auth/register", json={**payload, "email": "not-an-email"}).status_code == 422
    signup = client.post("/api/v1/auth/register", json=payload)
    assert signup.status_code == 201
    headers = {"Authorization": f"Bearer {signup.json()['access_token']}"}
    assert signup.json()["user"]["email_verification_required"] is False
    # Accounts registered before this change must also get access immediately.
    document.data["requires_email_verification"] = True
    assert client.get("/api/v1/auth/me", headers=headers).json()["email_verification_required"] is False
    assert client.get("/api/v1/pets", headers=headers).status_code == 200
    pref = "/api/v1/auth/email/alerts"
    assert client.patch(pref, json={"enabled": True}, headers=headers).status_code == 409
    send = "/api/v1/auth/email/send"
    assert client.post(send).status_code == 401
    assert client.post(send, headers=headers).status_code == 503
    monkeypatch.setattr(email_account_service, "email_delivery_configured", lambda: True)
    assert client.post(send, headers=headers).status_code == 204
    assert client.post(send, headers=headers).status_code == 429
    assert len(delivered) == 1 and delivered[0][0] == payload["email"]
    code = delivered[0][1]
    assert document.data["email_code_hash"] != code
    original_hash = document.data["email_code_hash"]
    document.data["email_code_sent_at"] -= timedelta(minutes=2)

    def reject_delivery(*args, **kwargs):
        raise email_account_service.EmailDeliveryError("Rejected")

    monkeypatch.setattr(email_account_service, "send_email", reject_delivery)
    assert client.post(send, headers=headers).status_code == 503
    assert document.data["email_code_hash"] == original_hash
    assert document.data["email_send_count"] == 1
    assert client.post(send, headers=headers).status_code == 429
    verify = "/api/v1/auth/email/verify"
    assert client.post(verify, json={"code": "X" * 16}, headers=headers).status_code == 400
    expiry = document.data["email_code_expires_at"]
    document.data["email_code_expires_at"] = datetime.now(UTC) - timedelta(seconds=1)
    assert client.post(verify, json={"code": code}, headers=headers).status_code == 400
    document.data["email_code_expires_at"] = expiry
    confirmed = client.post(verify, json={"code": code.lower()}, headers=headers)
    assert confirmed.status_code == 200
    assert confirmed.json()["email_verified"] is True
    assert confirmed.json()["email_verification_required"] is False
    assert confirmed.json()["email_alerts_enabled"] is False
    assert client.post(verify, json={"code": code}, headers=headers).status_code == 400
    assert client.patch(pref, json={"enabled": True}, headers=headers).json()["email_alerts_enabled"] is True
    assert client.patch(pref, json={"enabled": False}, headers=headers).json()["email_alerts_enabled"] is False

    # Re-registering a deleted account must not make an old session valid again.
    document.exists = False
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    assert client.post("/api/v1/auth/register", json=payload).status_code == 201
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
