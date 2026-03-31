from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.core.security import UserContext

router = APIRouter(tags=["Auth"])


@router.get("/auth-context")
def auth_context(user: UserContext = Depends(get_current_user)) -> dict[str, str | None]:
    return {
        "user_id": user.user_id,
        "email": user.email,
        "role": user.role,
    }
