from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient
from google.api_core.exceptions import GoogleAPIError

from app.main import app
from app.models.auth import AuthenticatedUser
from app.models.entities import Geofence, GeofenceCreate, GeofenceState, GeofenceTransitionType, GeofenceUpdate, Location, Pet
from app.schemas.geofences import GeofenceCreateRequest, GeofenceUpdateRequest
from app.schemas.telemetry import DeviceTelemetryRequest
from app.services.auth_service import get_current_user
from app.services.device_service import DeviceAuthenticationError
from app.services.geofence_service import (
    GeofenceNotFoundError,
    GeofenceService,
    GeofenceServiceError,
    calculate_distance_meters,
    get_geofence_service,
)
from app.services.telemetry_service import TelemetryService


client = TestClient(app)


def make_pet(pet_id: str = "pet-1", owner_id: str = "owner-1") -> Pet:
    now = datetime.now(UTC)
    return Pet(id=pet_id, owner_id=owner_id, name="Max", species="dog", created_at=now, updated_at=now)


def make_geofence(
    geofence_id: str = "geofence-1",
    owner_id: str = "owner-1",
    pet_id: str = "pet-1",
    enabled: bool = True,
    last_state: GeofenceState | None = None,
    radius_meters: float = 100,
) -> Geofence:
    now = datetime.now(UTC)
    return Geofence(
        id=geofence_id,
        owner_id=owner_id,
        pet_id=pet_id,
        name="Home",
        center=Location(latitude=14.5995, longitude=120.9842),
        radius_meters=radius_meters,
        enabled=enabled,
        last_state=last_state,
        last_state_changed_at=None,
        last_checked_at=None,
        created_at=now,
        updated_at=now,
    )


class FakeGeofenceApiService:
    def __init__(self) -> None:
        self.geofences = [make_geofence(), make_geofence("geofence-2", owner_id="owner-2")]
        self.created_owner_id: str | None = None
        self.deleted: tuple[str, str] | None = None

    def create_geofence(self, owner_id: str, data: GeofenceCreateRequest) -> Geofence:
        if data.pet_id in {"unknown-pet", "other-owner-pet"}:
            raise GeofenceNotFoundError("Pet was not found.")
        self.created_owner_id = owner_id
        return make_geofence(owner_id=owner_id, pet_id=data.pet_id, enabled=data.enabled)

    def list_geofences(self, owner_id: str) -> list[Geofence]:
        return [geofence for geofence in self.geofences if geofence.owner_id == owner_id]

    def get_geofence(self, owner_id: str, geofence_id: str) -> Geofence:
        for geofence in self.geofences:
            if geofence.id == geofence_id and geofence.owner_id == owner_id:
                return geofence
        raise GeofenceNotFoundError("Geofence was not found.")

    def update_geofence(self, owner_id: str, geofence_id: str, data: GeofenceUpdateRequest) -> Geofence:
        geofence = self.get_geofence(owner_id, geofence_id)
        return geofence.model_copy(update=data.model_dump(exclude_unset=True))

    def delete_geofence(self, owner_id: str, geofence_id: str) -> None:
        self.get_geofence(owner_id, geofence_id)
        self.deleted = (owner_id, geofence_id)


class FakeGeofenceRepository:
    def __init__(self, geofences: list[Geofence] | None = None, should_fail: bool = False) -> None:
        self.geofences = {geofence.id: geofence for geofence in (geofences or [make_geofence()])}
        self.should_fail = should_fail
        self.created: GeofenceCreate | None = None
        self.updated: list[tuple[str, dict[str, Any]]] = []
        self.deleted_id: str | None = None

    def create(self, data: GeofenceCreate) -> Geofence:
        self.created = data
        geofence = make_geofence(owner_id=data.owner_id, pet_id=data.pet_id, enabled=data.enabled)
        geofence = geofence.model_copy(update={"name": data.name, "center": data.center, "radius_meters": data.radius_meters})
        self.geofences[geofence.id] = geofence
        return geofence

    def query_by_owner(self, owner_id: str) -> list[Geofence]:
        if self.should_fail:
            raise GoogleAPIError("boom")
        return [geofence for geofence in self.geofences.values() if geofence.owner_id == owner_id]

    def query_enabled_by_pet(self, pet_id: str) -> list[Geofence]:
        if self.should_fail:
            raise GoogleAPIError("boom")
        return [geofence for geofence in self.geofences.values() if geofence.pet_id == pet_id and geofence.enabled]

    def get(self, geofence_id: str) -> Geofence | None:
        return self.geofences.get(geofence_id)

    def update(self, geofence_id: str, data: GeofenceUpdate) -> Geofence | None:
        geofence = self.geofences.get(geofence_id)
        if geofence is None:
            return None
        updated = geofence.model_copy(update=data.model_dump(exclude_unset=True))
        self.geofences[geofence_id] = updated
        return updated

    def update_fields(self, geofence_id: str, payload: dict[str, Any]) -> Geofence | None:
        geofence = self.geofences.get(geofence_id)
        if geofence is None:
            return None
        self.updated.append((geofence_id, payload))
        clean_payload = {key: value for key, value in payload.items() if not key.endswith("_at")}
        self.geofences[geofence_id] = geofence.model_copy(update=clean_payload)
        return self.geofences[geofence_id]

    def delete(self, geofence_id: str) -> None:
        self.deleted_id = geofence_id
        self.geofences.pop(geofence_id, None)


