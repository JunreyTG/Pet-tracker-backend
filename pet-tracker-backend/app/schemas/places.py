from pydantic import Field

from app.models.entities import FirestoreModel, Location


class PlaceOptionResponse(FirestoreModel):
    code: str = Field(min_length=1)
    name: str = Field(min_length=1)


class PlaceSearchResponse(FirestoreModel):
    display_name: str = Field(min_length=1)
    location: Location
