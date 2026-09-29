import logging
from datetime import datetime

from google.api_core.exceptions import GoogleAPIError

from app.models.entities import TrackingHistory
from app.services.firestore_repositories import PetRepository, TrackingHistoryRepository

logger = logging.getLogger(__name__)

MAX_LOCATION_HISTORY_LIMIT = 500
DEFAULT_LOCATION_HISTORY_LIMIT = 100


class LocationHistoryNotFoundError(RuntimeError):
    """Raised when the requested pet is missing or not owned by the user."""


class LocationHistoryServiceError(RuntimeError):
    """Raised when location history cannot be loaded safely."""


class LocationHistoryService:
    def __init__(
        self,
        pet_repository: PetRepository | None = None,
        history_repository: TrackingHistoryRepository | None = None,
    ) -> None:
        self.pet_repository = pet_repository or PetRepository()
        self.history_repository = history_repository or TrackingHistoryRepository()

    def list_pet_history(
        self,
        owner_id: str,
        pet_id: str,
        limit: int = DEFAULT_LOCATION_HISTORY_LIMIT,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
    ) -> list[TrackingHistory]:
        try:
            pet = self.pet_repository.get(pet_id)
            if pet is None or pet.owner_id != owner_id:
                raise LocationHistoryNotFoundError("Pet was not found.")

            safe_limit = min(limit, MAX_LOCATION_HISTORY_LIMIT)
            records = self.history_repository.query_history_for_pet(
                owner_id=owner_id,
                pet_id=pet_id,
                limit=safe_limit,
                start_time=start_time,
                end_time=end_time,
            )
        except LocationHistoryNotFoundError:
            raise
        except GoogleAPIError as exc:
            logger.info("Firestore location history lookup failed: %s", exc.__class__.__name__)
            raise LocationHistoryServiceError("Location history could not be loaded.") from exc

        return records


def get_location_history_service() -> LocationHistoryService:
    return LocationHistoryService()
