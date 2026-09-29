from collections.abc import Sequence
from datetime import datetime
from typing import Any, Generic, TypeVar

from firebase_admin import firestore
from google.cloud.firestore import Client, DocumentSnapshot
from pydantic import BaseModel

from app.firebase.firestore import get_firestore_client
from app.models.entities import (
    Alert,
    AlertCreate,
    AlertUpdate,
    Device,
    DeviceCreate,
    DeviceUpdate,
    Geofence,
    GeofenceCreate,
    GeofenceUpdate,
    NotificationToken,
    NotificationTokenCreate,
    NotificationTokenUpdate,
    Pet,
    PetCreate,
    PetUpdate,
    TrackingHistory,
    TrackingHistoryCreate,
    User,
    UserCreate,
    UserUpdate,
)

ModelT = TypeVar("ModelT", bound=BaseModel)
CreateT = TypeVar("CreateT", bound=BaseModel)
UpdateT = TypeVar("UpdateT", bound=BaseModel)


class FirestoreRepository(Generic[ModelT, CreateT, UpdateT]):
    collection_name: str
    model_class: type[ModelT]
    timestamp_fields: Sequence[str] = ("created_at", "updated_at")

    def __init__(self, client: Client | None = None) -> None:
        self.client = client or get_firestore_client()
        self.collection = self.client.collection(self.collection_name)

    def create(self, data: CreateT, document_id: str | None = None) -> ModelT:
        payload = self._dump(data)
        for field in self.timestamp_fields:
            if payload.get(field) is None:
                payload[field] = firestore.SERVER_TIMESTAMP

        document = self.collection.document(document_id) if document_id else self.collection.document()
        document.set(payload)
        snapshot = document.get()
        return self._from_snapshot(snapshot)

    def get(self, document_id: str) -> ModelT | None:
        snapshot = self.collection.document(document_id).get()
        if not snapshot.exists:
            return None
        return self._from_snapshot(snapshot)

    def update(self, document_id: str, data: UpdateT) -> ModelT | None:
        payload = self._dump(data, exclude_unset=True)
        if not payload:
            return self.get(document_id)

        if "updated_at" in self.timestamp_fields:
            payload["updated_at"] = firestore.SERVER_TIMESTAMP

        document = self.collection.document(document_id)
        if not document.get().exists:
            return None

        document.update(payload)
        return self._from_snapshot(document.get())

    def update_fields(self, document_id: str, payload: dict[str, Any]) -> ModelT | None:
        if not payload:
            return self.get(document_id)

        if "updated_at" in self.timestamp_fields:
            payload = {**payload, "updated_at": firestore.SERVER_TIMESTAMP}

        document = self.collection.document(document_id)
        if not document.get().exists:
            return None

        document.update(payload)
        return self._from_snapshot(document.get())

    def delete(self, document_id: str) -> None:
        self.collection.document(document_id).delete()

    def query_by_owner(self, owner_id: str) -> list[ModelT]:
        return self._where_equals("owner_id", owner_id)

    def query_by_pet(self, pet_id: str) -> list[ModelT]:
        return self._where_equals("pet_id", pet_id)

    def query_by_device(self, device_id: str) -> list[ModelT]:
        return self._where_equals("device_id", device_id)

    def _where_equals(self, field: str, value: str) -> list[ModelT]:
        snapshots = self.collection.where(filter=firestore.FieldFilter(field, "==", value)).stream()
        return [self._from_snapshot(snapshot) for snapshot in snapshots]

    def _from_snapshot(self, snapshot: DocumentSnapshot) -> ModelT:
        data = snapshot.to_dict() or {}
        data["id"] = snapshot.id
        return self.model_class.model_validate(data)

    @staticmethod
    def _dump(model: BaseModel, exclude_unset: bool = False) -> dict[str, Any]:
        return model.model_dump(mode="python", exclude_unset=exclude_unset)


class UserRepository(FirestoreRepository[User, UserCreate, UserUpdate]):
    collection_name = "users"
    model_class = User

    def create(self, user_id: str, data: UserCreate) -> User:  # type: ignore[override]
        return super().create(data, document_id=user_id)


class PetRepository(FirestoreRepository[Pet, PetCreate, PetUpdate]):
    collection_name = "pets"
    model_class = Pet


class DeviceRepository(FirestoreRepository[Device, DeviceCreate, DeviceUpdate]):
    collection_name = "devices"
    model_class = Device

    def create(self, data: DeviceCreate) -> Device:  # type: ignore[override]
        return super().create(data, document_id=data.device_id)

    def query_by_status(self, status: str) -> list[Device]:
        return self._where_equals("status", status)


class TrackingHistoryRepository(
    FirestoreRepository[TrackingHistory, TrackingHistoryCreate, TrackingHistoryCreate]
):
    collection_name = "tracking_history"
    model_class = TrackingHistory
    timestamp_fields = ("recorded_at",)

    def query_history_for_pet(
        self,
        owner_id: str,
        pet_id: str,
        limit: int,
        start_time: datetime | None = None,
        end_time: datetime | None = None,
    ) -> list[TrackingHistory]:
        # Keep this query on pet_id only to avoid requiring Firestore composite
        # indexes for owner_id/pet_id/recorded_at combinations. Ownership,
        # date range, ordering, and limit are applied below.
        query = self.collection.where(filter=firestore.FieldFilter("pet_id", "==", pet_id))
        records = [self._from_snapshot(snapshot) for snapshot in query.stream()]
        filtered = [record for record in records if record.owner_id == owner_id]
        if start_time is not None:
            filtered = [record for record in filtered if record.recorded_at >= start_time]
        if end_time is not None:
            filtered = [record for record in filtered if record.recorded_at <= end_time]

        filtered.sort(key=lambda record: record.recorded_at)
        return filtered[-limit:]


class GeofenceRepository(FirestoreRepository[Geofence, GeofenceCreate, GeofenceUpdate]):
    collection_name = "geofences"
    model_class = Geofence

    def query_enabled_by_pet(self, pet_id: str) -> list[Geofence]:
        return [geofence for geofence in self.query_by_pet(pet_id) if geofence.enabled]


class AlertRepository(FirestoreRepository[Alert, AlertCreate, AlertUpdate]):
    collection_name = "alerts"
    model_class = Alert
    timestamp_fields = ("created_at",)


class NotificationTokenRepository(
    FirestoreRepository[NotificationToken, NotificationTokenCreate, NotificationTokenUpdate]
):
    collection_name = "notification_tokens"
    model_class = NotificationToken

    def create(self, data: NotificationTokenCreate, token_id: str) -> NotificationToken:  # type: ignore[override]
        return super().create(data, document_id=token_id)

    def query_active_by_owner(self, owner_id: str) -> list[NotificationToken]:
        return [token for token in self.query_by_owner(owner_id) if token.active]
