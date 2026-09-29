import hashlib
import logging
from typing import Any

from firebase_admin import exceptions, firestore, messaging
from google.api_core.exceptions import GoogleAPIError

from app.firebase.admin import FirebaseInitializationError, initialize_firebase_app
from app.models.entities import Alert, NotificationToken, NotificationTokenCreate, NotificationTokenUpdate
from app.schemas.notifications import NotificationTokenRegisterRequest
from app.services.firestore_repositories import NotificationTokenRepository

logger = logging.getLogger(__name__)


class NotificationTokenNotFoundError(RuntimeError):
    """Raised when a notification token is missing or not owned by the authenticated user."""


class NotificationServiceError(RuntimeError):
    """Raised when notification token persistence fails."""


class NotificationDeliveryError(RuntimeError):
    """Raised when FCM delivery cannot be completed for an alert."""


def notification_token_id(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class NotificationService:
    def __init__(self, token_repository: NotificationTokenRepository | None = None) -> None:
        self.token_repository = token_repository or NotificationTokenRepository()

    def register_token(self, owner_id: str, data: NotificationTokenRegisterRequest) -> NotificationToken:
        token_id = notification_token_id(data.token)
        try:
            existing = self.token_repository.get(token_id)
            if existing is not None and existing.owner_id != owner_id:
                raise NotificationTokenNotFoundError("Notification token was not found.")

            if existing is None:
                created = self.token_repository.create(
                    NotificationTokenCreate(
                        owner_id=owner_id,
                        token=data.token,
                        platform=data.platform,
                        device_name=data.device_name,
                        active=True,
                    ),
                    token_id=token_id,
                )
                return self.token_repository.update_fields(token_id, {"last_used_at": firestore.SERVER_TIMESTAMP}) or created

            updated = self.token_repository.update_fields(
                token_id,
                {
                    "platform": data.platform,
                    "device_name": data.device_name,
                    "active": True,
                    "last_used_at": firestore.SERVER_TIMESTAMP,
                },
            )
        except NotificationTokenNotFoundError:
            raise
        except GoogleAPIError as exc:
            logger.info("Firestore notification token registration failed: %s", exc.__class__.__name__)
            raise NotificationServiceError("Notification token could not be registered.") from exc

        if updated is None:
            raise NotificationServiceError("Notification token could not be registered.")
        return updated

    def list_tokens(self, owner_id: str) -> list[NotificationToken]:
        try:
            return self.token_repository.query_by_owner(owner_id)
        except GoogleAPIError as exc:
            logger.info("Firestore notification token list failed: %s", exc.__class__.__name__)
            raise NotificationServiceError("Notification tokens could not be listed.") from exc

    def deactivate_token(self, owner_id: str, token_id: str) -> None:
        try:
            token = self.token_repository.get(token_id)
            if token is None or token.owner_id != owner_id:
                raise NotificationTokenNotFoundError("Notification token was not found.")
            self.token_repository.update(token_id, NotificationTokenUpdate(active=False))
        except NotificationTokenNotFoundError:
            raise
        except GoogleAPIError as exc:
            logger.info("Firestore notification token deactivation failed: %s", exc.__class__.__name__)
            raise NotificationServiceError("Notification token could not be removed.") from exc

    def send_alert_notification(self, alert: Alert) -> None:
        try:
            tokens = self.token_repository.query_active_by_owner(alert.owner_id)
        except GoogleAPIError as exc:
            logger.info("Firestore active notification token lookup failed: %s", exc.__class__.__name__)
            raise NotificationDeliveryError("Notification tokens could not be loaded.") from exc

        for token in tokens:
            self._send_to_token(alert, token)

    def _send_to_token(self, alert: Alert, token: NotificationToken) -> None:
        try:
            initialize_firebase_app()
            messaging.send(
                messaging.Message(
                    notification=messaging.Notification(title=alert.title, body=alert.message),
                    data=self._alert_data(alert),
                    token=token.token,
                    android=messaging.AndroidConfig(
                        priority="high",
                        notification=messaging.AndroidNotification(
                            channel_id="pet_tracker_alerts",
                            sound="default",
                            default_sound=True,
                            default_vibrate_timings=True,
                            priority="high",
                        ),
                    ),
                    apns=messaging.ApnsConfig(
                        headers={"apns-priority": "10"},
                        payload=messaging.ApnsPayload(
                            aps=messaging.Aps(
                                sound="default",
                                badge=1,
                            )
                        ),
                    ),
                )
            )
            self.token_repository.update_fields(token.id, {"last_used_at": firestore.SERVER_TIMESTAMP})
        except FirebaseInitializationError as exc:
            logger.info("Firebase Admin SDK is not initialized for FCM delivery: %s", exc.__class__.__name__)
        except self._invalid_token_errors() as exc:
            logger.info("FCM token became invalid; deactivating token_id=%s error=%s", token.id, exc.__class__.__name__)
            self._deactivate_invalid_token(token.id)
        except exceptions.FirebaseError as exc:
            logger.info("FCM delivery failed for token_id=%s error=%s", token.id, exc.__class__.__name__)

    def _deactivate_invalid_token(self, token_id: str) -> None:
        try:
            self.token_repository.update(token_id, NotificationTokenUpdate(active=False))
        except GoogleAPIError as exc:
            logger.info("Invalid FCM token deactivation failed for token_id=%s error=%s", token_id, exc.__class__.__name__)

    @staticmethod
    def _alert_data(alert: Alert) -> dict[str, str]:
        data: dict[str, str] = {
            "alert_id": alert.id,
            "type": str(alert.type),
        }
        if alert.pet_id is not None:
            data["pet_id"] = alert.pet_id
        if alert.device_id is not None:
            data["device_id"] = alert.device_id
        return data

    @staticmethod
    def _invalid_token_errors() -> tuple[type[Exception], ...]:
        return tuple(
            error_type
            for error_type in (
                getattr(messaging, "UnregisteredError", None),
                getattr(messaging, "SenderIdMismatchError", None),
            )
            if error_type is not None
        )


def notification_token_response(token: NotificationToken) -> dict[str, Any]:
    return {
        "token_id": token.id,
        "platform": token.platform,
        "device_name": token.device_name,
        "active": token.active,
        "created_at": token.created_at,
        "updated_at": token.updated_at,
        "last_used_at": token.last_used_at,
    }


def get_notification_service() -> NotificationService:
    return NotificationService()
