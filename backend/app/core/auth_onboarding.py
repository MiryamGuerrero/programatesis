from secrets import token_urlsafe
from typing import Any

from app.core.config import get_settings
from app.infraestructura.supabase.client import get_supabase_admin_client, get_supabase_public_client

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
    password: str = None,
) -> tuple[str, str]:
    normalized_email = email.strip().lower()
    normalized_role = role_code.strip().lower()
    redirect_url = _resolve_redirect_url(normalized_role)

    admin_client = get_supabase_admin_client()
    public_client = get_supabase_public_client()

    temp_password = password if password else token_urlsafe(12)
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
        # El usuario ya fue creado arriba. Si el envío de correo de recuperación falla
        # (ej. por límites de Supabase o email inválido), NO borramos al usuario ni bloqueamos
        # el flujo integral, ya que el paciente depende de este registro.
        import logging
        logging.warning(f"Advertencia: No se pudo enviar el correo de recuperacion a {normalized_email}: {exc}")

    return str(user_id), temp_password


def delete_auth_user(auth_user_id: Any) -> None:
    admin_client = get_supabase_admin_client()
    # Aseguramos que sea string para evitar fallos en la librería GoTrue
    admin_client.auth.admin.delete_user(str(auth_user_id))
