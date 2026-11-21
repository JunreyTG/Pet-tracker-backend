import httpx
import pytest
from pydantic import SecretStr

from app.services import email_delivery


def _configure(monkeypatch) -> None:
    monkeypatch.setattr(email_delivery.settings, "brevo_api_key", SecretStr("xkeysib-test"))
    monkeypatch.setattr(email_delivery.settings, "alert_email_from", "alerts@example.com")


def test_send_email_posts_a_brevo_transactional_message(monkeypatch) -> None:
    _configure(monkeypatch)
    calls = []

    def fake_post(url, headers, json, timeout):
        calls.append((url, headers, json, timeout))
        return httpx.Response(201, request=httpx.Request("POST", url))

    monkeypatch.setattr(email_delivery.httpx, "post", fake_post)

    email_delivery.send_email("owner@example.com", "Verify", "Your code", idempotency_key="verify-abc")

    url, headers, payload, timeout = calls[0]
    assert url == "https://api.brevo.com/v3/smtp/email"
    assert headers == {"api-key": "xkeysib-test", "accept": "application/json"}
    assert payload == {
        "sender": {"name": "Pet Tracker", "email": "alerts@example.com"},
        "to": [{"email": "owner@example.com"}],
        "subject": "Verify",
        "textContent": "Your code",
        "headers": {"X-Mailin-custom": "verify-abc"},
    }
    assert timeout == 5


def test_send_email_raises_when_brevo_rejects_the_message(monkeypatch) -> None:
    _configure(monkeypatch)
    monkeypatch.setattr(
        email_delivery.httpx,
        "post",
        lambda *args, **kwargs: httpx.Response(
            401, request=httpx.Request("POST", "https://api.brevo.com/v3/smtp/email")
        ),
    )

    with pytest.raises(email_delivery.EmailDeliveryError):
        email_delivery.send_email("owner@example.com", "Verify", "Your code", idempotency_key="verify-abc")
