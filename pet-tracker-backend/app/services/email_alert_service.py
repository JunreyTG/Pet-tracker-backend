import logging

from google.api_core.exceptions import GoogleAPIError

from app.firebase.admin import FirebaseInitializationError
from app.firebase.firestore import get_firestore_client
from app.models.entities import Alert
from app.services.auth_service import email_account_state
from app.services.email_delivery import EmailDeliveryError, email_delivery_configured, send_email

logger = logging.getLogger(__name__)


def send_alert_email(alert: Alert) -> None:
    if not email_delivery_configured():
        return
    try:
        snapshot = get_firestore_client().collection("users").document(alert.owner_id).get(retry=None, timeout=4)
        profile = snapshot.to_dict() or {}
        if not email_account_state(profile)["email_alerts_enabled"]:
            return
        send_email(
            profile["email"],
            f"Pet Tracker: {alert.title}",
            f"{alert.message}\n\nOpen Pet Tracker to view your alerts. "
            "You can turn off email alerts under Settings → Email notifications.",
            idempotency_key=f"alert-{alert.id}",
        )
    except (EmailDeliveryError, FirebaseInitializationError, GoogleAPIError) as exc:
        logger.warning("Email alert delivery failed for alert %s (%s).", alert.id, type(exc).__name__)
