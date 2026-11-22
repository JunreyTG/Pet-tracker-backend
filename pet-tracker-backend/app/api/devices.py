from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status

from app.models.auth import AuthenticatedUser
from app.models.entities import Device
from app.schemas.devices import (
    DeviceAssignRequest,
    DeviceClaimRequest,
    DeviceJoinRequest,
    DeviceRegisterRequest,
    DeviceRegistrationResponse,
    DeviceResponse,
)
from app.services.auth_service import get_current_user
from app.services.device_service import (
    DeviceConflictError,
    DeviceNotFoundError,
    DeviceRegistration,
    DeviceService,
    DeviceServiceError,
    get_device_service,
)

router = APIRouter(prefix="/api/v1/devices", tags=["devices"])


def _device_payload(device: Device) -> dict[str, Any]:
    return device.model_dump(exclude={"device_secret_hash"})


def _registration_payload(registration: DeviceRegistration) -> dict[str, Any]:
    payload = _device_payload(registration.device)
    payload["device_secret"] = registration.device_secret
    return payload


def _not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device was not found.")


def _conflict(message: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=message)


def _unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Device service is not available.",
    )


@router.post("", response_model=DeviceRegistrationResponse, status_code=status.HTTP_201_CREATED)
def register_device(
    data: DeviceRegisterRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _registration_payload(device_service.register_device(current_user.uid, data))
    except DeviceConflictError as exc:
        raise _conflict(str(exc)) from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.post("/claim", response_model=DeviceResponse)
def claim_device(
    data: DeviceClaimRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _device_payload(device_service.claim_device(current_user.uid, data.device_id, data.pet_id))
    except DeviceNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Tracker or pet not available for this account.") from exc
    except DeviceConflictError as exc:
        raise _conflict(str(exc)) from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.post("/join", response_model=DeviceResponse)
def join_device(
    data: DeviceJoinRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _device_payload(device_service.join_device(current_user.uid, data.device_id))
    except DeviceNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail="No tracker with that ID was found. Ask the owner to link it first.",
        ) from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.delete("/{device_id}/viewers/{viewer_uid}", response_model=DeviceResponse)
def remove_viewer(
    device_id: str,
    viewer_uid: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _device_payload(device_service.remove_viewer(current_user.uid, device_id, viewer_uid))
    except DeviceNotFoundError as exc:
        raise _not_found() from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.get("", response_model=list[DeviceResponse])
def list_devices(
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> list[dict[str, Any]]:
    try:
        return [_device_payload(device) for device in device_service.list_devices(current_user.uid)]
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.get("/{device_id}", response_model=DeviceResponse)
def get_device(
    device_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _device_payload(device_service.get_device(current_user.uid, device_id))
    except DeviceNotFoundError as exc:
        raise _not_found() from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.post("/{device_id}/assign", response_model=DeviceResponse)
def assign_device(
    device_id: str,
    data: DeviceAssignRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _device_payload(device_service.assign_device_to_pet(current_user.uid, device_id, data.pet_id))
    except DeviceNotFoundError as exc:
        raise _not_found() from exc
    except DeviceConflictError as exc:
        raise _conflict(str(exc)) from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.delete("/{device_id}/assignment", response_model=DeviceResponse)
def unassign_device(
    device_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        return _device_payload(device_service.unassign_device(current_user.uid, device_id))
    except DeviceNotFoundError as exc:
        raise _not_found() from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc
