from fastapi import APIRouter, Depends, HTTPException, Response
from google.api_core.exceptions import GoogleAPIError

from app.firebase.admin import FirebaseInitializationError
from app.models.auth import AuthResponse, AuthenticatedUser, CurrentUserResponse, EmailAlertsRequest, EmailVerificationRequest, LoginRequest, PasswordChangeRequest, ProfileUpdateRequest, RegisterRequest
from app.services.auth_service import UserProfileService, authenticate_with_password, create_access_token, get_current_user, get_session_user, register_with_password, sync_current_user_profile
from app.services.email_account_service import EmailAccountService
from app.services.email_delivery import EmailDeliveryError, email_delivery_configured

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _auth_response(user: AuthenticatedUser) -> AuthResponse:
    return AuthResponse(
        access_token=create_access_token(user),
        user=CurrentUserResponse.model_validate(user.model_dump()),
    )


@router.post("/register", response_model=AuthResponse, status_code=201)
def register(data: RegisterRequest) -> AuthResponse:
    if not email_delivery_configured():
        raise HTTPException(status_code=503, detail="New registration is temporarily unavailable because email verification is offline.")
    return _auth_response(register_with_password(data.name, str(data.email), data.password))


@router.post("/login", response_model=AuthResponse)
def login(data: LoginRequest) -> AuthResponse:
    return _auth_response(authenticate_with_password(str(data.email), data.password))


@router.get("/me", response_model=CurrentUserResponse)
def get_authenticated_user(current_user: AuthenticatedUser = Depends(get_session_user)) -> dict[str, object]:
    return sync_current_user_profile(current_user)


@router.patch("/me", response_model=CurrentUserResponse)
def update_profile(data: ProfileUpdateRequest, current_user: AuthenticatedUser = Depends(get_current_user)):
    try:
        return UserProfileService().update_profile(current_user, data.model_dump(exclude_none=True))
    except GoogleAPIError as exc:
        raise HTTPException(status_code=503, detail="User profile service is not available.") from exc


@router.post("/password", status_code=204)
def change_password(data: PasswordChangeRequest, current_user: AuthenticatedUser = Depends(get_current_user)) -> Response:
    try:
        UserProfileService().change_password(current_user, data.current_password.get_secret_value(), data.new_password.get_secret_value())
    except GoogleAPIError as exc:
        raise HTTPException(status_code=503, detail="Password changes are temporarily unavailable.") from exc
    return Response(status_code=204)


@router.post("/email/send", status_code=204)
def send_verification_email(user: AuthenticatedUser = Depends(get_session_user)) -> Response:
    try:
        EmailAccountService().send_verification(user)
    except (FirebaseInitializationError, GoogleAPIError, EmailDeliveryError) as exc:
        raise HTTPException(status_code=503, detail="Could not send a verification email. Try again in a minute.") from exc
    return Response(status_code=204)


@router.post("/email/verify", response_model=CurrentUserResponse)
def verify_email(data: EmailVerificationRequest, user: AuthenticatedUser = Depends(get_session_user)) -> dict:
    try:
        return EmailAccountService().verify(user, data.code)
    except (FirebaseInitializationError, GoogleAPIError) as exc:
        raise HTTPException(status_code=503, detail="Email verification is temporarily unavailable.") from exc


@router.patch("/email/alerts", response_model=CurrentUserResponse)
def update_email_alerts(data: EmailAlertsRequest, user: AuthenticatedUser = Depends(get_session_user)) -> dict:
    try:
        return EmailAccountService().set_email_alerts(user, data.enabled)
    except GoogleAPIError as exc:
        raise HTTPException(status_code=503, detail="Email alert preferences are temporarily unavailable.") from exc
