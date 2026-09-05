from google.cloud.firestore import Client
from firebase_admin import firestore

from app.firebase.admin import initialize_firebase_app


def get_firestore_client() -> Client:
    initialize_firebase_app()
    return firestore.client()
