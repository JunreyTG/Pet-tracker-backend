from pydantic import BaseModel, ConfigDict, EmailStr, Field


class AuthenticatedUser(BaseModel):
    model_config = ConfigDict(extra="ignore")

    uid: str
    email: EmailStr | None = None
    display_name: str | None = None


class CurrentUserResponse(BaseModel):
    uid: str
    email: EmailStr | None = None
    display_name: str | None = None


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
