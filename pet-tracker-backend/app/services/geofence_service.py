import logging
import math

from firebase_admin import firestore
from google.api_core.exceptions import GoogleAPIError

from app.models.entities import (
    Geofence,
    GeofenceCreate,
    GeofenceState,
    GeofenceTransitionType,
    GeofenceUpdate,
    Location,
)
from app.schemas.geofences import GeofenceCreateRequest, GeofenceTransitionResult, GeofenceUpdateRequest
from app.services.firestore_repositories import GeofenceRepository, PetRepository

logger = logging.getLogger(__name__)

EARTH_RADIUS_METERS = 6_371_000


class GeofenceNotFoundError(RuntimeError):
    """Raised when a geofence or its pet is missing or not owned by the user."""


class GeofenceServiceError(RuntimeError):
    """Raised when geofence persistence fails."""


class GeofenceService:
    def __init__(
        self,
        geofence_repository: GeofenceRepository | None = None,
        pet_repository: PetRepository | None = None,
    ) -> None:
        self.geofence_repository = geofence_repository or GeofenceRepository()
        self.pet_repository = pet_repository or PetRepository()

    def create_geofence(self, owner_id: str, data: GeofenceCreateRequest) -> Geofence:
        self._require_owned_pet(owner_id, data.pet_id)
        try:
            return self.geofence_repository.create(
                GeofenceCreate(
                    owner_id=owner_id,
                    pet_id=data.pet_id,
                    name=data.name,
                    center=data.center,
                    radius_meters=data.radius_meters,
                    enabled=data.enabled,
                )
            )
        except GoogleAPIError as exc:
            logger.info("Firestore geofence creation failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Geofence could not be created.") from exc

    def list_geofences(self, owner_id: str) -> list[Geofence]:
        try:
            return self.geofence_repository.query_by_owner(owner_id)
        except GoogleAPIError as exc:
            logger.info("Firestore geofence list failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Geofences could not be listed.") from exc

    def get_geofence(self, owner_id: str, geofence_id: str) -> Geofence:
        try:
            geofence = self.geofence_repository.get(geofence_id)
        except GoogleAPIError as exc:
            logger.info("Firestore geofence lookup failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Geofence could not be loaded.") from exc
        if geofence is None or geofence.owner_id != owner_id:
            raise GeofenceNotFoundError("Geofence was not found.")
        return geofence

    def update_geofence(self, owner_id: str, geofence_id: str, data: GeofenceUpdateRequest) -> Geofence:
        self.get_geofence(owner_id, geofence_id)
        try:
            geofence = self.geofence_repository.update(geofence_id, GeofenceUpdate(**data.model_dump(exclude_unset=True)))
        except GoogleAPIError as exc:
            logger.info("Firestore geofence update failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Geofence could not be updated.") from exc
        if geofence is None or geofence.owner_id != owner_id:
            raise GeofenceNotFoundError("Geofence was not found.")
        return geofence

    def delete_geofence(self, owner_id: str, geofence_id: str) -> None:
        self.get_geofence(owner_id, geofence_id)
        try:
            self.geofence_repository.delete(geofence_id)
        except GoogleAPIError as exc:
            logger.info("Firestore geofence deletion failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Geofence could not be deleted.") from exc

    def evaluate_enabled_geofences_for_pet(self, pet_id: str, location: Location) -> list[GeofenceTransitionResult]:
        try:
            geofences = self.geofence_repository.query_enabled_by_pet(pet_id)
            return [self.evaluate_geofence(geofence, location) for geofence in geofences]
        except GoogleAPIError as exc:
            logger.info("Firestore geofence evaluation failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Geofences could not be evaluated.") from exc

    def evaluate_geofence(self, geofence: Geofence, location: Location) -> GeofenceTransitionResult:
        current_state = self.determine_state(location, geofence.center, geofence.radius_meters)
        previous_state = geofence.last_state
        transition_type = self._transition_type(previous_state, current_state)
        transition_detected = transition_type in {GeofenceTransitionType.ENTER, GeofenceTransitionType.EXIT}

        update_payload = {
            "last_state": current_state,
            "last_checked_at": firestore.SERVER_TIMESTAMP,
        }
        if previous_state != current_state:
            update_payload["last_state_changed_at"] = firestore.SERVER_TIMESTAMP

        self.geofence_repository.update_fields(geofence.id, update_payload)

        return GeofenceTransitionResult(
            geofence_id=geofence.id,
            pet_id=geofence.pet_id,
            geofence_name=geofence.name,
            previous_state=previous_state,
            current_state=current_state,
            transition_detected=transition_detected,
            transition_type=transition_type,
        )

    def determine_state(self, location: Location, center: Location, radius_meters: float) -> GeofenceState:
        distance = calculate_distance_meters(location, center)
        return GeofenceState.INSIDE if distance <= radius_meters else GeofenceState.OUTSIDE

    def _require_owned_pet(self, owner_id: str, pet_id: str) -> None:
        try:
            pet = self.pet_repository.get(pet_id)
        except GoogleAPIError as exc:
            logger.info("Firestore pet lookup for geofence failed: %s", exc.__class__.__name__)
            raise GeofenceServiceError("Pet could not be loaded.") from exc
        if pet is None or pet.owner_id != owner_id:
            raise GeofenceNotFoundError("Pet was not found.")

    @staticmethod
    def _transition_type(
        previous_state: GeofenceState | None,
        current_state: GeofenceState,
    ) -> GeofenceTransitionType:
        if previous_state is None:
            return GeofenceTransitionType.INITIAL
        if previous_state == current_state:
            return GeofenceTransitionType.NONE
        if previous_state is GeofenceState.INSIDE and current_state is GeofenceState.OUTSIDE:
            return GeofenceTransitionType.EXIT
        return GeofenceTransitionType.ENTER


def calculate_distance_meters(start: Location, end: Location) -> float:
    lat1 = math.radians(start.latitude)
    lat2 = math.radians(end.latitude)
    delta_lat = math.radians(end.latitude - start.latitude)
    delta_lon = math.radians(end.longitude - start.longitude)

    haversine = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    )
    return 2 * EARTH_RADIUS_METERS * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine))


def get_geofence_service() -> GeofenceService:
    return GeofenceService()
