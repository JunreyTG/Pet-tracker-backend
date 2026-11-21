from google.cloud.firestore import Client
from firebase_admin import firestore

from app.firebase.admin import initialize_firebase_app

READ_TIMEOUT_SECONDS = 8


def get_firestore_client() -> Client:
    initialize_firebase_app()
    return firestore.client()
