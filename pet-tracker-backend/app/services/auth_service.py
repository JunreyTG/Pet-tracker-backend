import logging
import base64
import hashlib
import hmac
import json
import secrets
import time
from typing import Any

from fastapi import Depends, Header, HTTPException, status
from firebase_admin import firestore
from google.api_core.exceptions import AlreadyExists, GoogleAPIError
from google.cloud.firestore import Client

from app.core.config import settings
from app.firebase.firestore import get_firestore_client
from app.models.auth import AuthenticatedUser

logger = logging.getLogger(__name__)


AUTHENTICATION_ERROR = "Invalid or missing authentication token."
PASSWORD_ITERATIONS = 260_000


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=AUTHENTICATION_ERROR,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _invalid_credentials() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Email or password is incorrect.",
    )


def extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise _unauthorized()

    scheme, separator, token = authorization.partition(" ")
    token = token.strip()
    if separator != " " or scheme.lower() != "bearer" or not token or any(char.isspace() for char in token):
        raise _unauthorized()

    return token


def _b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _b64decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _user_id_for_email(email: str) -> str:
    normalized_email = email.strip().lower()
    return hashlib.sha256(normalized_email.encode("utf-8")).hexdigest()


def _hash_password(password: str, salt: bytes) -> str:
    return _b64encode(hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PASSWORD_ITERATIONS))


def create_password_hash(password: str) -> tuple[str, str]:
    salt = secrets.token_bytes(16)
    return _b64encode(salt), _hash_password(password, salt)


def verify_password(password: str, salt: str, password_hash: str) -> bool:
    try:
        actual_hash = _hash_password(password, _b64decode(salt))
    except Exception:
        return False
    return hmac.compare_digest(actual_hash, password_hash)


def create_access_token(user: AuthenticatedUser) -> str:
    payload = {
        "uid": user.uid,
        "email": user.email,
        "display_name": user.display_name,
        "credential_version": user.credential_version,
        "exp": int(time.time()) + settings.auth_token_ttl_seconds,
    }
    payload_data = _b64encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = hmac.new(settings.auth_token_secret.encode("utf-8"), payload_data.encode("ascii"), hashlib.sha256).digest()
    return f"{payload_data}.{_b64encode(signature)}"


def verify_access_token(token: str) -> AuthenticatedUser:
    try:
        payload_data, signature = token.split(".", 1)
        expected_signature = hmac.new(settings.auth_token_secret.encode("utf-8"), payload_data.encode("ascii"), hashlib.sha256).digest()
        if not hmac.compare_digest(_b64decode(signature), expected_signature):
            raise ValueError("invalid signature")
        payload = json.loads(_b64decode(payload_data))
        if int(payload.get("exp", 0)) < int(time.time()):
            raise ValueError("expired token")
        return AuthenticatedUser(
            uid=str(payload["uid"]),
            email=payload.get("email"),
            display_name=payload.get("display_name"),
            credential_version=payload.get("credential_version", ""),
        )
    except Exception as exc:
        logger.info("App token verification failed: %s", exc.__class__.__name__)
        raise _unauthorized() from exc


def authenticated_user_from_token(decoded_token: dict[str, Any]) -> AuthenticatedUser:
    uid = decoded_token.get("uid") or decoded_token.get("sub")
    if not uid or not isinstance(uid, str):
        logger.info("Firebase ID token verification returned no UID.")
        raise _unauthorized()

    return AuthenticatedUser(
        uid=uid,
        email=decoded_token.get("email"),
        display_name=decoded_token.get("name"),
    )


def get_session_user(authorization: str | None = Header(default=None)) -> AuthenticatedUser:
    token = extract_bearer_token(authorization)
    user = verify_access_token(token)
    try:
        return UserProfileService().check_session(user)
    except GoogleAPIError as exc:
        raise _profile_unavailable() from exc


def get_current_user(user: AuthenticatedUser = Depends(get_session_user)) -> AuthenticatedUser:
    if user.email_verification_required:
        raise HTTPException(status_code=403, detail="Verify your email to finish setting up your account.")
    return user


def _profile_unavailable() -> HTTPException:
    return HTTPException(status_code=503, detail="User profile service is not available.")


