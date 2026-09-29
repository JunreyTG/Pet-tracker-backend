import logging
import base64
import hashlib
import hmac
import json
import secrets
import time
from typing import Any

from fastapi import Header, HTTPException, status
from firebase_admin import firestore
from google.api_core.exceptions import GoogleAPIError
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


def get_current_user(authorization: str | None = Header(default=None)) -> AuthenticatedUser:
    token = extract_bearer_token(authorization)
    return verify_access_token(token)


class UserProfileService:
    def __init__(self, client: Client | None = None) -> None:
        self.client = client or get_firestore_client()
        self.collection = self.client.collection("users")

    def sync_user_profile(self, user: AuthenticatedUser) -> dict[str, Any]:
        document = self.collection.document(user.uid)
        snapshot = document.get()

        payload: dict[str, Any] = {
            "updated_at": firestore.SERVER_TIMESTAMP,
        }

        if user.display_name is not None:
            payload["display_name"] = user.display_name

        if user.email is not None:
            payload["email"] = str(user.email)

        if not snapshot.exists:
            payload["created_at"] = firestore.SERVER_TIMESTAMP
            payload.setdefault("display_name", "Firebase User")
            payload.setdefault("email", "")

        document.set(payload, merge=True)
        updated_snapshot = document.get()
        profile = updated_snapshot.to_dict() or {}
        return {
            "uid": user.uid,
            "email": profile.get("email") or user.email,
            "display_name": profile.get("display_name") or user.display_name,
        }

    def register_user(self, name: str, email: str, password: str) -> AuthenticatedUser:
        normalized_email = email.strip().lower()
        uid = _user_id_for_email(normalized_email)
        document = self.collection.document(uid)
        if document.get().exists:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account already exists for this email.")

        password_salt, password_hash = create_password_hash(password)
        document.set(
            {
                "email": normalized_email,
                "display_name": name.strip(),
                "password_salt": password_salt,
                "password_hash": password_hash,
                "created_at": firestore.SERVER_TIMESTAMP,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )
        return AuthenticatedUser(uid=uid, email=normalized_email, display_name=name.strip())

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
        )


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
