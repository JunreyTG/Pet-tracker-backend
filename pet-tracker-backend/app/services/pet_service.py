import logging

from google.api_core.exceptions import GoogleAPIError

from app.models.entities import Pet, PetCreate, PetUpdate
from app.schemas.pets import PetCreateRequest, PetUpdateRequest
from app.services.firestore_repositories import DeviceRepository, PetRepository

logger = logging.getLogger(__name__)


class PetNotFoundError(RuntimeError):
    """Raised when a pet is missing or not owned by the authenticated user."""


class PetServiceError(RuntimeError):
    """Raised when pet persistence fails."""


class PetService:
    def __init__(
        self,
        repository: PetRepository | None = None,
        device_repository: DeviceRepository | None = None,
    ) -> None:
        self.repository = repository or PetRepository()
        self.device_repository = device_repository or DeviceRepository()

    def create_pet(self, owner_id: str, data: PetCreateRequest) -> Pet:
        try:
            pet_data = PetCreate(
                owner_id=owner_id,
                name=data.name,
                species=data.species,
                breed=data.breed,
                age=data.age,
                photo_url=data.photo_url,
                device_id=None,
            )
            return self.repository.create(pet_data)
        except GoogleAPIError as exc:
            logger.info("Firestore pet creation failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be created.") from exc

    def list_pets(self, uid: str) -> list[Pet]:
        try:
            owned = self.repository.query_by_owner(uid)
            shared_device_ids = {device.device_id for device in self.device_repository.query_by_viewer(uid)}
            shared = [
                pet
                for device_id in shared_device_ids
                for pet in self.repository.query_by_device(device_id)
            ]
        except GoogleAPIError as exc:
            logger.info("Firestore pet list failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pets could not be listed.") from exc

        seen = {pet.id for pet in owned}
        return owned + [pet for pet in shared if pet.id not in seen]

    def _can_view(self, uid: str, pet: Pet) -> bool:
        if pet.owner_id == uid:
            return True
        if pet.device_id is None:
            return False
        device = self.device_repository.get(pet.device_id)
        return device is not None and uid in device.viewer_ids

    def get_pet(self, uid: str, pet_id: str) -> Pet:
        try:
            pet = self.repository.get(pet_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet lookup failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be loaded.") from exc

        if pet is None or not self._can_view(uid, pet):
            raise PetNotFoundError("Pet was not found.")

        return pet

    def _get_owned_pet(self, owner_id: str, pet_id: str) -> Pet:
        try:
            pet = self.repository.get(pet_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet lookup failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be loaded.") from exc

        if pet is None or pet.owner_id != owner_id:
            raise PetNotFoundError("Pet was not found.")

        return pet

    def update_pet(self, owner_id: str, pet_id: str, data: PetUpdateRequest) -> Pet:
        self._get_owned_pet(owner_id, pet_id)

        update_data = PetUpdate(**data.model_dump(exclude_unset=True))
        try:
            pet = self.repository.update(pet_id, update_data)
        except GoogleAPIError as exc:
            logger.info("Firestore pet update failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be updated.") from exc

        if pet is None or pet.owner_id != owner_id:
            raise PetNotFoundError("Pet was not found.")

        return pet

    def delete_pet(self, owner_id: str, pet_id: str) -> None:
        self._get_owned_pet(owner_id, pet_id)
        try:
            self.repository.delete(pet_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet deletion failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be deleted.") from exc


def get_pet_service() -> PetService:
    return PetService()
