from fastapi import APIRouter, Depends, HTTPException
from typing import Optional
from pydantic import BaseModel
from app.api.deps import UserContext, get_current_user
from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
from app.api.v1.simple_cache import cached

router = APIRouter(tags=["Auth"])

class UpdateProfileRequest(BaseModel):
    nombre_completo: Optional[str] = None
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    email: Optional[str] = None

@router.get("/me")
def get_current_user_context(
    user: UserContext = Depends(get_current_user)
):
    """Retorna el contexto del usuario actual. (Ruta profesional)"""
    repo = RepositorioPerfilPostgres()
    perfil = repo.obtener_perfil_usuario(user.user_id)
    
    if not perfil:
        # Fallback: Si no está en nuestra tabla, devolvemos lo que viene del token de Supabase
        return {
            "id": user.user_id,
            "email": user.email,
            "rol": user.role
        }
        
    return perfil

@router.put("/me")
def actualizar_perfil_actual(
    payload: UpdateProfileRequest,
    user: UserContext = Depends(get_current_user)
):
    """Actualiza el perfil del usuario autenticado."""
    repo = RepositorioPerfilPostgres()
    exito = repo.actualizar_usuario(user.user_id, payload.model_dump(exclude_none=True))
    if not exito:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"id": user.user_id, "updated": True}

# Alias para compatibilidad con frontend que busca /auth-context
@router.get("/auth-context")
def auth_context_compat(user: UserContext = Depends(get_current_user)):
    repo = RepositorioPerfilPostgres()
    perfil = repo.obtener_perfil_usuario(user.user_id)
    if not perfil:
        return {"id": user.user_id, "email": user.email, "rol": user.role, "role": user.role}
    perfil["role"] = perfil.get("rol_codigo") or user.role
    return perfil


