import logging
from dataclasses import dataclass

from firebase_admin import firestore
from google.api_core.exceptions import AlreadyExists, GoogleAPIError

from app.models.entities import Device, DeviceCreate, DeviceStatus
from app.schemas.devices import DeviceRegisterRequest
from app.services.device_credentials import generate_device_secret, hash_device_secret, verify_device_secret
from app.services.firestore_repositories import DeviceRepository, PetRepository

logger = logging.getLogger(__name__)
UNCLAIMED_TRACKER_OWNER = "unclaimed-tracker-inventory"


class DeviceNotFoundError(RuntimeError):
    """Raised when a device is missing or not owned by the authenticated user."""


class DeviceConflictError(RuntimeError):
    """Raised when a device operation would overwrite an existing relationship or credential."""


class DeviceAuthenticationError(RuntimeError):
    """Raised when ESP32 device credentials are invalid."""


class DeviceServiceError(RuntimeError):
    """Raised when device persistence fails."""


@dataclass(frozen=True)
class DeviceRegistration:
    device: Device
    device_secret: str


class DeviceService:
    def __init__(
        self,
        device_repository: DeviceRepository | None = None,
        pet_repository: PetRepository | None = None,
    ) -> None:
        self.device_repository = device_repository or DeviceRepository()
        self.pet_repository = pet_repository or PetRepository()

    def register_device(self, owner_id: str, data: DeviceRegisterRequest) -> DeviceRegistration:
        try:
            if self.device_repository.get(data.device_id) is not None:
                raise DeviceConflictError("Device is already registered.")

            device_secret = generate_device_secret()
            device_secret_hash = hash_device_secret(device_secret)
            device = self.device_repository.create(
                DeviceCreate(
                    device_id=data.device_id,
                    name=data.name,
                    owner_id=owner_id,
                    preconfigured=owner_id == UNCLAIMED_TRACKER_OWNER,
                    pet_id=None,
                    status=DeviceStatus.UNREGISTERED,
                    device_secret_hash=device_secret_hash,
                )
            )
        except AlreadyExists as exc:
            raise DeviceConflictError("Device is already registered.") from exc
        except GoogleAPIError as exc:
            logger.info("Firestore device registration failed: %s", exc.__class__.__name__)
            raise DeviceServiceError("Device could not be registered.") from exc

        return DeviceRegistration(device=device, device_secret=device_secret)

    def list_devices(self, owner_id: str) -> list[Device]:
        try:
            return self.device_repository.query_by_owner(owner_id)
        except GoogleAPIError as exc:
            logger.info("Firestore device list failed: %s", exc.__class__.__name__)
            raise DeviceServiceError("Devices could not be listed.") from exc

    def get_device(self, owner_id: str, device_id: str) -> Device:
        try:
            device = self.device_repository.get(device_id)
        except GoogleAPIError as exc:
            logger.info("Firestore device lookup failed: %s", exc.__class__.__name__)
            raise DeviceServiceError("Device could not be loaded.") from exc

        if device is None or device.owner_id != owner_id:
            raise DeviceNotFoundError("Device was not found.")

        return device

    def assign_device_to_pet(self, owner_id: str, device_id: str, pet_id: str) -> Device:
        return self._assign(owner_id, device_id, pet_id, claim=False)

    def claim_device(self, owner_id: str, device_id: str, pet_id: str) -> Device:
        return self._assign(owner_id, device_id, pet_id, claim=True)

    def _assign(self, owner_id: str, device_id: str, pet_id: str, *, claim: bool) -> Device:
        @firestore.transactional
        def assign(transaction):
            device = self.device_repository.get(device_id, transaction=transaction)
            if device is None:
                raise DeviceNotFoundError("Device was not found.")
            claimable = (
                claim and device.owner_id == UNCLAIMED_TRACKER_OWNER
                and device.preconfigured and device.status == DeviceStatus.UNREGISTERED
                and bool(device.device_secret_hash)
            )
            if device.owner_id != owner_id and not claimable:
                raise DeviceNotFoundError("Device was not found.")
            if device.pet_id not in (None, pet_id):
                raise DeviceConflictError("Device is already assigned to another pet.")

            pet = self.pet_repository.get(pet_id, transaction=transaction)
            if pet is None or pet.owner_id != owner_id:
                raise DeviceNotFoundError("Pet was not found.")
            if pet.device_id not in (None, device_id):
                raise DeviceConflictError("Pet already has a device assigned.")
            if device.owner_id == owner_id and device.pet_id == pet_id and pet.device_id == device_id:
                return

            transaction.update(self.device_repository.collection.document(device_id), {
                "owner_id": owner_id, "pet_id": pet_id, "updated_at": firestore.SERVER_TIMESTAMP,
            })
            transaction.update(self.pet_repository.collection.document(pet_id), {
                "device_id": device_id, "updated_at": firestore.SERVER_TIMESTAMP,
            })

        try:
            assign(self.device_repository.client.transaction())
        except GoogleAPIError as exc:
            logger.info("Firestore device assignment failed: %s", exc.__class__.__name__)
            raise DeviceServiceError("Device assignment could not be completed.") from exc
        return self.get_device(owner_id, device_id)

    def unassign_device(self, owner_id: str, device_id: str) -> Device:
        device = self.get_device(owner_id, device_id)
        pet_id = device.pet_id
        if pet_id is None:
            return device

        try:
            pet = self.pet_repository.get(pet_id)
            if pet is None or pet.owner_id != owner_id:
                raise DeviceNotFoundError("Pet was not found.")

            batch = self.device_repository.client.batch()
            device_ref = self.device_repository.collection.document(device_id)
            pet_ref = self.pet_repository.collection.document(pet_id)
            batch.update(device_ref, {"pet_id": None, "updated_at": firestore.SERVER_TIMESTAMP})
            batch.update(pet_ref, {"device_id": None, "updated_at": firestore.SERVER_TIMESTAMP})
            batch.commit()
            updated_device = self.device_repository.get(device_id)
        except GoogleAPIError as exc:
            logger.info("Firestore device unassignment failed: %s", exc.__class__.__name__)
            raise DeviceServiceError("Device assignment could not be removed.") from exc

        if updated_device is None or updated_device.owner_id != owner_id:
            raise DeviceNotFoundError("Device was not found.")

        return updated_device


class DeviceAuthenticationService:
    def __init__(self, device_repository: DeviceRepository | None = None) -> None:
        self.device_repository = device_repository or DeviceRepository()

    def verify_device_credentials(self, device_id: str, device_secret: str | None) -> Device:
        if not device_secret:
            raise DeviceAuthenticationError("Invalid device credentials.")

        try:
            device = self.device_repository.get(device_id)
        except GoogleAPIError as exc:
            logger.info("Firestore device credential lookup failed: %s", exc.__class__.__name__)
            raise DeviceServiceError("Device credentials could not be verified.") from exc

        if device is None or device.status == DeviceStatus.DISABLED or not verify_device_secret(device_secret, device.device_secret_hash):
            raise DeviceAuthenticationError("Invalid device credentials.")

        return device


def get_device_service() -> DeviceService:
    return DeviceService()
