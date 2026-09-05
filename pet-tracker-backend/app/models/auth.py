from pydantic import BaseModel, ConfigDict, EmailStr


class AuthenticatedUser(BaseModel):
    model_config = ConfigDict(extra="ignore")

    uid: str
    email: EmailStr | None = None
    display_name: str | None = None


class CurrentUserResponse(BaseModel):
    uid: str
    email: EmailStr | None = None
    display_name: str | None = None
