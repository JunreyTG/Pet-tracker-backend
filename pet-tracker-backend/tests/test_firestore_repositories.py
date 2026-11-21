from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from google.api_core.exceptions import DeadlineExceeded
from pydantic import ValidationError

from app.models.entities import Location, PetUpdate
from app.services.firestore_repositories import DeviceRepository, FirestoreRepository


def test_repository_update_dump_preserves_explicit_null_values() -> None:
    payload = FirestoreRepository._dump(PetUpdate(device_id=None), exclude_unset=True)

    assert payload == {"device_id": None}


def test_repository_update_dump_omits_unset_values() -> None:
    payload = FirestoreRepository._dump(PetUpdate(), exclude_unset=True)

    assert payload == {}


def test_device_owner_query_reads_legacy_location_without_changing_stored_data() -> None:
    now = datetime.now(UTC)
    location = {"latitude": 5.02, "longitude": 119.77, "battery_level": 92, "timestamp": now, "speed": 1.4}
    data = {"device_id": "tracker", "owner_id": "owner", "current_location": location, "created_at": now, "updated_at": now}
    snapshot = SimpleNamespace(id="tracker", to_dict=data.copy)
    query = SimpleNamespace(stream=lambda **kwargs: iter([snapshot]))
    collection = SimpleNamespace(where=lambda **kwargs: query)
    repository = DeviceRepository(client=SimpleNamespace(collection=lambda name: collection))

    [device] = repository.query_by_owner("owner")

    assert device.current_location == Location(latitude=5.02, longitude=119.77)
    assert data["current_location"]["timestamp"] == now
    with pytest.raises(ValidationError):
        Location.model_validate(location)


def test_owner_query_uses_bounded_stream_without_retrying_deadline() -> None:
    def stream(*, retry, timeout):
        assert 0 < timeout < 10
        error = DeadlineExceeded("database timeout")
        assert not retry._predicate(error)
        raise error

    query = SimpleNamespace(stream=stream)
    collection = SimpleNamespace(where=lambda **kwargs: query)
    repository = DeviceRepository(client=SimpleNamespace(collection=lambda name: collection))

    with pytest.raises(DeadlineExceeded):
        repository.query_by_owner("owner")
