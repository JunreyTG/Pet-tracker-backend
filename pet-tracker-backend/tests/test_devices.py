from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.auth import AuthenticatedUser
from app.models.entities import Device, DeviceCreate, DeviceStatus, DeviceUpdate, Pet
from app.services.auth_service import get_current_user
from app.services.device_credentials import hash_device_secret, verify_device_secret
from app.services.device_service import (
    DeviceAuthenticationError,
    DeviceAuthenticationService,
    DeviceConflictError,
    DeviceNotFoundError,
    DeviceRegistration,
    DeviceService,
    get_device_service,
)


client = TestClient(app)


def make_device(
    device_id: str = "PET-ESP32-001",
    owner_id: str = "owner-1",
    pet_id: str | None = None,
    device_secret_hash: str | None = "stored-hash",
) -> Device:
    now = datetime.now(UTC)
    return Device(
        id=device_id,
        device_id=device_id,
        owner_id=owner_id,
        pet_id=pet_id,
        status=DeviceStatus.UNREGISTERED,
        device_secret_hash=device_secret_hash,
        battery_level=None,
        current_location=None,
        last_seen=None,
        last_location_update=None,
        created_at=now,
        updated_at=now,
    )


def make_pet(pet_id: str = "pet-1", owner_id: str = "owner-1", device_id: str | None = None) -> Pet:
    now = datetime.now(UTC)
    return Pet(
        id=pet_id,
        owner_id=owner_id,
        name="Max",
        species="dog",
        breed=None,
        age=None,
        photo_url=None,
        device_id=device_id,
        created_at=now,
        updated_at=now,
    )


class FakeDeviceApiService:
    def __init__(self) -> None:
        self.registered_owner_id: str | None = None
        self.devices = [
            make_device(),
            make_device(device_id="PET-ESP32-002", owner_id="owner-2"),
        ]

    def register_device(self, owner_id: str, data) -> DeviceRegistration:
        self.registered_owner_id = owner_id
        if data.device_id == "duplicate-device":
            raise DeviceConflictError("Device is already registered.")
        return DeviceRegistration(
            device=make_device(device_id=data.device_id, owner_id=owner_id, device_secret_hash="hash"),
            device_secret="raw-secret",
        )

    def list_devices(self, owner_id: str) -> list[Device]:
        return [device for device in self.devices if device.owner_id == owner_id]

    def get_device(self, owner_id: str, device_id: str) -> Device:
        for device in self.devices:
            if device.device_id == device_id and device.owner_id == owner_id:
                return device
        raise DeviceNotFoundError("Device was not found.")

    def assign_device_to_pet(self, owner_id: str, device_id: str, pet_id: str) -> Device:
        device = self.get_device(owner_id, device_id)
        return device.model_copy(update={"pet_id": pet_id})

    def unassign_device(self, owner_id: str, device_id: str) -> Device:
        device = self.get_device(owner_id, device_id)
        return device.model_copy(update={"pet_id": None})


class FakeDocumentRef:
    def __init__(self, repository: Any, document_id: str) -> None:
        self.repository = repository
        self.document_id = document_id

    def apply_update(self, payload: dict[str, Any]) -> None:
        self.repository.apply_update(self.document_id, payload)


class FakeCollection:
    def __init__(self, repository: Any) -> None:
        self.repository = repository

    def document(self, document_id: str) -> FakeDocumentRef:
        return FakeDocumentRef(self.repository, document_id)


class FakeBatch:
    def __init__(self) -> None:
        self.updates: list[tuple[FakeDocumentRef, dict[str, Any]]] = []

    def update(self, ref: FakeDocumentRef, payload: dict[str, Any]) -> None:
        self.updates.append((ref, payload))

    def commit(self) -> None:
        for ref, payload in self.updates:
            ref.apply_update(payload)


class FakeClient:
    def batch(self) -> FakeBatch:
        return FakeBatch()


class FakeDeviceRepository:
    def __init__(self) -> None:
        self.client = FakeClient()
        self.collection = FakeCollection(self)
        self.created: DeviceCreate | None = None
        self.devices: dict[str, Device] = {
            "PET-ESP32-001": make_device(device_id="PET-ESP32-001", owner_id="owner-1"),
            "PET-ESP32-002": make_device(device_id="PET-ESP32-002", owner_id="owner-2"),
            "PET-ESP32-003": make_device(device_id="PET-ESP32-003", owner_id="owner-1", pet_id="pet-2"),
        }

    def create(self, data: DeviceCreate) -> Device:
        self.created = data
        device = make_device(
            device_id=data.device_id,
            owner_id=data.owner_id,
            pet_id=data.pet_id,
            device_secret_hash=data.device_secret_hash,
        )
        self.devices[device.device_id] = device
        return device

    def query_by_owner(self, owner_id: str) -> list[Device]:
        return [device for device in self.devices.values() if device.owner_id == owner_id]

    def get(self, device_id: str) -> Device | None:
        return self.devices.get(device_id)

    def apply_update(self, device_id: str, payload: dict[str, Any]) -> None:
        device = self.devices[device_id]
        clean_payload = {key: value for key, value in payload.items() if key != "updated_at"}
        self.devices[device_id] = device.model_copy(update=clean_payload)


