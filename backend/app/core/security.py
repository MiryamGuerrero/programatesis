from dataclasses import dataclass

import httpx
from fastapi import HTTPException, status
from jose import JWTError, jwt

from app.core.config import get_settings


@dataclass
class UserContext:
    user_id: str
    role: str
    email: str | None


def _verify_token_with_supabase_auth(token: str) -> dict:
    settings = get_settings()
    if not settings.supabase_url:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="SUPABASE_URL is not configured",
        )

    api_key = settings.supabase_anon_key or settings.supabase_service_role_key
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY is required",
        )

    url = f"{settings.supabase_url.rstrip('/')}/auth/v1/user"
    try:
        response = httpx.get(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "apikey": api_key,
            },
            timeout=10.0,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Auth provider is unavailable",
        ) from exc

    if response.status_code != status.HTTP_200_OK:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    payload = response.json()
    app_meta = payload.get("app_metadata") or {}
    return {
        "sub": payload.get("id"),
        "email": payload.get("email"),
        "app_metadata": app_meta,
        "role": app_meta.get("role") or payload.get("role"),
    }


def decode_supabase_token(token: str) -> dict:
    settings = get_settings()
    if settings.supabase_jwt_secret:
        try:
            return jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
        except JWTError:
            # New Supabase projects issue asymmetric JWTs; fallback to Auth API validation.
            pass

    return _verify_token_with_supabase_auth(token)


def build_user_context(claims: dict) -> UserContext:
    app_meta = claims.get("app_metadata") or {}
    role = app_meta.get("role") or claims.get("role") or "tutor"
    user_id = claims.get("sub")
    email = claims.get("email")

    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing sub claim")

    return UserContext(user_id=user_id, role=role, email=email)


def assert_allowed_role(user: UserContext, allowed_roles: set[str]) -> None:
    if user.role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Role '{user.role}' not allowed for this resource",
        )
