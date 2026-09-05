from app.models.entities import FirestoreModel, Pet
from pydantic import Field


class PetCreateRequest(FirestoreModel):
    name: str = Field(min_length=1)
    species: str = Field(min_length=1)
    breed: str | None = None
    age: int | None = Field(default=None, ge=0)
    photo_url: str | None = None


class PetUpdateRequest(FirestoreModel):
    name: str | None = Field(default=None, min_length=1)
    species: str | None = Field(default=None, min_length=1)
    breed: str | None = None
    age: int | None = Field(default=None, ge=0)
    photo_url: str | None = None


PetResponse = Pet
