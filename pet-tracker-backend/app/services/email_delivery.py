import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_BREVO_ERROR_CODES = {
    "unauthorized", "permission_denied", "account_under_validation", "not_enough_credits",
    "invalid_parameter", "api-key not found", "DMARC policy requires domain authentication",
}


class EmailDeliveryError(RuntimeError):
    """Mail was not accepted by the delivery provider."""


def email_delivery_configured() -> bool:
    key = settings.brevo_api_key
    value = key.get_secret_value().strip() if key else ""
    return bool(value and value not in {
        "replace-with-your-brevo-api-key", "xkeysib-your-api-key", "xkeysib-...",
    } and settings.alert_email_from)


def _rejection_reason(response: httpx.Response) -> str:
    try:
        data = response.json()
    except ValueError:
        return "unknown"
    if not isinstance(data, dict):
        return "unknown"
    # Map known responses to fixed labels; avoid logging raw provider text.
    message = data.get("message")
    if isinstance(message, str):
        text = message.casefold()
        if any(fragment in text for fragment in ("unrecognised ip", "unrecognized ip", "unauthorized ip")):
            return "ip_not_authorized"
        if "sender" in text and any(fragment in text for fragment in ("not verified", "not valid", "not authorized")):
            return "sender_not_authorized"
    code = data.get("code")
    return code if isinstance(code, str) and code in _BREVO_ERROR_CODES else "unknown"


def send_email(recipient: str, subject: str, text: str, *, idempotency_key: str) -> None:
    key = settings.brevo_api_key
    if key is None or not email_delivery_configured():
        raise EmailDeliveryError("Email delivery is not configured.")
    try:
        response = httpx.post(
            "https://api.brevo.com/v3/smtp/email",
            headers={"api-key": key.get_secret_value().strip(), "accept": "application/json"},
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
        logger.warning("Email provider rejected a request (HTTP %s; reason=%s).", response.status_code, _rejection_reason(response))
        raise EmailDeliveryError("Email provider did not accept the message.")