class FakePetRepository:
    def __init__(self) -> None:
        self.pets = {"pet-1": make_pet(), "pet-2": make_pet("pet-2", "owner-2")}

    def get(self, pet_id: str) -> Pet | None:
        return self.pets.get(pet_id)


class FakeTelemetryGeofenceService:
    def __init__(self, should_fail: bool = False) -> None:
        self.should_fail = should_fail
        self.evaluated: tuple[str, Location] | None = None

    def evaluate_enabled_geofences_for_pet(self, pet_id: str, location: Location) -> list[Any]:
        if self.should_fail:
            raise GeofenceServiceError("Geofences could not be evaluated.")
        self.evaluated = (pet_id, location)
        return []


class FakeTelemetryAuthService:
    def __init__(self, should_reject: bool = False) -> None:
        self.should_reject = should_reject

    def verify_device_credentials(self, device_id: str, device_secret: str | None):
        if self.should_reject:
            raise DeviceAuthenticationError("Invalid device credentials.")
        from tests.test_telemetry import make_device

        return make_device(pet_id="pet-1")


class FakeTelemetryDeviceRepository:
    def update_fields(self, device_id: str, payload: dict[str, Any]):
        from tests.test_telemetry import make_device

        return make_device(device_id=device_id)


class FakeTelemetryHistoryRepository:
    def create(self, data):
        return data


@pytest.fixture(autouse=True)
def clear_dependency_overrides() -> None:
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def fake_api_service() -> FakeGeofenceApiService:
    service = FakeGeofenceApiService()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="owner-1", email="owner@example.com")
    app.dependency_overrides[get_geofence_service] = lambda: service
    return service


def geofence_payload(**overrides: Any) -> dict[str, Any]:
    payload = {
        "pet_id": "pet-1",
        "name": "Home",
        "center": {"latitude": 14.5995, "longitude": 120.9842},
        "radius_meters": 100,
        "enabled": True,
    }
    payload.update(overrides)
    return payload


def test_authenticated_owner_can_create_geofence(fake_api_service: FakeGeofenceApiService) -> None:
    response = client.post("/api/v1/geofences", json=geofence_payload())
    assert response.status_code == 201
    assert response.json()["owner_id"] == "owner-1"
    assert response.json()["last_state"] is None


def test_unauthenticated_user_cannot_create_geofence() -> None:
    response = client.post("/api/v1/geofences", json=geofence_payload())
    assert response.status_code == 401


def test_owner_can_list_retrieve_update_and_delete_geofence(fake_api_service: FakeGeofenceApiService) -> None:
    assert client.get("/api/v1/geofences").json()[0]["id"] == "geofence-1"
    assert client.get("/api/v1/geofences/geofence-1").status_code == 200
    assert client.patch("/api/v1/geofences/geofence-1", json={"name": "Park"}).json()["name"] == "Park"
    assert client.delete("/api/v1/geofences/geofence-1").status_code == 204
    assert fake_api_service.deleted == ("owner-1", "geofence-1")


def test_cross_owner_access_modification_and_deletion_return_404(fake_api_service: FakeGeofenceApiService) -> None:
    assert client.get("/api/v1/geofences/geofence-2").status_code == 404
    assert client.patch("/api/v1/geofences/geofence-2", json={"name": "Park"}).status_code == 404
    assert client.delete("/api/v1/geofences/geofence-2").status_code == 404


@pytest.mark.parametrize(
    "payload",
    [
        geofence_payload(center={"latitude": 91, "longitude": 0}),
        geofence_payload(center={"latitude": 0, "longitude": 181}),
        geofence_payload(radius_meters=0),
        geofence_payload(radius_meters=-1),
        geofence_payload(name=""),
        geofence_payload(owner_id="owner-2"),
    ],
)
def test_invalid_geofence_payloads_are_rejected(fake_api_service: FakeGeofenceApiService, payload: dict[str, Any]) -> None:
    response = client.post("/api/v1/geofences", json=payload)
    assert response.status_code == 422


def test_unknown_pet_and_cross_owner_pet_are_rejected(fake_api_service: FakeGeofenceApiService) -> None:
    assert client.post("/api/v1/geofences", json=geofence_payload(pet_id="unknown-pet")).status_code == 404
    assert client.post("/api/v1/geofences", json=geofence_payload(pet_id="other-owner-pet")).status_code == 404


def test_position_at_center_and_clearly_inside_are_inside() -> None:
    service = GeofenceService(FakeGeofenceRepository(), FakePetRepository())
    center = Location(latitude=14.5995, longitude=120.9842)
    assert service.determine_state(center, center, 100) is GeofenceState.INSIDE
    assert service.determine_state(Location(latitude=14.5996, longitude=120.9842), center, 100) is GeofenceState.INSIDE


