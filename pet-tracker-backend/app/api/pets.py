from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.models.auth import AuthenticatedUser
from app.models.entities import Pet
from app.schemas.pets import PetCreateRequest, PetResponse, PetUpdateRequest
from app.services.auth_service import get_current_user
from app.services.pet_service import PetNotFoundError, PetService, PetServiceError, get_pet_service

router = APIRouter(prefix="/api/v1/pets", tags=["pets"])


def _pet_not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pet was not found.")


def _pet_service_unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Pet service is not available.",
    )


@router.post("", response_model=PetResponse, status_code=status.HTTP_201_CREATED)
def create_pet(
    data: PetCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    pet_service: PetService = Depends(get_pet_service),
) -> Pet:
    try:
        return pet_service.create_pet(current_user.uid, data)
    except PetServiceError as exc:
        raise _pet_service_unavailable() from exc


@router.get("", response_model=list[PetResponse])
def list_pets(
    current_user: AuthenticatedUser = Depends(get_current_user),
    pet_service: PetService = Depends(get_pet_service),
) -> list[Pet]:
    try:
        return pet_service.list_pets(current_user.uid)
    except PetServiceError as exc:
        raise _pet_service_unavailable() from exc


@router.get("/{pet_id}", response_model=PetResponse)
def get_pet(
    pet_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    pet_service: PetService = Depends(get_pet_service),
) -> Pet:
    try:
        return pet_service.get_pet(current_user.uid, pet_id)
    except PetNotFoundError as exc:
        raise _pet_not_found() from exc
    except PetServiceError as exc:
        raise _pet_service_unavailable() from exc


@router.patch("/{pet_id}", response_model=PetResponse)
def update_pet(
    pet_id: str,
    data: PetUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    pet_service: PetService = Depends(get_pet_service),
) -> Pet:
    try:
        return pet_service.update_pet(current_user.uid, pet_id, data)
    except PetNotFoundError as exc:
        raise _pet_not_found() from exc
    except PetServiceError as exc:
        raise _pet_service_unavailable() from exc


@router.delete("/{pet_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_pet(
    pet_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    pet_service: PetService = Depends(get_pet_service),
) -> Response:
    try:
        pet_service.delete_pet(current_user.uid, pet_id)
    except PetNotFoundError as exc:
        raise _pet_not_found() from exc
    except PetServiceError as exc:
        raise _pet_service_unavailable() from exc

    return Response(status_code=status.HTTP_204_NO_CONTENT)
