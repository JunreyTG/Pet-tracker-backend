from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.models.auth import AuthenticatedUser
from app.schemas.places import PlaceOptionResponse, PlaceSearchResponse
from app.services.auth_service import get_current_user
from app.services.place_service import PlaceService, PlaceServiceError, get_place_service

router = APIRouter(prefix="/api/v1/places", tags=["places"])


def _not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No matching place was found.")


def _unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Place search service is not available.",
    )


@router.get("/search", response_model=list[PlaceSearchResponse])
def search_places(
    country: str = Query(min_length=1),
    province: str = Query(min_length=1),
    city: str = Query(min_length=1),
    barangay: str = Query(min_length=1),
    limit: int = Query(default=5, ge=1, le=10),
    current_user: AuthenticatedUser = Depends(get_current_user),
    place_service: PlaceService = Depends(get_place_service),
) -> list[PlaceSearchResponse]:
    _ = current_user
    try:
        places = place_service.search_places(
            country=country,
            province=province,
            city=city,
            barangay=barangay,
            limit=limit,
        )
    except PlaceServiceError as exc:
        raise _unavailable() from exc

    if not places:
        raise _not_found()

    return places


@router.get("/countries", response_model=list[PlaceOptionResponse])
def list_countries(
    current_user: AuthenticatedUser = Depends(get_current_user),
    place_service: PlaceService = Depends(get_place_service),
) -> list[PlaceOptionResponse]:
    _ = current_user
    return place_service.list_countries()


@router.get("/provinces", response_model=list[PlaceOptionResponse])
def list_provinces(
    country_code: str = Query(default="PH", min_length=1),
    current_user: AuthenticatedUser = Depends(get_current_user),
    place_service: PlaceService = Depends(get_place_service),
) -> list[PlaceOptionResponse]:
    _ = current_user
    try:
        return place_service.list_provinces(country_code)
    except PlaceServiceError as exc:
        raise _unavailable() from exc


@router.get("/cities", response_model=list[PlaceOptionResponse])
def list_cities(
    province_code: str = Query(min_length=1),
    current_user: AuthenticatedUser = Depends(get_current_user),
    place_service: PlaceService = Depends(get_place_service),
) -> list[PlaceOptionResponse]:
    _ = current_user
    try:
        return place_service.list_cities(province_code)
    except PlaceServiceError as exc:
        raise _unavailable() from exc


@router.get("/barangays", response_model=list[PlaceOptionResponse])
def list_barangays(
    city_code: str = Query(min_length=1),
    current_user: AuthenticatedUser = Depends(get_current_user),
    place_service: PlaceService = Depends(get_place_service),
) -> list[PlaceOptionResponse]:
    _ = current_user
    try:
        return place_service.list_barangays(city_code)
    except PlaceServiceError as exc:
        raise _unavailable() from exc