class FakePetRepository:
    def __init__(self) -> None:
        self.collection = FakeCollection(self)
        self.pets: dict[str, Pet] = {
            "pet-1": make_pet(pet_id="pet-1", owner_id="owner-1"),
            "pet-2": make_pet(pet_id="pet-2", owner_id="owner-1", device_id="PET-ESP32-003"),
            "pet-3": make_pet(pet_id="pet-3", owner_id="owner-2"),
        }

    def get(self, pet_id: str) -> Pet | None:
        return self.pets.get(pet_id)

    def apply_update(self, pet_id: str, payload: dict[str, Any]) -> None:
        pet = self.pets[pet_id]
        clean_payload = {key: value for key, value in payload.items() if key != "updated_at"}
        self.pets[pet_id] = pet.model_copy(update=clean_payload)


@pytest.fixture(autouse=True)
def clear_dependency_overrides() -> None:
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def fake_device_api_service() -> FakeDeviceApiService:
    service = FakeDeviceApiService()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="owner-1",
        email="owner@example.com",
        display_name="Owner",
    )
    app.dependency_overrides[get_device_service] = lambda: service
    return service


def test_unauthenticated_registration_returns_401() -> None:
    response = client.post("/api/v1/devices", json={"device_id": "PET-ESP32-001"})

    assert response.status_code == 401


