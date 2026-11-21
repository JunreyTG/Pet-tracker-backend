import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class EmailDeliveryError(RuntimeError):
    """Mail was not accepted by the delivery provider."""


def email_delivery_configured() -> bool:
    key = settings.brevo_api_key
    return bool(key and key.get_secret_value().strip() and settings.alert_email_from)


def send_email(recipient: str, subject: str, text: str, *, idempotency_key: str) -> None:
    key = settings.brevo_api_key
    if key is None or not email_delivery_configured():
        raise EmailDeliveryError("Email delivery is not configured.")
    try:
        response = httpx.post(
            "https://api.brevo.com/v3/smtp/email",
            headers={"api-key": key.get_secret_value(), "accept": "application/json"},
            json={
                "sender": {"name": "Pet Tracker", "email": str(settings.alert_email_from)},
                "to": [{"email": recipient}],
                "subject": subject,
                "textContent": text,
                "headers": {"X-Mailin-custom": idempotency_key},
            },
            timeout=5,
        )
    except httpx.RequestError as exc:
        raise EmailDeliveryError("Email provider could not be reached.") from exc
    if not response.is_success:
        logger.warning("Email provider rejected a request (HTTP %s).", response.status_code)
        raise EmailDeliveryError("Email provider did not accept the message.")
