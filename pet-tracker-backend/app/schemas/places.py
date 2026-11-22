from pydantic import Field

from app.models.entities import FirestoreModel, Location


class PlaceOptionResponse(FirestoreModel):
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)


class PlaceSearchResponse(FirestoreModel):
    display_name: str = Field(min_length=1)
    location: Location


class PlaceReverseResponse(FirestoreModel):
    display_name: str = Field(min_length=1)
    country: str | None = None
    province: str | None = None
    city: str | None = None
    barangay: str | None = None
    location: Location
