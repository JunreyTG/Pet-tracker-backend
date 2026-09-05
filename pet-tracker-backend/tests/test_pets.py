from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.auth import AuthenticatedUser
from app.models.entities import Pet, PetCreate, PetUpdate
from app.services.auth_service import get_current_user
from app.services.pet_service import PetNotFoundError, PetService, get_pet_service


client = TestClient(app)


def make_pet(
    pet_id: str = "pet-1",
    owner_id: str = "owner-1",
    name: str = "Max",
    species: str = "dog",
    device_id: str | None = None,
) -> Pet:
    now = datetime.now(UTC)
    return Pet(
        id=pet_id,
        owner_id=owner_id,
        name=name,
        species=species,
        breed="Golden Retriever",
        age=3,
        photo_url=None,
        device_id=device_id,
        created_at=now,
        updated_at=now,
    )


class FakePetService:
    def __init__(self) -> None:
        self.created_owner_id: str | None = None
        self.updated_payload: dict[str, Any] | None = None
        self.deleted: tuple[str, str] | None = None
        self.pets = [make_pet(), make_pet(pet_id="pet-2", owner_id="owner-2")]

    def create_pet(self, owner_id: str, data) -> Pet:
        self.created_owner_id = owner_id
        return make_pet(owner_id=owner_id, name=data.name, species=data.species)

    def list_pets(self, owner_id: str) -> list[Pet]:
        return [pet for pet in self.pets if pet.owner_id == owner_id]

    def get_pet(self, owner_id: str, pet_id: str) -> Pet:
        for pet in self.pets:
            if pet.id == pet_id and pet.owner_id == owner_id:
                return pet
        raise PetNotFoundError("Pet was not found.")

    def update_pet(self, owner_id: str, pet_id: str, data) -> Pet:
        pet = self.get_pet(owner_id, pet_id)
        self.updated_payload = data.model_dump(exclude_unset=True)
        updated = pet.model_copy(update=self.updated_payload)
        return updated

    def delete_pet(self, owner_id: str, pet_id: str) -> None:
        self.get_pet(owner_id, pet_id)
        self.deleted = (owner_id, pet_id)


class FakePetRepository:
    def __init__(self) -> None:
        self.pets: dict[str, Pet] = {
            "pet-1": make_pet(pet_id="pet-1", owner_id="owner-1"),
            "pet-2": make_pet(pet_id="pet-2", owner_id="owner-2"),
        }
        self.created: PetCreate | None = None
        self.updated: PetUpdate | None = None
        self.deleted_id: str | None = None
        self.queried_owner_id: str | None = None

    def create(self, data: PetCreate) -> Pet:
        self.created = data
        pet = make_pet(pet_id="pet-created", owner_id=data.owner_id, name=data.name, species=data.species)
        self.pets[pet.id] = pet
        return pet

    def query_by_owner(self, owner_id: str) -> list[Pet]:
        self.queried_owner_id = owner_id
        return [pet for pet in self.pets.values() if pet.owner_id == owner_id]

    def get(self, pet_id: str) -> Pet | None:
        return self.pets.get(pet_id)

    def update(self, pet_id: str, data: PetUpdate) -> Pet | None:
        self.updated = data
        pet = self.pets.get(pet_id)
        if pet is None:
            return None
        updated = pet.model_copy(update=data.model_dump(exclude_unset=True))
        self.pets[pet_id] = updated
        return updated

    def delete(self, pet_id: str) -> None:
        self.deleted_id = pet_id
        self.pets.pop(pet_id, None)


@pytest.fixture(autouse=True)
def clear_dependency_overrides() -> None:
    app.dependency_overrides.clear()
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def fake_pet_service() -> FakePetService:
    service = FakePetService()
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="owner-1",
        email="owner@example.com",
        display_name="Owner",
    )
    app.dependency_overrides[get_pet_service] = lambda: service
    return service


def test_unauthenticated_create_request_returns_401() -> None:
    response = client.post("/api/v1/pets", json={"name": "Max", "species": "dog"})

    assert response.status_code == 401


def test_unauthenticated_list_request_returns_401() -> None:
    response = client.get("/api/v1/pets")

    assert response.status_code == 401


def test_unauthenticated_get_request_returns_401() -> None:
    response = client.get("/api/v1/pets/pet-1")

    assert response.status_code == 401


def test_unauthenticated_update_request_returns_401() -> None:
    response = client.patch("/api/v1/pets/pet-1", json={"name": "Milo"})

    assert response.status_code == 401


def test_unauthenticated_delete_request_returns_401() -> None:
    response = client.delete("/api/v1/pets/pet-1")

    assert response.status_code == 401


