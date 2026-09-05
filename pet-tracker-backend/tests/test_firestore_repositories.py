from app.models.entities import PetUpdate
from app.services.firestore_repositories import FirestoreRepository


def test_repository_update_dump_preserves_explicit_null_values() -> None:
    payload = FirestoreRepository._dump(PetUpdate(device_id=None), exclude_unset=True)

    assert payload == {"device_id": None}


def test_repository_update_dump_omits_unset_values() -> None:
    payload = FirestoreRepository._dump(PetUpdate(), exclude_unset=True)

    assert payload == {}