def test_position_clearly_outside_is_outside() -> None:
    service = GeofenceService(FakeGeofenceRepository(), FakePetRepository())
    assert service.determine_state(
        Location(latitude=14.6095, longitude=120.9842),
        Location(latitude=14.5995, longitude=120.9842),
        100,
    ) is GeofenceState.OUTSIDE


def test_boundary_distance_is_inside() -> None:
    service = GeofenceService(FakeGeofenceRepository(), FakePetRepository())
    center = Location(latitude=0, longitude=0)
    point = Location(latitude=0, longitude=1)
    distance = calculate_distance_meters(point, center)
    assert service.determine_state(point, center, distance) is GeofenceState.INSIDE


def test_haversine_calculation_is_used_correctly() -> None:
    distance = calculate_distance_meters(Location(latitude=0, longitude=0), Location(latitude=0, longitude=1))
    assert 111_000 < distance < 112_000


def test_state_transitions_are_classified_and_persisted() -> None:
    repository = FakeGeofenceRepository([make_geofence(last_state=None)])
    service = GeofenceService(repository, FakePetRepository())
    result = service.evaluate_geofence(make_geofence(last_state=None), Location(latitude=14.5995, longitude=120.9842))
    assert result.transition_type is GeofenceTransitionType.INITIAL
    assert result.transition_detected is False
    assert repository.updated[0][1]["last_state"] is GeofenceState.INSIDE
    assert "last_state_changed_at" in repository.updated[0][1]
    assert "last_checked_at" in repository.updated[0][1]


@pytest.mark.parametrize(
    ("previous", "location", "transition", "detected"),
    [
        (None, Location(latitude=14.6095, longitude=120.9842), GeofenceTransitionType.INITIAL, False),
        (GeofenceState.INSIDE, Location(latitude=14.6095, longitude=120.9842), GeofenceTransitionType.EXIT, True),
        (GeofenceState.OUTSIDE, Location(latitude=14.5995, longitude=120.9842), GeofenceTransitionType.ENTER, True),
        (GeofenceState.INSIDE, Location(latitude=14.5995, longitude=120.9842), GeofenceTransitionType.NONE, False),
        (GeofenceState.OUTSIDE, Location(latitude=14.6095, longitude=120.9842), GeofenceTransitionType.NONE, False),
    ],
)
def test_geofence_transition_types(previous, location, transition, detected) -> None:
    service = GeofenceService(FakeGeofenceRepository(), FakePetRepository())
    result = service.evaluate_geofence(make_geofence(last_state=previous), location)
    assert result.transition_type is transition
    assert result.transition_detected is detected


def test_disabled_geofence_is_skipped_and_multiple_geofences_are_independent() -> None:
    repository = FakeGeofenceRepository(
        [
            make_geofence("home", enabled=True, last_state=GeofenceState.INSIDE, radius_meters=50),
            make_geofence("park", enabled=True, last_state=GeofenceState.OUTSIDE, radius_meters=2_000),
            make_geofence("disabled", enabled=False),
        ]
    )
    results = GeofenceService(repository, FakePetRepository()).evaluate_enabled_geofences_for_pet(
        "pet-1", Location(latitude=14.6095, longitude=120.9842)
    )
    assert [result.geofence_id for result in results] == ["home", "park"]
    assert len(repository.updated) == 2


def test_valid_telemetry_still_works_when_no_geofence_exists_and_checks_enabled_geofences() -> None:
    geofence_service = FakeTelemetryGeofenceService()
    service = TelemetryService(
        device_authentication_service=FakeTelemetryAuthService(),
        device_repository=FakeTelemetryDeviceRepository(),
        tracking_history_repository=FakeTelemetryHistoryRepository(),
        geofence_service=geofence_service,
    )
    service.receive_telemetry(DeviceTelemetryRequest(**{
        "device_id": "PET-ESP32-001",
        "device_secret": "secret",
        "latitude": 14.5995,
        "longitude": 120.9842,
        "battery_level": 87,
    }))
    assert geofence_service.evaluated is not None
    assert geofence_service.evaluated[0] == "pet-1"


def test_invalid_telemetry_and_failed_auth_do_not_modify_geofence_state() -> None:
    geofence_service = FakeTelemetryGeofenceService()
    with pytest.raises(Exception):
        DeviceTelemetryRequest(device_id="d", device_secret="s", latitude=999, longitude=0, battery_level=1)

    service = TelemetryService(
        device_authentication_service=FakeTelemetryAuthService(should_reject=True),
        device_repository=FakeTelemetryDeviceRepository(),
        tracking_history_repository=FakeTelemetryHistoryRepository(),
        geofence_service=geofence_service,
    )
    with pytest.raises(DeviceAuthenticationError):
        service.receive_telemetry(DeviceTelemetryRequest(device_id="d", device_secret="s", latitude=0, longitude=0, battery_level=1))
    assert geofence_service.evaluated is None


def test_firestore_service_errors_are_handled_safely() -> None:
    service = GeofenceService(FakeGeofenceRepository(should_fail=True), FakePetRepository())
    with pytest.raises(GeofenceServiceError):
        service.list_geofences("owner-1")
