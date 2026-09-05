from fastapi import APIRouter, Depends, HTTPException, status

from app.schemas.telemetry import DeviceTelemetryRequest, DeviceTelemetryResponse
from app.services.device_service import DeviceAuthenticationError
from app.services.telemetry_service import DeviceNotAssignedError, TelemetryService, TelemetryServiceError, get_telemetry_service

router = APIRouter(prefix="/api/v1/device", tags=["device telemetry"])


@router.post(
    "/telemetry",
    response_model=DeviceTelemetryResponse,
    summary="Submit ESP32 GPS telemetry",
    description=(
        "Receives GPS telemetry from an ESP32 tracker. This endpoint uses device credentials "
        "from device registration and does not use Firebase user authentication."
    ),
    responses={
        200: {"description": "Telemetry accepted."},
        401: {"description": "Invalid device credentials."},
        409: {"description": "Device is not assigned to a pet."},
        422: {"description": "Invalid telemetry payload."},
        503: {"description": "Telemetry service unavailable."},
    },
)
def receive_device_telemetry(
    data: DeviceTelemetryRequest,
    telemetry_service: TelemetryService = Depends(get_telemetry_service),
) -> DeviceTelemetryResponse:
    try:
        telemetry_service.receive_telemetry(data)
    except DeviceAuthenticationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device credentials.",
        ) from exc
    except DeviceNotAssignedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Device is not assigned to a pet.",
        ) from exc
    except TelemetryServiceError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Telemetry service is not available.",
        ) from exc

    return DeviceTelemetryResponse(message="Telemetry received successfully")
