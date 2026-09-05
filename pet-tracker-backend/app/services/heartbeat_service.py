import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from google.api_core.exceptions import GoogleAPIError

from app.core.config import settings
from app.models.entities import Device, DeviceStatus
from app.services.firestore_repositories import DeviceRepository
from app.services.alert_service import AlertService, AlertServiceError, get_alert_delivery_service

logger = logging.getLogger(__name__)


class HeartbeatServiceError(RuntimeError):
    """Raised when heartbeat status checks cannot be completed safely."""


@dataclass(frozen=True)
class HeartbeatCheckResult:
    checked_count: int
    marked_offline_count: int
    skipped_count: int


class HeartbeatService:
    def __init__(
        self,
        device_repository: DeviceRepository | None = None,
        offline_threshold_seconds: int | None = None,
        alert_service: AlertService | None = None,
    ) -> None:
        self.device_repository = device_repository or DeviceRepository()
        self.offline_threshold_seconds = offline_threshold_seconds or settings.device_offline_threshold_seconds
        self.alert_service = alert_service

    def check_devices_for_offline_status(self, current_time: datetime | None = None) -> HeartbeatCheckResult:
        now = self._to_utc(current_time or datetime.now(UTC))
        checked_count = 0
        marked_offline_count = 0
        skipped_count = 0

        try:
            devices = self.device_repository.query_by_status(DeviceStatus.ONLINE)
            for device in devices:
                checked_count += 1
                if not self._should_mark_offline(device, now):
                    skipped_count += 1
                    continue

                self.device_repository.update_fields(device.device_id, {"status": DeviceStatus.OFFLINE})
                self._create_offline_alert(device)
                marked_offline_count += 1
        except GoogleAPIError as exc:
            logger.info("Firestore heartbeat check failed: %s", exc.__class__.__name__)
            raise HeartbeatServiceError("Heartbeat check could not be completed.") from exc

        return HeartbeatCheckResult(
            checked_count=checked_count,
            marked_offline_count=marked_offline_count,
            skipped_count=skipped_count,
        )

    def is_device_offline(self, device: Device, current_time: datetime | None = None) -> bool:
        now = self._to_utc(current_time or datetime.now(UTC))
        return self._should_mark_offline(device, now)

    def _should_mark_offline(self, device: Device, current_time: datetime) -> bool:
        if device.status is not DeviceStatus.ONLINE:
            return False

        if device.last_seen is None:
            return False

        elapsed = current_time - self._to_utc(device.last_seen)
        return elapsed > timedelta(seconds=self.offline_threshold_seconds)

    def _create_offline_alert(self, device: Device) -> None:
        try:
            alert_service = self.alert_service or get_alert_delivery_service()
            alert_service.create_device_offline_alert(device)
        except AlertServiceError as exc:
            logger.info("Device offline alert creation failed: %s", exc.__class__.__name__)

    @staticmethod
    def _to_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)
