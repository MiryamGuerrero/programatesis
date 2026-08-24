from collections.abc import Callable

from fastapi import Depends, Header, HTTPException, status

from app.core.security import (
    UserContext,
    assert_allowed_role,
    build_user_context,
    decode_supabase_token,
)


def get_current_user(authorization: str = Header(default="")) -> UserContext:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Bearer token")

    token = authorization.replace("Bearer ", "", 1).strip()
    claims = decode_supabase_token(token)
    return build_user_context(claims)


def require_roles(*roles: str) -> Callable[[UserContext], UserContext]:
    allowed_roles = set(roles)

    def _checker(user: UserContext = Depends(get_current_user)) -> UserContext:
        assert_allowed_role(user, allowed_roles)
        return user

    return _checker
