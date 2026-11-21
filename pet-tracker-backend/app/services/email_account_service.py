import hashlib
import re
import secrets
from datetime import UTC, datetime, timedelta
from hmac import compare_digest

from fastapi import HTTPException
from firebase_admin import firestore
from google.cloud.firestore import Client

from app.firebase.firestore import get_firestore_client
from app.models.auth import AuthenticatedUser
from app.services.auth_service import UserProfileService, email_account_state
from app.services.email_delivery import email_delivery_configured, send_email

CODE_LIFETIME = timedelta(minutes=15)
CODE_RESEND_DELAY = timedelta(minutes=1)
CODE_SEND_WINDOW = timedelta(days=1)
SEND_LIMIT = 5


def _code_digest(uid: str, address: str, code: str) -> str:
    return hashlib.sha256(f"{uid}\n{address}\n{code}".encode()).hexdigest()


class EmailAccountService(UserProfileService):
    def __init__(self, client: Client | None = None) -> None:
        super().__init__(client or get_firestore_client())

    def send_verification(self, user: AuthenticatedUser) -> None:
        if not email_delivery_configured():
            raise HTTPException(status_code=503, detail="Email verification is temporarily unavailable.")

        document = self.collection.document(user.uid)
        now = datetime.now(UTC)
        code = secrets.token_hex(8).upper()

        @firestore.transactional
        def reserve(transaction):
            profile = self._validate_session(document.get(transaction=transaction), user)
            address = profile.get("email")
            if not address:
                raise HTTPException(status_code=409, detail="This account has no email address.")
            if email_account_state(profile)["email_verified"]:
                raise HTTPException(status_code=409, detail="Your email is already verified.")

            last_sent = profile.get("email_code_sent_at")
            if isinstance(last_sent, datetime) and now - last_sent < CODE_RESEND_DELAY:
                raise HTTPException(status_code=429, detail="Wait one minute before requesting another code.")
            window_start = profile.get("email_send_window")
            if not isinstance(window_start, datetime) or now - window_start >= CODE_SEND_WINDOW:
                window_start, send_count = now, 0
            else:
                send_count = profile.get("email_send_count", 0)
            if send_count >= SEND_LIMIT:
                raise HTTPException(status_code=429, detail="Too many verification requests. Try again tomorrow.")

            digest = _code_digest(user.uid, address, code)
            transaction.update(document, {
                "email_code_hash": digest,
                "email_code_expires_at": now + CODE_LIFETIME,
                "email_code_sent_at": now,
                "email_send_window": window_start,
                "email_send_count": send_count + 1,
            })
            return address, digest

        address, digest = reserve(self.client.transaction())
        send_email(
            address,
            "Verify your Pet Tracker email",
            f"Enter this code in Pet Tracker to verify your email:\n\n{code}\n\n"
            "The code expires in 15 minutes. If you did not request it, you can ignore this message.",
            idempotency_key=f"verify-{digest}",
        )

    def verify(self, user: AuthenticatedUser, code: str) -> dict:
        invalid = "That code is invalid or expired. Request a new code if needed."
        if not re.fullmatch(r"[0-9A-F]{16}", code):
            raise HTTPException(status_code=400, detail=invalid)
        document = self.collection.document(user.uid)

        @firestore.transactional
        def consume(transaction):
            profile = self._validate_session(document.get(transaction=transaction), user)
            address = profile.get("email")
            digest = profile.get("email_code_hash")
            expires = profile.get("email_code_expires_at")
            if (not address or not isinstance(digest, str) or not isinstance(expires, datetime)
                or expires <= datetime.now(UTC) or not compare_digest(digest, _code_digest(user.uid, address, code))):
                raise HTTPException(status_code=400, detail=invalid)
            transaction.update(document, {
                "verified_email": address,
                "email_verified_at": firestore.SERVER_TIMESTAMP,
                "email_code_hash": firestore.DELETE_FIELD,
                "email_code_expires_at": firestore.DELETE_FIELD,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
            return self._profile(user, {**profile, "verified_email": address})

        return consume(self.client.transaction())

    def set_email_alerts(self, user: AuthenticatedUser, enabled: bool) -> dict:
        document = self.collection.document(user.uid)

        @firestore.transactional
        def set_preference(transaction):
            profile = self._validate_session(document.get(transaction=transaction), user)
            if enabled and not email_account_state(profile)["email_verified"]:
                raise HTTPException(status_code=409, detail="Verify your email before enabling email alerts.")
            if enabled and not email_delivery_configured():
                raise HTTPException(status_code=503, detail="Email alerts are temporarily unavailable.")
            transaction.update(document, {"email_alerts_enabled": enabled, "updated_at": firestore.SERVER_TIMESTAMP})
            return self._profile(user, {**profile, "email_alerts_enabled": enabled})

        return set_preference(self.client.transaction())
