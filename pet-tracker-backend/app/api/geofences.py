from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.models.auth import AuthenticatedUser
from app.models.entities import Geofence
from app.schemas.geofences import GeofenceCreateRequest, GeofenceResponse, GeofenceUpdateRequest
from app.services.auth_service import get_current_user
from app.services.geofence_service import (
    GeofenceNotFoundError,
    GeofenceService,
    GeofenceServiceError,
    get_geofence_service,
)

router = APIRouter(prefix="/api/v1/geofences", tags=["geofences"])


def _not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Geofence was not found.")


def _unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Geofence service is not available.",
    )


@router.post("", response_model=GeofenceResponse, status_code=status.HTTP_201_CREATED)
def create_geofence(
    data: GeofenceCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    geofence_service: GeofenceService = Depends(get_geofence_service),
) -> Geofence:
    try:
        return geofence_service.create_geofence(current_user.uid, data)
    except GeofenceNotFoundError as exc:
        raise _not_found() from exc
    except GeofenceServiceError as exc:
        raise _unavailable() from exc


@router.get("", response_model=list[GeofenceResponse])
def list_geofences(
    current_user: AuthenticatedUser = Depends(get_current_user),
    geofence_service: GeofenceService = Depends(get_geofence_service),
) -> list[Geofence]:
    try:
        return geofence_service.list_geofences(current_user.uid)
    except GeofenceServiceError as exc:
        raise _unavailable() from exc


@router.get("/{geofence_id}", response_model=GeofenceResponse)
def get_geofence(
    geofence_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    geofence_service: GeofenceService = Depends(get_geofence_service),
) -> Geofence:
    try:
        return geofence_service.get_geofence(current_user.uid, geofence_id)
    except GeofenceNotFoundError as exc:
        raise _not_found() from exc
    except GeofenceServiceError as exc:
        raise _unavailable() from exc


@router.patch("/{geofence_id}", response_model=GeofenceResponse)
def update_geofence(
    geofence_id: str,
    data: GeofenceUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    geofence_service: GeofenceService = Depends(get_geofence_service),
) -> Geofence:
    try:
        return geofence_service.update_geofence(current_user.uid, geofence_id, data)
    except GeofenceNotFoundError as exc:
        raise _not_found() from exc
    except GeofenceServiceError as exc:
        raise _unavailable() from exc


@router.delete("/{geofence_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_geofence(
    geofence_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    geofence_service: GeofenceService = Depends(get_geofence_service),
) -> Response:
    try:
        geofence_service.delete_geofence(current_user.uid, geofence_id)
    except GeofenceNotFoundError as exc:
        raise _not_found() from exc
    except GeofenceServiceError as exc:
        raise _unavailable() from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
