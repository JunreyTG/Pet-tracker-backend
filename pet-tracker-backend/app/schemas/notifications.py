from datetime import datetime

from pydantic import Field, field_validator

from app.models.entities import FirestoreModel, NotificationPlatform


class NotificationTokenRegisterRequest(FirestoreModel):
    token: str = Field(min_length=1)
    platform: NotificationPlatform
    device_name: str | None = None

    @field_validator("token")
    @classmethod
    def token_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("FCM token must not be empty.")
        return value


class NotificationTokenRegisterResponse(FirestoreModel):
    message: str
    token_id: str


class NotificationTokenResponse(FirestoreModel):
    token_id: str
    platform: NotificationPlatform
    device_name: str | None = None
    active: bool
    created_at: datetime
    updated_at: datetime
    last_used_at: datetime | None = None