def test_authenticated_user_can_register_device(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.post("/api/v1/devices", json={"device_id": "PET-ESP32-010"})

    assert response.status_code == 201
    assert response.json()["device_id"] == "PET-ESP32-010"


def test_registered_device_receives_authenticated_owner_id(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.post("/api/v1/devices", json={"device_id": "PET-ESP32-010"})

    assert response.status_code == 201
    assert response.json()["owner_id"] == "owner-1"
    assert fake_device_api_service.registered_owner_id == "owner-1"


def test_new_device_status_is_unregistered(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.post("/api/v1/devices", json={"device_id": "PET-ESP32-010"})

    assert response.json()["status"] == "unregistered"


def test_device_secret_is_generated_and_hash_is_not_returned(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.post("/api/v1/devices", json={"device_id": "PET-ESP32-010"})
    body = response.json()

    assert body["device_secret"] == "raw-secret"
    assert "device_secret_hash" not in body


def test_duplicate_device_registration_returns_409(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.post("/api/v1/devices", json={"device_id": "duplicate-device"})

    assert response.status_code == 409


def test_user_can_list_their_devices(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.get("/api/v1/devices")

    assert response.status_code == 200
    assert [device["device_id"] for device in response.json()] == ["PET-ESP32-001"]


def test_user_cannot_see_another_owners_devices(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.get("/api/v1/devices")

    assert response.status_code == 200
    assert all(device["owner_id"] == "owner-1" for device in response.json())


def test_user_can_retrieve_their_own_device(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.get("/api/v1/devices/PET-ESP32-001")

    assert response.status_code == 200
    assert response.json()["device_id"] == "PET-ESP32-001"


def test_user_cannot_retrieve_another_owners_device(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.get("/api/v1/devices/PET-ESP32-002")

    assert response.status_code == 404


def test_device_credentials_are_never_returned_from_get_endpoints(fake_device_api_service: FakeDeviceApiService) -> None:
    list_response = client.get("/api/v1/devices")
    get_response = client.get("/api/v1/devices/PET-ESP32-001")

    assert "device_secret" not in list_response.json()[0]
    assert "device_secret_hash" not in list_response.json()[0]
    assert "device_secret" not in get_response.json()
    assert "device_secret_hash" not in get_response.json()


def test_owner_can_assign_device_to_pet(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.post("/api/v1/devices/PET-ESP32-001/assign", json={"pet_id": "pet-1"})

    assert response.status_code == 200
    assert response.json()["pet_id"] == "pet-1"


def test_owner_can_unassign_device(fake_device_api_service: FakeDeviceApiService) -> None:
    response = client.delete("/api/v1/devices/PET-ESP32-001/assignment")

    assert response.status_code == 200
    assert response.json()["pet_id"] is None


def test_device_service_registers_with_hashed_credential(monkeypatch) -> None:
    device_repository = FakeDeviceRepository()
    service = DeviceService(device_repository=device_repository, pet_repository=FakePetRepository())

    monkeypatch.setattr("app.services.device_service.generate_device_secret", lambda: "raw-secret")

    registration = service.register_device("owner-1", data=type("Request", (), {"device_id": "PET-ESP32-100"})())

    assert registration.device_secret == "raw-secret"
    assert device_repository.created is not None
    assert device_repository.created.owner_id == "owner-1"
    assert device_repository.created.status is DeviceStatus.UNREGISTERED
    assert device_repository.created.device_secret_hash is not None
    assert device_repository.created.device_secret_hash != "raw-secret"
    assert verify_device_secret("raw-secret", device_repository.created.device_secret_hash)


def test_device_service_rejects_duplicate_registration() -> None:
    service = DeviceService(device_repository=FakeDeviceRepository(), pet_repository=FakePetRepository())

    with pytest.raises(DeviceConflictError):
        service.register_device("owner-1", data=type("Request", (), {"device_id": "PET-ESP32-001"})())


def test_device_service_assignment_updates_device_and_pet() -> None:
    device_repository = FakeDeviceRepository()
    pet_repository = FakePetRepository()
    service = DeviceService(device_repository=device_repository, pet_repository=pet_repository)

    device = service.assign_device_to_pet("owner-1", "PET-ESP32-001", "pet-1")

    assert device.pet_id == "pet-1"
    assert device_repository.get("PET-ESP32-001").pet_id == "pet-1"
    assert pet_repository.get("pet-1").device_id == "PET-ESP32-001"


def test_device_belonging_to_another_owner_cannot_be_assigned() -> None:
    service = DeviceService(device_repository=FakeDeviceRepository(), pet_repository=FakePetRepository())

    with pytest.raises(DeviceNotFoundError):
        service.assign_device_to_pet("owner-1", "PET-ESP32-002", "pet-1")


def test_pet_belonging_to_another_owner_cannot_be_assigned() -> None:
    service = DeviceService(device_repository=FakeDeviceRepository(), pet_repository=FakePetRepository())

    with pytest.raises(DeviceNotFoundError):
        service.assign_device_to_pet("owner-1", "PET-ESP32-001", "pet-3")


def test_pet_cannot_receive_second_device() -> None:
    service = DeviceService(device_repository=FakeDeviceRepository(), pet_repository=FakePetRepository())

    with pytest.raises(DeviceConflictError):
        service.assign_device_to_pet("owner-1", "PET-ESP32-001", "pet-2")


def test_device_cannot_be_silently_reassigned_to_another_pet() -> None:
    service = DeviceService(device_repository=FakeDeviceRepository(), pet_repository=FakePetRepository())

    with pytest.raises(DeviceConflictError):
        service.assign_device_to_pet("owner-1", "PET-ESP32-003", "pet-1")


def test_device_service_unassignment_updates_device_and_pet() -> None:
    device_repository = FakeDeviceRepository()
    pet_repository = FakePetRepository()
    service = DeviceService(device_repository=device_repository, pet_repository=pet_repository)

    device = service.unassign_device("owner-1", "PET-ESP32-003")

    assert device.pet_id is None
    assert device_repository.get("PET-ESP32-003").pet_id is None
    assert pet_repository.get("pet-2").device_id is None


def test_device_service_unassignment_rejects_cross_owner_pet_reference() -> None:
    device_repository = FakeDeviceRepository()
    device_repository.devices["PET-ESP32-001"] = make_device(
        device_id="PET-ESP32-001",
        owner_id="owner-1",
        pet_id="pet-3",
    )
    service = DeviceService(device_repository=device_repository, pet_repository=FakePetRepository())

    with pytest.raises(DeviceNotFoundError):
        service.unassign_device("owner-1", "PET-ESP32-001")


def test_correct_device_secret_authenticates_successfully() -> None:
    repository = FakeDeviceRepository()
    repository.devices["PET-ESP32-001"] = make_device(
        device_id="PET-ESP32-001",
        owner_id="owner-1",
        device_secret_hash=hash_device_secret("raw-secret"),
    )
    service = DeviceAuthenticationService(device_repository=repository)

    device = service.verify_device_credentials("PET-ESP32-001", "raw-secret")

    assert device.device_id == "PET-ESP32-001"


def test_incorrect_device_secret_is_rejected() -> None:
    repository = FakeDeviceRepository()
    repository.devices["PET-ESP32-001"] = make_device(
        device_id="PET-ESP32-001",
        owner_id="owner-1",
        device_secret_hash=hash_device_secret("raw-secret"),
    )
    service = DeviceAuthenticationService(device_repository=repository)

    with pytest.raises(DeviceAuthenticationError):
        service.verify_device_credentials("PET-ESP32-001", "wrong-secret")


def test_unknown_device_is_rejected() -> None:
    service = DeviceAuthenticationService(device_repository=FakeDeviceRepository())

    with pytest.raises(DeviceAuthenticationError):
        service.verify_device_credentials("unknown-device", "raw-secret")


def test_device_id_alone_cannot_authenticate() -> None:
    service = DeviceAuthenticationService(device_repository=FakeDeviceRepository())

    with pytest.raises(DeviceAuthenticationError):
        service.verify_device_credentials("PET-ESP32-001", None)
