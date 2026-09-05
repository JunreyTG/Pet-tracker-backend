from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.models.auth import AuthenticatedUser
from app.schemas.notifications import (
    NotificationTokenRegisterRequest,
    NotificationTokenRegisterResponse,
    NotificationTokenResponse,
)
from app.services.auth_service import get_current_user
from app.services.notification_service import (
    NotificationService,
    NotificationServiceError,
    NotificationTokenNotFoundError,
    get_notification_service,
    notification_token_response,
)

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


def _not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification token was not found.")


def _unavailable() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Notification service is not available.",
    )


@router.post("/tokens", response_model=NotificationTokenRegisterResponse, status_code=status.HTTP_201_CREATED)
def register_notification_token(
    data: NotificationTokenRegisterRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    notification_service: NotificationService = Depends(get_notification_service),
) -> NotificationTokenRegisterResponse:
    try:
        token = notification_service.register_token(current_user.uid, data)
    except NotificationTokenNotFoundError as exc:
        raise _not_found() from exc
    except NotificationServiceError as exc:
        raise _unavailable() from exc

    return NotificationTokenRegisterResponse(
        message="Notification token registered successfully",
        token_id=token.id,
    )


@router.get("/tokens", response_model=list[NotificationTokenResponse])
def list_notification_tokens(
    current_user: AuthenticatedUser = Depends(get_current_user),
    notification_service: NotificationService = Depends(get_notification_service),
) -> list[dict[str, Any]]:
    try:
        return [notification_token_response(token) for token in notification_service.list_tokens(current_user.uid)]
    except NotificationServiceError as exc:
        raise _unavailable() from exc


@router.delete("/tokens/{token_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notification_token(
    token_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    notification_service: NotificationService = Depends(get_notification_service),
) -> Response:
    try:
        notification_service.deactivate_token(current_user.uid, token_id)
    except NotificationTokenNotFoundError as exc:
        raise _not_found() from exc
    except NotificationServiceError as exc:
        raise _unavailable() from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
