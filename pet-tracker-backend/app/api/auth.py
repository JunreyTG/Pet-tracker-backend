from fastapi import APIRouter, Depends

from app.models.auth import AuthenticatedUser, CurrentUserResponse
from app.services.auth_service import get_current_user, sync_current_user_profile

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.get("/me", response_model=CurrentUserResponse)
def get_authenticated_user(current_user: AuthenticatedUser = Depends(get_current_user)) -> dict[str, object]:
    return sync_current_user_profile(current_user)
