import logging
from typing import Any

from fastapi import Header, HTTPException, status
from firebase_admin import auth, firestore
from google.api_core.exceptions import GoogleAPIError
from google.cloud.firestore import Client

from app.firebase.admin import FirebaseInitializationError, initialize_firebase_app
from app.firebase.firestore import get_firestore_client
from app.models.auth import AuthenticatedUser

logger = logging.getLogger(__name__)


AUTHENTICATION_ERROR = "Invalid or missing Firebase authentication token."


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=AUTHENTICATION_ERROR,
        headers={"WWW-Authenticate": "Bearer"},
    )


def extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise _unauthorized()

    scheme, separator, token = authorization.partition(" ")
    token = token.strip()
    if separator != " " or scheme.lower() != "bearer" or not token or any(char.isspace() for char in token):
        raise _unauthorized()

    return token


def verify_firebase_id_token(token: str) -> dict[str, Any]:
    try:
        initialize_firebase_app()
        return auth.verify_id_token(token, check_revoked=True)
    except FirebaseInitializationError:
        logger.exception("Firebase Admin SDK is not initialized for authentication.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service is not available.",
        )
    except Exception as exc:
        logger.info("Firebase ID token verification failed: %s", exc.__class__.__name__)
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
    decoded_token = verify_firebase_id_token(token)
    return authenticated_user_from_token(decoded_token)


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


def sync_current_user_profile(user: AuthenticatedUser) -> dict[str, Any]:
    try:
        return UserProfileService().sync_user_profile(user)
    except GoogleAPIError as exc:
        logger.info("Firestore user profile synchronization failed: %s", exc.__class__.__name__)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User profile service is not available.",
        ) from exc
