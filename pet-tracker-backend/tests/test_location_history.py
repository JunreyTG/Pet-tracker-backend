from datetime import UTC, datetime

import pytest

from app.models.entities import Pet, TrackingHistory
from app.services.location_history_service import LocationHistoryNotFoundError, LocationHistoryService


def make_pet(pet_id: str = "pet-1", owner_id: str = "owner-1") -> Pet:
    now = datetime.now(UTC)
    return Pet(
        id=pet_id,
        owner_id=owner_id,
        name="Max",
        species="dog",
        breed=None,
        age=None,
        photo_url=None,
        device_id="tracker-1",
        created_at=now,
        updated_at=now,
    )


def make_history(owner_id: str, recorded_at: datetime) -> TrackingHistory:
    return TrackingHistory(
        id=f"history-{owner_id}",
        device_id="tracker-1",
        pet_id="pet-1",
        owner_id=owner_id,
        latitude=14.5995,
        longitude=120.9842,
        battery_level=90,
        recorded_at=recorded_at,
    )


class FakePetRepository:
    def __init__(self, pet: Pet | None = None) -> None:
        self.pet = pet

    def get(self, pet_id: str) -> Pet | None:
        return self.pet if self.pet and self.pet.id == pet_id else None


class FakeHistoryRepository:
    def __init__(self) -> None:
        self.seen_owner_id: str | None = None

    def query_history_for_pet(self, owner_id: str, pet_id: str, limit: int, start_time=None, end_time=None):
        self.seen_owner_id = owner_id
        return [make_history(owner_id, datetime(2026, 1, 1, tzinfo=UTC))]


def test_location_history_service_requires_owned_pet() -> None:
    service = LocationHistoryService(
        pet_repository=FakePetRepository(make_pet(owner_id="owner-2")),
        history_repository=FakeHistoryRepository(),
    )

    with pytest.raises(LocationHistoryNotFoundError):
        service.list_pet_history("owner-1", "pet-1")


def test_location_history_service_loads_history_for_owned_pet() -> None:
    history_repository = FakeHistoryRepository()
    service = LocationHistoryService(
        pet_repository=FakePetRepository(make_pet(owner_id="owner-1")),
        history_repository=history_repository,
    )

    records = service.list_pet_history("owner-1", "pet-1")

    assert len(records) == 1
    assert records[0].owner_id == "owner-1"
    assert history_repository.seen_owner_id == "owner-1"
