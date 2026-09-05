import logging
from typing import Any

from google.api_core.exceptions import GoogleAPIError

from app.models.entities import Alert, AlertCreate, AlertType, AlertUpdate, Device, Geofence, GeofenceTransitionType, Location, Pet
from app.schemas.geofences import GeofenceTransitionResult
from app.schemas.alerts import AlertUpdateRequest
from app.services.firestore_repositories import AlertRepository, PetRepository
from app.services.notification_service import NotificationDeliveryError, NotificationService

logger = logging.getLogger(__name__)


class AlertNotFoundError(RuntimeError):
    """Raised when an alert is missing or not owned by the authenticated user."""


class AlertServiceError(RuntimeError):
    """Raised when alert persistence fails."""


class AlertService:
    def __init__(
        self,
        alert_repository: AlertRepository | None = None,
        pet_repository: PetRepository | None = None,
        notification_service: NotificationService | None = None,
    ) -> None:
        self.alert_repository = alert_repository or AlertRepository()
        self.pet_repository = pet_repository or PetRepository()
        self.notification_service = notification_service

    def create_device_offline_alert(self, device: Device) -> Alert:
        pet = self._get_pet(device.pet_id)
        location = device.current_location
        pet_name = pet.name if pet else "Your pet"
        return self._create_alert(
            AlertCreate(
                owner_id=device.owner_id,
                pet_id=device.pet_id,
                device_id=device.device_id,
                type=AlertType.DEVICE_OFFLINE,
                title="Tracker Offline",
                message=f"{pet_name}'s tracker has gone offline.",
                latitude=location.latitude if location else None,
                longitude=location.longitude if location else None,
            )
        )

    def create_device_online_alert(self, device: Device, location: Location) -> Alert:
        pet = self._get_pet(device.pet_id)
        pet_name = pet.name if pet else "Your pet"
        return self._create_alert(
            AlertCreate(
                owner_id=device.owner_id,
                pet_id=device.pet_id,
                device_id=device.device_id,
                type=AlertType.DEVICE_ONLINE,
                title="Tracker Back Online",
                message=f"{pet_name}'s tracker is back online.",
                latitude=location.latitude,
                longitude=location.longitude,
            )
        )

    def create_geofence_exit_alert(self, device: Device, geofence: Geofence, location: Location) -> Alert:
        pet = self._get_pet(device.pet_id)
        pet_name = pet.name if pet else "Your pet"
        return self._create_alert(
            AlertCreate(
                owner_id=device.owner_id,
                pet_id=device.pet_id,
                device_id=device.device_id,
                type=AlertType.GEOFENCE_EXIT,
                title="Safe Zone Exit",
                message=f"{pet_name} has left {geofence.name}.",
                latitude=location.latitude,
                longitude=location.longitude,
            )
        )

    def create_geofence_enter_alert(self, device: Device, geofence: Geofence, location: Location) -> Alert:
        pet = self._get_pet(device.pet_id)
        pet_name = pet.name if pet else "Your pet"
        return self._create_alert(
            AlertCreate(
                owner_id=device.owner_id,
                pet_id=device.pet_id,
                device_id=device.device_id,
                type=AlertType.GEOFENCE_ENTER,
                title="Safe Zone Entered",
                message=f"{pet_name} has returned to {geofence.name}.",
                latitude=location.latitude,
                longitude=location.longitude,
            )
        )

    def create_geofence_transition_alert(
        self,
        device: Device,
        transition: GeofenceTransitionResult,
        location: Location,
    ) -> Alert | None:
        if transition.transition_type is GeofenceTransitionType.EXIT:
            geofence = Geofence.model_construct(
                id=transition.geofence_id,
                owner_id=device.owner_id,
                pet_id=transition.pet_id,
                name=transition.geofence_name,
            )
            return self.create_geofence_exit_alert(device, geofence, location)
        if transition.transition_type is GeofenceTransitionType.ENTER:
            geofence = Geofence.model_construct(
                id=transition.geofence_id,
                owner_id=device.owner_id,
                pet_id=transition.pet_id,
                name=transition.geofence_name,
            )
            return self.create_geofence_enter_alert(device, geofence, location)
        return None

    def create_low_battery_alert(self, device: Device, battery_level: int, location: Location) -> Alert:
        pet = self._get_pet(device.pet_id)
        pet_name = pet.name if pet else "Your pet"
        return self._create_alert(
            AlertCreate(
                owner_id=device.owner_id,
                pet_id=device.pet_id,
                device_id=device.device_id,
                type=AlertType.LOW_BATTERY,
                title="Low Battery",
                message=f"{pet_name}'s tracker battery is low ({battery_level}%).",
                latitude=location.latitude,
                longitude=location.longitude,
            )
        )

    def list_alerts(
        self,
        owner_id: str,
        pet_id: str | None = None,
        alert_type: AlertType | None = None,
        read: bool | None = None,
    ) -> list[Alert]:
        try:
            alerts = self.alert_repository.query_by_owner(owner_id)
        except GoogleAPIError as exc:
            logger.info("Firestore alert list failed: %s", exc.__class__.__name__)
            raise AlertServiceError("Alerts could not be listed.") from exc

        if pet_id is not None:
            alerts = [alert for alert in alerts if alert.pet_id == pet_id]
        if alert_type is not None:
            alerts = [alert for alert in alerts if alert.type == alert_type]
        if read is not None:
            alerts = [alert for alert in alerts if alert.read is read]
        return alerts

    def get_alert(self, owner_id: str, alert_id: str) -> Alert:
        try:
            alert = self.alert_repository.get(alert_id)
        except GoogleAPIError as exc:
            logger.info("Firestore alert lookup failed: %s", exc.__class__.__name__)
            raise AlertServiceError("Alert could not be loaded.") from exc
        if alert is None or alert.owner_id != owner_id:
            raise AlertNotFoundError("Alert was not found.")
        return alert

    def update_alert(self, owner_id: str, alert_id: str, data: AlertUpdateRequest) -> Alert:
        self.get_alert(owner_id, alert_id)
        try:
            alert = self.alert_repository.update(alert_id, AlertUpdate(read=data.read))
        except GoogleAPIError as exc:
            logger.info("Firestore alert update failed: %s", exc.__class__.__name__)
            raise AlertServiceError("Alert could not be updated.") from exc
        if alert is None or alert.owner_id != owner_id:
            raise AlertNotFoundError("Alert was not found.")
        return alert

    def delete_alert(self, owner_id: str, alert_id: str) -> None:
        self.get_alert(owner_id, alert_id)
        try:
            self.alert_repository.delete(alert_id)
        except GoogleAPIError as exc:
            logger.info("Firestore alert deletion failed: %s", exc.__class__.__name__)
            raise AlertServiceError("Alert could not be deleted.") from exc

    def _create_alert(self, data: AlertCreate) -> Alert:
        try:
            alert = self.alert_repository.create(data)
        except GoogleAPIError as exc:
            logger.info("Firestore alert creation failed: %s", exc.__class__.__name__)
            raise AlertServiceError("Alert could not be created.") from exc

        self._send_notification(alert)
        return alert

    def _send_notification(self, alert: Alert) -> None:
        if self.notification_service is None:
            return
        try:
            self.notification_service.send_alert_notification(alert)
        except NotificationDeliveryError as exc:
            logger.info("Alert notification delivery failed for alert_id=%s error=%s", alert.id, exc.__class__.__name__)

    def _get_pet(self, pet_id: str | None) -> Pet | None:
        if pet_id is None:
            return None
        try:
            return self.pet_repository.get(pet_id)
        except GoogleAPIError:
            logger.info("Pet lookup for alert message failed.")
            return None


def get_alert_service() -> AlertService:
    return AlertService()


def get_alert_delivery_service() -> AlertService:
    return AlertService(notification_service=NotificationService())
