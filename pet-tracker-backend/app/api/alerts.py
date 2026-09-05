from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.models.auth import AuthenticatedUser
from app.models.entities import Alert, AlertType
from app.schemas.alerts import AlertResponse, AlertUpdateRequest
from app.services.alert_service import AlertNotFoundError, AlertService, AlertServiceError, get_alert_service
from app.services.auth_service import get_current_user

router = APIRouter(prefix="/api/v1/alerts", tags=["alerts"])


def _not_found() -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert was not found.")


def _unavailable() -> HTTPException:
    return HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Alert service is not available.")


@router.get("", response_model=list[AlertResponse])
def list_alerts(
    pet_id: str | None = None,
    type: AlertType | None = Query(default=None),
    read: bool | None = None,
    current_user: AuthenticatedUser = Depends(get_current_user),
    alert_service: AlertService = Depends(get_alert_service),
) -> list[Alert]:
    try:
        return alert_service.list_alerts(current_user.uid, pet_id=pet_id, alert_type=type, read=read)
    except AlertServiceError as exc:
        raise _unavailable() from exc


@router.get("/{alert_id}", response_model=AlertResponse)
def get_alert(
    alert_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    alert_service: AlertService = Depends(get_alert_service),
) -> Alert:
    try:
        return alert_service.get_alert(current_user.uid, alert_id)
    except AlertNotFoundError as exc:
        raise _not_found() from exc
    except AlertServiceError as exc:
        raise _unavailable() from exc


@router.patch("/{alert_id}", response_model=AlertResponse)
def update_alert(
    alert_id: str,
    data: AlertUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    alert_service: AlertService = Depends(get_alert_service),
) -> Alert:
    try:
        return alert_service.update_alert(current_user.uid, alert_id, data)
    except AlertNotFoundError as exc:
        raise _not_found() from exc
    except AlertServiceError as exc:
        raise _unavailable() from exc


@router.delete("/{alert_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_alert(
    alert_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    alert_service: AlertService = Depends(get_alert_service),
) -> Response:
    try:
        alert_service.delete_alert(current_user.uid, alert_id)
    except AlertNotFoundError as exc:
        raise _not_found() from exc
    except AlertServiceError as exc:
        raise _unavailable() from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