@router.get("/auth/tutor-redirect")
@router.get("/tutor-redirect")
def tutor_redirect_bridge():
    """Página puente para redirección de configuración de contraseña de tutores.
    
    Cuando Supabase verifica el enlace del correo, redirige aquí vía HTTPS.
    Esta página extrae los tokens o código del hash/query y:
    1. Si la app Android (com.nutrireuma.app) está instalada, la abre directamente.
    2. Si no está instalada, redirige automáticamente a Google Play Store.
    3. Muestra una interfaz institucional limpia y moderna de NutriReuma con botones
       claros de respaldo en caso de que el navegador bloquee la apertura automática.
    """
    html_content = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NutriReuma - Configuración de Contraseña</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Nunito:wght@400;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --azul-oscuro: #1A365D;
      --azul-secundario: #2B6CB0;
      --verde-salud: #2E7D32;
      --verde-claro: #E8F5E9;
      --fondo: #F0F4F8;
      --blanco: #FFFFFF;
      --gris-texto: #4A5568;
      --gris-suave: #718096;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: 'Nunito', sans-serif;
      background: linear-gradient(135deg, #E2E8F0 0%, #EDF2F7 50%, #EBF8FF 100%);
      color: var(--gris-texto);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: var(--blanco);
      max-width: 440px;
      width: 100%;
      border-radius: 24px;
      padding: 36px 28px;
      box-shadow: 0 20px 40px -15px rgba(26, 54, 93, 0.15), 0 0 1px 1px rgba(0, 0, 0, 0.04);
      text-align: center;
      position: relative;
      overflow: hidden;
    }
    .card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 6px;
      background: linear-gradient(90deg, var(--azul-oscuro), var(--verde-salud));
    }
    .icon-container {
      width: 80px;
      height: 80px;
      margin: 0 auto 20px;
      background: var(--verde-claro);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      position: relative;
    }
    .icon-container svg {
      width: 42px;
      height: 42px;
      fill: var(--verde-salud);
    }
    .spinner {
      position: absolute;
      top: -4px;
      left: -4px;
      right: -4px;
      bottom: -4px;
      border: 3px solid transparent;
      border-top-color: var(--verde-salud);
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    h1 {
      font-family: 'Montserrat', sans-serif;
      font-size: 22px;
      font-weight: 800;
      color: var(--azul-oscuro);
      margin-bottom: 8px;
    }
    p.subtitle {
      font-size: 15px;
      color: var(--gris-suave);
      line-height: 1.5;
      margin-bottom: 24px;
    }
    .status-badge {
      background: #F7FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 12px 16px;
      margin-bottom: 24px;
      font-size: 14px;
      color: var(--azul-oscuro);
      font-weight: 600;
    }
    .actions {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 14px 20px;
      border-radius: 14px;
      font-weight: 700;
      font-size: 15px;
      text-decoration: none;
      transition: all 0.2s ease;
      cursor: pointer;
      border: none;
    }
    .btn-primary {
      background: var(--azul-oscuro);
      color: var(--blanco);
      box-shadow: 0 4px 12px rgba(26, 54, 93, 0.25);
    }
    .btn-primary:hover {
      background: #102a45;
      transform: translateY(-1px);
    }
    .btn-secondary {
      background: #EDF2F7;
      color: var(--azul-oscuro);
    }
    .btn-secondary:hover {
      background: #E2E8F0;
    }
    .footer-note {
      margin-top: 24px;
      font-size: 12px;
      color: var(--gris-suave);
      line-height: 1.4;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-container">
      <div class="spinner" id="spinner"></div>
      <svg viewBox="0 0 24 24">
        <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/>
      </svg>
    </div>

    <h1>NutriReuma</h1>
    <p class="subtitle">Verificando enlace de activación y redirigiendo a la aplicación móvil...</p>

    <div class="status-badge" id="statusMessage">
      Abriendo NutriReuma en tu teléfono...
    </div>

    <div class="actions">
      <a id="btnOpenApp" href="#" class="btn btn-primary">
        Abrir NutriReuma
      </a>
      <a id="btnPlayStore" href="https://play.google.com/store/apps/details?id=com.nutrireuma.app" class="btn btn-secondary">
        Instalar desde Google Play
      </a>
    </div>

    <p class="footer-note">
      Si la aplicación aún no está instalada, descárgala en Google Play y vuelve a abrir este enlace para definir tu contraseña.
    </p>
  </div>

  <script>
    (function() {
      // 1. Obtener parámetros desde query string o fragment (hash)
      var hash = window.location.hash ? window.location.hash.substring(1) : "";
      var query = window.location.search ? window.location.search.substring(1) : "";
      
      // Combinar los datos (el fragment tiene prioridad para tokens)
      var fullPayload = hash || query;
      var cleanParams = fullPayload.replace(/^\\?/, "").replace(/^#/, "");

      var playStoreUrl = "https://play.google.com/store/apps/details?id=com.nutrireuma.app";
      var customSchemeUrl = "reumanutri://auth/callback";
      if (cleanParams) {
        customSchemeUrl += "?" + cleanParams;
      }

      // Android Intent URI con fallback automático a Google Play
      var intentUrl = "intent://auth/callback" + 
        (cleanParams ? ("?" + cleanParams) : "") + 
        "#Intent;scheme=reumanutri;package=com.nutrireuma.app;S.browser_fallback_url=" + 
        encodeURIComponent(playStoreUrl) + ";end";

      var btnOpen = document.getElementById("btnOpenApp");
      var btnPlay = document.getElementById("btnPlayStore");
      var statusMsg = document.getElementById("statusMessage");

      btnOpen.href = intentUrl;
      btnPlay.href = playStoreUrl;

      // 2. Intentar apertura automática
      var isAndroid = /android/i.test(navigator.userAgent);

      if (isAndroid) {
        // En Android, redirigir al Intent URI activa la app si está instalada,
        // o envía a Google Play si no lo está.
        setTimeout(function() {
          window.location.href = intentUrl;
        }, 150);
      } else {
        // Si se abre en otra plataforma (PC / iOS), dar opción manual
        statusMsg.innerText = "Este enlace está diseñado para abrir la app móvil en tu dispositivo Android.";
      }
    })();
  </script>
</body>
</html>
"""
    from fastapi.responses import HTMLResponse
    return HTMLResponse(content=html_content)

