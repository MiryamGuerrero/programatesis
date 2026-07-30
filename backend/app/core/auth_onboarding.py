from secrets import token_urlsafe
from typing import Any
import unicodedata

from app.core.config import get_settings
from app.infraestructura.supabase.client import get_supabase_admin_client

_ROLE_WEB = {"admin", "medico", "nutricionista"}
_ROLE_MOBILE = {"tutor"}


def _clean_role(role_code: str) -> str:
    r = role_code.strip().lower()
    cleaned = ''.join(c for c in unicodedata.normalize('NFD', r) if unicodedata.category(c) != 'Mn')
    if cleaned == "administrador":
        return "admin"
    return cleaned

def _resolve_redirect_url(role_code: str) -> str:
    settings = get_settings()
    role = _clean_role(role_code)

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
    normalized_role = _clean_role(role_code)
    redirect_url = _resolve_redirect_url(normalized_role)

    admin_client = get_supabase_admin_client()

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
        # Usamos generate_link con type="recovery" en vez de reset_password_for_email
        # del cliente público. Esto garantiza:
        # 1. El token tendrá type=recovery en el link (necesario para PKCE en Flutter).
        # 2. El redirect_to se inyecta correctamente en el link generado.
        # 3. No está sujeto a los rate limits del cliente público.
        # 4. El correo se envía automáticamente vía la API admin de Supabase.
        admin_client.auth.admin.generate_link(
            {
                "type": "recovery",
                "email": normalized_email,
                "options": {
                    "redirect_to": redirect_url,
                },
            }
        )
    except Exception as exc:
        # Si el envío de correo falla, no bloqueamos el flujo ya que el usuario
        # ya fue creado. El admin puede reenviar el correo manualmente.
        import logging
        logging.warning(f"Advertencia: No se pudo enviar el correo de recuperacion a {normalized_email}: {exc}")

    return str(user_id), temp_password


def delete_auth_user(auth_user_id: Any) -> None:
    admin_client = get_supabase_admin_client()
    # Aseguramos que sea string para evitar fallos en la librería GoTrue
    admin_client.auth.admin.delete_user(str(auth_user_id))