class UserProfileService:
    def __init__(self, client: Client | None = None) -> None:
        self.client = client or get_firestore_client()
        self.collection = self.client.collection("users")

    def sync_user_profile(self, user: AuthenticatedUser) -> dict[str, Any]:
        document = self.collection.document(user.uid)
        snapshot = document.get()
        if snapshot.exists:
            return self._profile(user, snapshot.to_dict() or {})

        payload: dict[str, Any] = {
            "updated_at": firestore.SERVER_TIMESTAMP,
        }

        if user.display_name is not None:
            payload["display_name"] = user.display_name

        if user.email is not None:
            payload["email"] = str(user.email)

        payload["created_at"] = firestore.SERVER_TIMESTAMP
        payload.setdefault("display_name", "Pet Owner")
        payload.setdefault("email", "")

        document.set(payload, merge=True)
        return self._profile(user, payload)

    @staticmethod
    def _profile(user: AuthenticatedUser, profile: dict[str, Any]) -> dict[str, Any]:
        return {
            "uid": user.uid,
            "email": profile.get("email") or user.email,
            "display_name": profile.get("display_name") or user.display_name,
            "phone": profile.get("phone") or None,
            "location": profile.get("location") or None,
            "bio": profile.get("bio") or None,
            **email_account_state(profile),
        }

    @staticmethod
    def _validate_session(snapshot, user: AuthenticatedUser) -> dict[str, Any]:
        data = snapshot.to_dict() or {}
        if not snapshot.exists or data.get("credential_version", "") != user.credential_version:
            raise _unauthorized()
        return data

    def check_session(self, user: AuthenticatedUser) -> AuthenticatedUser:
        profile = self._validate_session(self.collection.document(user.uid).get(), user)
        return user.model_copy(update=email_account_state(profile))

    def update_profile(self, user: AuthenticatedUser, changes: dict[str, str | None]) -> dict[str, Any]:
        document = self.collection.document(user.uid)
        profile = self._validate_session(document.get(), user)
        payload: dict[str, Any] = {}
        updated = dict(profile)
        for field, value in changes.items():
            if value is None:
                continue
            if value:
                payload[field] = value
                updated[field] = value
            else:
                payload[field] = firestore.DELETE_FIELD
                updated.pop(field, None)
        payload["updated_at"] = firestore.SERVER_TIMESTAMP
        document.update(payload)
        return self._profile(user, updated)

    def change_password(self, user: AuthenticatedUser, current: str, replacement: str) -> None:
        document = self.collection.document(user.uid)

        @firestore.transactional
        def change(transaction):
            profile = self._validate_session(document.get(transaction=transaction), user)
            salt = profile.get("password_salt")
            old_hash = profile.get("password_hash")
            if not isinstance(salt, str) or not isinstance(old_hash, str) or not verify_password(current, salt, old_hash):
                raise HTTPException(status_code=400, detail="Current password is incorrect.")
            if current == replacement:
                raise HTTPException(status_code=400, detail="Choose a different password.")
            new_salt, new_hash = create_password_hash(replacement)
            transaction.update(document, {
                "password_salt": new_salt,
                "password_hash": new_hash,
                "credential_version": secrets.token_hex(16),
                "updated_at": firestore.SERVER_TIMESTAMP,
            })

        change(self.client.transaction())

    def register_user(self, name: str, email: str, password: str) -> AuthenticatedUser:
        normalized_email = email.strip().lower()
        uid = _user_id_for_email(normalized_email)
        document = self.collection.document(uid)
        if document.get().exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account already exists for this email.")

        password_salt, password_hash = create_password_hash(password)
        credential_version = secrets.token_hex(16)
        try:
            document.create({
                "email": normalized_email,
                "display_name": name.strip(),
                "password_salt": password_salt,
                "password_hash": password_hash,
                "credential_version": credential_version,
                "requires_email_verification": True,
                "created_at": firestore.SERVER_TIMESTAMP,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
        except AlreadyExists as exc:
            raise HTTPException(status_code=409, detail="An account already exists for this email.") from exc
        return AuthenticatedUser(
            uid=uid, email=normalized_email, display_name=name.strip(),
            credential_version=credential_version, email_verification_required=True,
        )

    def authenticate_user(self, email: str, password: str) -> AuthenticatedUser:
        normalized_email = email.strip().lower()
        uid = _user_id_for_email(normalized_email)
        snapshot = self.collection.document(uid).get()
        if not snapshot.exists:
            raise _invalid_credentials()

        profile = snapshot.to_dict() or {}
        password_salt = profile.get("password_salt")
        password_hash = profile.get("password_hash")
        if not isinstance(password_salt, str) or not isinstance(password_hash, str) or not verify_password(password, password_salt, password_hash):
            raise _invalid_credentials()

        return AuthenticatedUser(
            uid=uid,
            email=profile.get("email") or normalized_email,
            display_name=profile.get("display_name") or "Pet Owner",
            phone=profile.get("phone") or None,
            location=profile.get("location") or None,
            bio=profile.get("bio") or None,
            credential_version=profile.get("credential_version", ""),
            **email_account_state(profile),
        )


def email_account_state(profile: dict[str, Any]) -> dict[str, bool]:
    address = profile.get("email")
    verified = bool(address and profile.get("verified_email") == address)
    return {
        "email_verified": verified,
        "email_verification_required": profile.get("requires_email_verification") is True and not verified,
        "email_alerts_enabled": verified and profile.get("email_alerts_enabled") is True,
    }


def sync_current_user_profile(user: AuthenticatedUser) -> dict[str, Any]:
    try:
        return UserProfileService().sync_user_profile(user)
    except GoogleAPIError as exc:
        logger.info("Firestore user profile synchronization failed: %s", exc.__class__.__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User profile service is not available.",
        ) from exc


def register_with_password(name: str, email: str, password: str) -> AuthenticatedUser:
    try:
        return UserProfileService().register_user(name, email, password)
    except HTTPException:
        raise
    except GoogleAPIError as exc:
        logger.info("Firestore user registration failed: %s", exc.__class__.__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User profile service is not available.",
        ) from exc


def authenticate_with_password(email: str, password: str) -> AuthenticatedUser:
    try:
        return UserProfileService().authenticate_user(email, password)
    except HTTPException:
        raise
    except GoogleAPIError as exc:
        logger.info("Firestore user login failed: %s", exc.__class__.__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User profile service is not available.",
        ) from exc
