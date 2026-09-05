from google.api_core.exceptions import GoogleAPIError

from app.firebase.admin import FirebaseInitializationError
from app.firebase.firestore import get_firestore_client


def verify_firebase_connectivity() -> None:
    try:
        client = get_firestore_client()
        next(client.collections(), None)
    except FirebaseInitializationError:
        raise
    except GoogleAPIError as exc:
        raise FirebaseInitializationError(
            "Firebase initialized, but Firestore connectivity could not be verified. "
            "Check project permissions and network access."
        ) from exc
    except Exception as exc:
        raise FirebaseInitializationError(
            "Firebase connectivity verification failed. Check Firebase configuration."
        ) from exc


if __name__ == "__main__":
    try:
        verify_firebase_connectivity()
    except FirebaseInitializationError as exc:
        raise SystemExit(f"Firebase verification failed: {exc}") from exc

    print("Firebase verification succeeded: Admin SDK initialized and Firestore responded.")
