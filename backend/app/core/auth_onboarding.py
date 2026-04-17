from secrets import token_urlsafe

from app.core.config import get_settings
from app.core.supabase_client import get_supabase_admin_client, get_supabase_public_client

_ROLE_WEB = {"admin", "medico", "nutricionista"}
_ROLE_MOBILE = {"tutor"}


def _resolve_redirect_url(role_code: str) -> str:
    settings = get_settings()
    role = role_code.strip().lower()

    if role in _ROLE_MOBILE:
        target = settings.onboarding_tutor_redirect_url.strip()
        if not target:
            raise RuntimeError("ONBOARDING_TUTOR_REDIRECT_URL must be configured")
        return target

    if role in _ROLE_WEB:
        target = settings.onboarding_web_redirect_url.strip()
        if not target:
            raise RuntimeError("ONBOARDING_WEB_REDIRECT_URL must be configured")
        return target

    raise ValueError(f"Rol no soportado para onboarding: {role_code}")


def provision_auth_user_with_password_setup(
    *,
    email: str,
    nombre_completo: str,
    role_code: str,
) -> str:
    normalized_email = email.strip().lower()
    normalized_role = role_code.strip().lower()
    redirect_url = _resolve_redirect_url(normalized_role)

    admin_client = get_supabase_admin_client()
    public_client = get_supabase_public_client()

    temp_password = token_urlsafe(24)
    user_response = admin_client.auth.admin.create_user(
        {
            "email": normalized_email,
            "password": temp_password,
            "email_confirm": True,
            "user_metadata": {
                "nombre_completo": nombre_completo.strip(),
                "role": normalized_role,
            },
            "app_metadata": {
                "role": normalized_role,
            },
        }
    )

    user = getattr(user_response, "user", None)
    user_id = getattr(user, "id", None)
    if not user_id:
        raise RuntimeError("No fue posible crear el usuario en Supabase Auth")

    try:
        public_client.auth.reset_password_for_email(
            normalized_email,
            {
                "redirect_to": redirect_url,
            },
        )
    except Exception as exc:
        try:
            admin_client.auth.admin.delete_user(user_id)
        except Exception:
            pass
        raise RuntimeError("No fue posible enviar el correo de configuracion de contrasena") from exc

    return str(user_id)


def delete_auth_user(auth_user_id: str) -> None:
    admin_client = get_supabase_admin_client()
    admin_client.auth.admin.delete_user(auth_user_id)
