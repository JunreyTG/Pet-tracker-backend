from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.models.auth import AuthenticatedUser
from app.models.entities import Device
from app.schemas.devices import (
    DeviceAssignRequest,
    DeviceProvisioningRequest,
    DeviceProvisioningResponse,
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
TELEMETRY_PATH = "/api/v1/device/telemetry"


def _device_payload(device: Device) -> dict[str, Any]:
    return device.model_dump(exclude={"device_secret_hash"})


def _registration_payload(registration: DeviceRegistration) -> dict[str, Any]:
    payload = _device_payload(registration.device)
    payload["device_secret"] = registration.device_secret
    return payload


def _provisioning_payload(registration: DeviceRegistration, backend_url: str) -> dict[str, Any]:
    clean_backend_url = backend_url.rstrip("/")
    payload = _registration_payload(registration)
    payload["backend_url"] = clean_backend_url
    payload["telemetry_path"] = TELEMETRY_PATH
    payload["telemetry_url"] = f"{clean_backend_url}{TELEMETRY_PATH}"
    payload["setup_hotspot_ssid"] = f"PET_TRACKER_SETUP_{registration.device.device_id}"
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
        raise _conflict("Device is already registered.") from exc
    except DeviceServiceError as exc:
        raise _unavailable() from exc


@router.post("/setup", response_model=DeviceProvisioningResponse, status_code=status.HTTP_201_CREATED)
def create_device_provisioning(
    data: DeviceProvisioningRequest,
    request: Request,
    current_user: AuthenticatedUser = Depends(get_current_user),
    device_service: DeviceService = Depends(get_device_service),
) -> dict[str, Any]:
    try:
        backend_url = data.backend_url or str(request.base_url)
        registration = device_service.register_device(current_user.uid, DeviceRegisterRequest(device_id=data.device_id))
        return _provisioning_payload(registration, backend_url)
    except DeviceConflictError as exc:
        raise _conflict("Device is already registered. Use the saved device secret or register a new tracker ID.") from exc
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
