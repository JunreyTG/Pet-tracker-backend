import logging

from google.api_core.exceptions import GoogleAPIError

from firebase_admin import firestore

from app.core.config import settings
from app.models.entities import Device, DeviceStatus, Location, TrackingHistoryCreate
from app.schemas.telemetry import DeviceTelemetryRequest
from app.services.device_service import DeviceAuthenticationError, DeviceAuthenticationService, DeviceServiceError
from app.services.firestore_repositories import DeviceRepository, TrackingHistoryRepository
from app.services.geofence_service import GeofenceService, GeofenceServiceError
from app.services.alert_service import AlertService, AlertServiceError, get_alert_delivery_service

logger = logging.getLogger(__name__)


class DeviceNotAssignedError(RuntimeError):
    """Raised when an authenticated tracker has no pet assignment."""


class TelemetryServiceError(RuntimeError):
    """Raised when telemetry persistence fails."""


class TelemetryService:
    def __init__(
        self,
        device_authentication_service: DeviceAuthenticationService | None = None,
        device_repository: DeviceRepository | None = None,
        tracking_history_repository: TrackingHistoryRepository | None = None,
        geofence_service: GeofenceService | None = None,
        alert_service: AlertService | None = None,
        low_battery_threshold_percent: int | None = None,
    ) -> None:
        self.device_repository = device_repository or DeviceRepository()
        self.device_authentication_service = device_authentication_service or DeviceAuthenticationService(
            device_repository=self.device_repository
        )
        self.tracking_history_repository = tracking_history_repository or TrackingHistoryRepository()
        self.geofence_service = geofence_service
        self.alert_service = alert_service
        self.low_battery_threshold_percent = (
            low_battery_threshold_percent
            if low_battery_threshold_percent is not None
            else settings.low_battery_threshold_percent
        )

    def receive_telemetry(self, data: DeviceTelemetryRequest) -> None:
        try:
            device = self.device_authentication_service.verify_device_credentials(data.device_id, data.device_secret)
        except DeviceAuthenticationError:
            raise
        except DeviceServiceError as exc:
            raise TelemetryServiceError("Device credentials could not be verified.") from exc

        if device.pet_id is None:
            raise DeviceNotAssignedError("Device is not assigned to a pet.")

        try:
            self._update_device_location(device, data)
            self._create_tracking_history(device, data)
            location = Location(latitude=data.latitude, longitude=data.longitude)
            self._create_online_recovery_alert_if_needed(device, location)
            self._evaluate_low_battery(device, data.battery_level, location)
            geofence_service = self.geofence_service or GeofenceService()
            transitions = geofence_service.evaluate_enabled_geofences_for_pet(device.pet_id, location)
            self._create_geofence_alerts(device, transitions, location)
        except GoogleAPIError as exc:
            logger.info("Firestore telemetry write failed: %s", exc.__class__.__name__)
            raise TelemetryServiceError("Telemetry could not be saved.") from exc
        except GeofenceServiceError as exc:
            raise TelemetryServiceError("Telemetry geofence evaluation failed.") from exc
        except AlertServiceError as exc:
            raise TelemetryServiceError("Telemetry alert evaluation failed.") from exc

    def _update_device_location(self, device: Device, data: DeviceTelemetryRequest) -> None:
        self.device_repository.update_fields(
            device.device_id,
            {
                "status": DeviceStatus.ONLINE,
                "battery_level": data.battery_level,
                "current_location": Location(latitude=data.latitude, longitude=data.longitude).model_dump(),
                "last_seen": firestore.SERVER_TIMESTAMP,
                "last_location_update": firestore.SERVER_TIMESTAMP,
            },
        )

    def _create_online_recovery_alert_if_needed(self, device: Device, location: Location) -> None:
        if device.status is DeviceStatus.OFFLINE:
            alert_service = self.alert_service or get_alert_delivery_service()
            alert_service.create_device_online_alert(device, location)

    def _evaluate_low_battery(self, device: Device, battery_level: int, location: Location) -> None:
        if battery_level <= self.low_battery_threshold_percent:
            if not device.low_battery_alert_active:
                alert_service = self.alert_service or get_alert_delivery_service()
                alert_service.create_low_battery_alert(device, battery_level, location)
                self.device_repository.update_fields(device.device_id, {"low_battery_alert_active": True})
            return

        if device.low_battery_alert_active:
            self.device_repository.update_fields(device.device_id, {"low_battery_alert_active": False})

    def _create_geofence_alerts(self, device: Device, transitions: list[object], location: Location) -> None:
        if not transitions:
            return
        alert_service = self.alert_service or get_alert_delivery_service()
        for transition in transitions:
            alert_service.create_geofence_transition_alert(device, transition, location)

    def _create_tracking_history(self, device: Device, data: DeviceTelemetryRequest) -> None:
        self.tracking_history_repository.create(
            TrackingHistoryCreate(
                device_id=device.device_id,
                pet_id=device.pet_id,
                owner_id=device.owner_id,
                latitude=data.latitude,
                longitude=data.longitude,
                battery_level=data.battery_level,
            )
        )


def get_telemetry_service() -> TelemetryService:
    return TelemetryService()
