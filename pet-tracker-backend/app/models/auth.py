from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, StringConstraints, model_validator


class AuthenticatedUser(BaseModel):
    model_config = ConfigDict(extra="ignore")

    uid: str
    email: EmailStr | None = None
    display_name: str | None = None
    phone: str | None = None
    location: str | None = None
    bio: str | None = None
    credential_version: str = ""
    email_verified: bool = False
    email_verification_required: bool = False
    email_alerts_enabled: bool = False


class CurrentUserResponse(BaseModel):
    uid: str
    email: EmailStr | None = None
    display_name: str | None = None
    phone: str | None = None
    location: str | None = None
    bio: str | None = None
    email_verified: bool = False
    email_verification_required: bool = False
    email_alerts_enabled: bool = False


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: CurrentUserResponse


class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    display_name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)] | None = None
    phone: Annotated[str, StringConstraints(strip_whitespace=True, max_length=30)] | None = None
    location: Annotated[str, StringConstraints(strip_whitespace=True, max_length=120)] | None = None
    bio: Annotated[str, StringConstraints(strip_whitespace=True, max_length=300)] | None = None

    @model_validator(mode="after")
    def _require_a_change(self) -> "ProfileUpdateRequest":
        if all(getattr(self, field) is None for field in ("display_name", "phone", "location", "bio")):
            raise ValueError("Provide at least one profile field to update.")
        return self


class PasswordChangeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: SecretStr = Field(min_length=1, max_length=128)
    new_password: SecretStr = Field(min_length=8, max_length=128)


class EmailVerificationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: Annotated[str, StringConstraints(strip_whitespace=True, to_upper=True, min_length=16, max_length=16)]


class EmailAlertsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    enabled: bool = Field(strict=True)