def test_authenticated_user_can_create_pet(fake_pet_service: FakePetService) -> None:
    response = client.post("/api/v1/pets", json={"name": "Max", "species": "dog"})

    assert response.status_code == 201
    assert response.json()["name"] == "Max"


def test_created_pet_receives_authenticated_owner_id(fake_pet_service: FakePetService) -> None:
    response = client.post("/api/v1/pets", json={"name": "Max", "species": "dog"})

    assert response.status_code == 201
    assert response.json()["owner_id"] == "owner-1"
    assert fake_pet_service.created_owner_id == "owner-1"


def test_user_can_list_their_own_pets(fake_pet_service: FakePetService) -> None:
    response = client.get("/api/v1/pets")

    assert response.status_code == 200
    assert [pet["id"] for pet in response.json()] == ["pet-1"]


def test_user_cannot_see_another_owners_pets(fake_pet_service: FakePetService) -> None:
    response = client.get("/api/v1/pets")

    assert response.status_code == 200
    assert all(pet["owner_id"] == "owner-1" for pet in response.json())


def test_user_can_retrieve_their_own_pet(fake_pet_service: FakePetService) -> None:
    response = client.get("/api/v1/pets/pet-1")

    assert response.status_code == 200
    assert response.json()["id"] == "pet-1"


def test_user_cannot_retrieve_another_owners_pet(fake_pet_service: FakePetService) -> None:
    response = client.get("/api/v1/pets/pet-2")

    assert response.status_code == 404


def test_user_can_update_their_own_pet(fake_pet_service: FakePetService) -> None:
    response = client.patch("/api/v1/pets/pet-1", json={"name": "Milo"})

    assert response.status_code == 200
    assert response.json()["name"] == "Milo"


def test_user_cannot_update_another_owners_pet(fake_pet_service: FakePetService) -> None:
    response = client.patch("/api/v1/pets/pet-2", json={"name": "Milo"})

    assert response.status_code == 404


def test_user_cannot_change_owner_id(fake_pet_service: FakePetService) -> None:
    response = client.patch("/api/v1/pets/pet-1", json={"owner_id": "owner-2"})

    assert response.status_code == 422


def test_user_cannot_change_device_id(fake_pet_service: FakePetService) -> None:
    response = client.patch("/api/v1/pets/pet-1", json={"device_id": "tracker-1"})

    assert response.status_code == 422


def test_user_can_delete_their_own_pet(fake_pet_service: FakePetService) -> None:
    response = client.delete("/api/v1/pets/pet-1")

    assert response.status_code == 204
    assert fake_pet_service.deleted == ("owner-1", "pet-1")


def test_user_cannot_delete_another_owners_pet(fake_pet_service: FakePetService) -> None:
    response = client.delete("/api/v1/pets/pet-2")

    assert response.status_code == 404


def test_invalid_negative_age_is_rejected(fake_pet_service: FakePetService) -> None:
    response = client.post("/api/v1/pets", json={"name": "Max", "species": "dog", "age": -1})

    assert response.status_code == 422


def test_empty_pet_name_is_rejected(fake_pet_service: FakePetService) -> None:
    response = client.post("/api/v1/pets", json={"name": "", "species": "dog"})

    assert response.status_code == 422


def test_pet_service_sets_owner_id_and_device_id() -> None:
    repository = FakePetRepository()
    service = PetService(repository=repository)

    pet = service.create_pet("owner-1", data=type("Request", (), {
        "name": "Max",
        "species": "dog",
        "breed": None,
        "age": None,
        "photo_url": None,
    })())

    assert pet.owner_id == "owner-1"
    assert repository.created is not None
    assert repository.created.owner_id == "owner-1"
    assert repository.created.device_id is None


def test_pet_service_queries_list_by_owner_id() -> None:
    repository = FakePetRepository()
    service = PetService(repository=repository)

    pets = service.list_pets("owner-1")

    assert repository.queried_owner_id == "owner-1"
    assert [pet.id for pet in pets] == ["pet-1"]


def test_pet_service_blocks_cross_owner_get_update_and_delete() -> None:
    repository = FakePetRepository()
    service = PetService(repository=repository)

    with pytest.raises(PetNotFoundError):
        service.get_pet("owner-1", "pet-2")

    with pytest.raises(PetNotFoundError):
        service.update_pet("owner-1", "pet-2", PetUpdate(name="Milo"))

    with pytest.raises(PetNotFoundError):
        service.delete_pet("owner-1", "pet-2")

    assert repository.deleted_id is None
