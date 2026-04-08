from dataclasses import dataclass

import httpx
from fastapi import HTTPException, status
from jose import JWTError, jwt

from app.core.config import get_settings
from app.core.db import db_cursor


@dataclass
class UserContext:
    user_id: str
    role: str
    email: str | None


_KNOWN_ROLES = {"admin", "medico", "nutricionista", "tutor"}


def _normalize_role(raw_role: str | None) -> str | None:
    if not raw_role:
        return None

    token = raw_role.strip().lower()
    if token in ("", "authenticated", "anon"):
        return None

    role_by_id = {
        "1": "admin",
        "2": "medico",
        "3": "nutricionista",
        "4": "tutor",
    }
    if token in role_by_id:
        return role_by_id[token]

    aliases = {
        "admin": "admin",
        "administrador": "admin",
        "medico": "medico",
        "nutricionista": "nutricionista",
        "nutritionist": "nutricionista",
        "tutor": "tutor",
    }
    normalized = aliases.get(token)
    if normalized in _KNOWN_ROLES:
        return normalized

    return None


def _get_role_from_user_table(user_id: str, email: str | None) -> str | None:
    sql_by_id = """
        select upper(r.codigo::text)
        from usuarios.usuario u
        inner join usuarios.rol r on r.id = u.id_rol
        where u.id::text = %s
           or u.auth_user_id::text = %s
        limit 1
    """
    sql_by_email = """
        select upper(r.codigo::text)
        from usuarios.usuario u
        inner join usuarios.rol r on r.id = u.id_rol
        where lower(u.email) = lower(%s)
        limit 1
    """

    try:
        with db_cursor() as cur:
            cur.execute(sql_by_id, (user_id, user_id))
            row = cur.fetchone()
            if row and row[0]:
                return _normalize_role(str(row[0]))

            if email:
                cur.execute(sql_by_email, (email,))
                row = cur.fetchone()
                if row and row[0]:
                    return _normalize_role(str(row[0]))
    except Exception:
        return None

    return None


def _is_user_active(user_id: str, email: str | None) -> bool:
    sql_by_id = """
        select activo
        from usuarios.usuario
        where id::text = %s
           or auth_user_id::text = %s
        limit 1
    """
    sql_by_email = """
        select activo
        from usuarios.usuario
        where lower(email) = lower(%s)
        limit 1
    """
    try:
        with db_cursor() as cur:
            cur.execute(sql_by_id, (user_id, user_id))
            row = cur.fetchone()
            if row is not None:
                return bool(row[0])

            if email:
                cur.execute(sql_by_email, (email,))
                row = cur.fetchone()
                if row is not None:
                    return bool(row[0])
    except Exception:
        pass
    return True


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
    user_meta = claims.get("user_metadata")
    if not isinstance(user_meta, dict):
        user_meta = {}

    user_id = claims.get("sub")
    email = claims.get("email")

    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing sub claim")

    if not _is_user_active(user_id, email):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account deactivated")

    role = _normalize_role(
        app_meta.get("role")
        or app_meta.get("rol")
        or app_meta.get("id_rol")
        or claims.get("role")
        or claims.get("rol")
        or claims.get("id_rol")
        or user_meta.get("role")
        or user_meta.get("rol")
        or user_meta.get("id_rol")
    )

    if role is None:
        role = _get_role_from_user_table(user_id=user_id, email=email)

    if role is None:
        role = "tutor"

    return UserContext(user_id=user_id, role=role, email=email)


def assert_allowed_role(user: UserContext, allowed_roles: set[str]) -> None:
    if user.role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Role '{user.role}' not allowed for this resource",
        )
