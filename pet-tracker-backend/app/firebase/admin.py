import json
from pathlib import Path

import firebase_admin
from firebase_admin import App, credentials

from app.core.config import settings


class FirebaseInitializationError(RuntimeError):
    """Raised when Firebase Admin SDK cannot be initialized safely."""


def initialize_firebase_app() -> App:
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    options: dict[str, str] = {}
    if settings.firebase_project_id:
        options["projectId"] = settings.firebase_project_id

    # 1. Check if service account JSON content was provided directly in env var
    if settings.firebase_service_account_json:
        try:
            cert_dict = json.loads(settings.firebase_service_account_json)
            credential = credentials.Certificate(cert_dict)
            return firebase_admin.initialize_app(credential, options or None)
        except Exception as exc:
            raise FirebaseInitializationError(
                f"FIREBASE_SERVICE_ACCOUNT_JSON could not be parsed: {exc}"
            ) from exc

    # 2. Otherwise fall back to local file path
    credentials_path = settings.firebase_credentials_path
    if not credentials_path.is_absolute():
        credentials_path = Path.cwd() / credentials_path

    if not credentials_path.exists():
        raise FirebaseInitializationError(
            "Firebase credentials file was not found. Set FIREBASE_SERVICE_ACCOUNT_JSON "
            "or FIREBASE_CREDENTIALS_PATH."
        )

    if not credentials_path.is_file():
        raise FirebaseInitializationError(
            "FIREBASE_CREDENTIALS_PATH must point to a Firebase service-account JSON file."
        )

    try:
        credential = credentials.Certificate(str(credentials_path))
        return firebase_admin.initialize_app(credential, options or None)
    except (OSError, ValueError) as exc:
        raise FirebaseInitializationError(
            "Firebase Admin SDK could not be initialized. Check that the service-account "
            "JSON file is valid and that FIREBASE_PROJECT_ID matches the Firebase project."
        ) from exc
