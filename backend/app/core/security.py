from dataclasses import dataclass, field
import logging
import threading
import time

import httpx
from fastapi import HTTPException, status
from jose import JWTError, jwt

from app.core.config import get_settings
from app.infraestructura.database.db import db_cursor

logger = logging.getLogger("security")

_TOKEN_CACHE: dict[str, tuple[dict, float]] = {}
_TOKEN_CACHE_LOCK = threading.Lock()


@dataclass
class UserContext:
    user_id: str
    role: str
    email: str | None
    roles: set[str] = field(default_factory=set)


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
        "médico": "medico",
        "nutricionista": "nutricionista",
        "nutritionist": "nutricionista",
        "tutor": "tutor",
    }
    normalized = aliases.get(token)
    if normalized in _KNOWN_ROLES:
        return normalized

    return None


def _get_user_roles_from_db(user_id: str, email: str | None) -> tuple[str | None, set[str]]:
    """
    Obtiene el rol activo (de usuarios.usuario.id_rol) y el conjunto de todos los roles
    asignados (de usuarios.usuario_rol) para el usuario indicado por id, auth_user_id o email.
    """
    sql = """
        select 
            r_act.nombre as active_role,
            coalesce(
                array_agg(r_all.nombre) filter (where r_all.nombre is not null),
                array[]::varchar[]
            ) as assigned_roles
        from usuarios.usuario u
        left join usuarios.rol r_act on r_act.id = u.id_rol
        left join usuarios.usuario_rol ur on ur.id_usuario = u.id
        left join usuarios.rol r_all on r_all.id = ur.id_rol
        where u.id::text = %s 
           or u.auth_user_id::text = %s 
           or (u.email is not null and lower(u.email) = lower(%s))
        group by r_act.nombre
        limit 1
    """
    try:
        with db_cursor() as cur:
            cur.execute(sql, (user_id, user_id, email or ""))
            row = cur.fetchone()
            if row:
                active_role = _normalize_role(str(row[0])) if row[0] else None
                assigned_raw = row[1] or []
                assigned_roles = {_normalize_role(str(r)) for r in assigned_raw if r}
                assigned_roles.discard(None)
                return active_role, assigned_roles
    except Exception:
        pass

    return None, set()


def _get_role_from_user_table(user_id: str, email: str | None) -> str | None:
    active_role, _ = _get_user_roles_from_db(user_id, email)
    return active_role


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


def _cache_token_payload(token: str, payload: dict) -> None:
    try:
        now = time.time()
        exp = None
        if isinstance(payload, dict) and "exp" in payload:
            exp = float(payload["exp"])
        else:
            try:
                unverified = jwt.get_unverified_claims(token)
                exp = float(unverified.get("exp", 0))
            except Exception:
                exp = None

        if exp and exp > now:
            ttl = min(max(exp - now - 15, 30), 300)
        else:
            ttl = 120

        with _TOKEN_CACHE_LOCK:
            if len(_TOKEN_CACHE) > 1000:
                expired_keys = [k for k, (_, exp_time) in _TOKEN_CACHE.items() if exp_time <= now]
                for k in expired_keys:
                    _TOKEN_CACHE.pop(k, None)
                if len(_TOKEN_CACHE) > 1000:
                    _TOKEN_CACHE.clear()
            _TOKEN_CACHE[token] = (payload, now + ttl)
    except Exception:
        pass


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
            trust_env=False,
        )
    except httpx.HTTPError as exc:
        try:
            payload = jwt.get_unverified_claims(token)
        except JWTError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Auth provider is unavailable",
            ) from exc

        app_meta = payload.get("app_metadata") or {}
        return {
            "sub": payload.get("sub"),
            "email": payload.get("email"),
            "app_metadata": app_meta,
            "role": app_meta.get("role") or payload.get("role"),
        }

    if response.status_code == status.HTTP_200_OK:
        payload = response.json()
        app_meta = payload.get("app_metadata") or {}
        return {
            "sub": payload.get("id"),
            "email": payload.get("email"),
            "app_metadata": app_meta,
            "role": app_meta.get("role") or payload.get("role"),
        }

    # Si Supabase nos devuelve 429 (Too Many Requests) o 5xx
    if response.status_code == 429 or response.status_code >= 500:
        logger.warning(
            "Supabase Auth devolvió status %s (%s). Verificando claims del token.",
            response.status_code,
            response.text,
        )
        try:
            payload = jwt.get_unverified_claims(token)
            exp = float(payload.get("exp", 0))
            if exp > time.time():
                app_meta = payload.get("app_metadata") or {}
                return {
                    "sub": payload.get("sub"),
                    "email": payload.get("email"),
                    "app_metadata": app_meta,
                    "role": app_meta.get("role") or payload.get("role"),
                }
        except Exception:
            pass

        if response.status_code == 429:
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Auth rate limit exceeded")
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Auth provider temporarily unavailable")

    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


def decode_supabase_token(token: str) -> dict:
    now = time.time()
    with _TOKEN_CACHE_LOCK:
        cached = _TOKEN_CACHE.get(token)
        if cached:
            payload, expiry = cached
            if now < expiry:
                return payload
            else:
                _TOKEN_CACHE.pop(token, None)

    settings = get_settings()
    if settings.supabase_jwt_secret:
        try:
            payload = jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
            _cache_token_payload(token, payload)
            return payload
        except JWTError:
            # New Supabase projects issue asymmetric JWTs; fallback to Auth API validation.
            pass

    payload = _verify_token_with_supabase_auth(token)
    _cache_token_payload(token, payload)
    return payload


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

    # 1. Consultar rol activo y conjunto de roles asignados desde la base de datos
    active_role_db, db_assigned_roles = _get_user_roles_from_db(user_id, email)

    # 2. Extraer rol presente en las declaraciones del token
    token_role = _normalize_role(
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

    # Prioridad: rol activo en base de datos si existe, luego el del token, o 'tutor' por defecto
    role = active_role_db or token_role or "tutor"

    # Conjunto de todos los roles que el usuario tiene asignados
    all_roles = set(db_assigned_roles)
    if role:
        all_roles.add(role)
    if token_role:
        all_roles.add(token_role)

    return UserContext(user_id=user_id, role=role, email=email, roles=all_roles)


def assert_allowed_role(user: UserContext, allowed_roles: set[str]) -> None:
    # 1. Si el rol activo está explícitamente en los permitidos
    if user.role in allowed_roles:
        return

    # 2. Si el usuario posee asignado cualquiera de los roles permitidos en sus roles múltiples
    if any(r in allowed_roles for r in user.roles):
        return

    # 3. Si el usuario es administrador, tiene acceso a recursos profesionales del sistema
    if "admin" in user.roles:
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=f"Role '{user.role}' not allowed for this resource",
    )
