from fastapi import APIRouter, Depends

from app.models.auth import AuthResponse, AuthenticatedUser, CurrentUserResponse, LoginRequest, RegisterRequest
from app.services.auth_service import authenticate_with_password, create_access_token, get_current_user, register_with_password, sync_current_user_profile

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _auth_response(user: AuthenticatedUser) -> AuthResponse:
    return AuthResponse(
        access_token=create_access_token(user),
        user=CurrentUserResponse(uid=user.uid, email=user.email, display_name=user.display_name),
    )


@router.post("/register", response_model=AuthResponse, status_code=201)
def register(data: RegisterRequest) -> AuthResponse:
    return _auth_response(register_with_password(data.name, str(data.email), data.password))


@router.post("/login", response_model=AuthResponse)
def login(data: LoginRequest) -> AuthResponse:
    return _auth_response(authenticate_with_password(str(data.email), data.password))


@router.get("/me", response_model=CurrentUserResponse)
def get_authenticated_user(current_user: AuthenticatedUser = Depends(get_current_user)) -> dict[str, object]:
    return sync_current_user_profile(current_user)
