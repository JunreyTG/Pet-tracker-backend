import logging

from google.api_core.exceptions import GoogleAPIError

from app.models.entities import Pet, PetCreate, PetUpdate
from app.schemas.pets import PetCreateRequest, PetUpdateRequest
from app.services.firestore_repositories import PetRepository

logger = logging.getLogger(__name__)


class PetNotFoundError(RuntimeError):
    """Raised when a pet is missing or not owned by the authenticated user."""


class PetServiceError(RuntimeError):
    """Raised when pet persistence fails."""


class PetService:
    def __init__(self, repository: PetRepository | None = None) -> None:
        self.repository = repository or PetRepository()

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

    def list_pets(self, owner_id: str) -> list[Pet]:
        try:
            return self.repository.query_by_owner(owner_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet list failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pets could not be listed.") from exc

    def get_pet(self, owner_id: str, pet_id: str) -> Pet:
        try:
            pet = self.repository.get(pet_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet lookup failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be loaded.") from exc

        if pet is None or pet.owner_id != owner_id:
            raise PetNotFoundError("Pet was not found.")

        return pet

    def update_pet(self, owner_id: str, pet_id: str, data: PetUpdateRequest) -> Pet:
        self.get_pet(owner_id, pet_id)

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
        self.get_pet(owner_id, pet_id)
        try:
            self.repository.delete(pet_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet deletion failed: %s", exc.__class__.__name__)
            raise PetServiceError("Pet could not be deleted.") from exc


def get_pet_service() -> PetService:
    return PetService()
