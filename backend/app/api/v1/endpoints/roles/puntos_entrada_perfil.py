from fastapi import APIRouter, Depends, Response
from app.core.security import UserContext
from app.api.deps import get_current_user
from app.api.v1.use_cases import obtener_caso_uso_obtener_perfil
from app.aplicacion.clinica.gestionar_perfil_usuario import CasoUsoObtenerPerfilUsuario
from app.domain.modelos.usuario import PerfilUsuario

router = APIRouter(tags=["Perfil"])

@router.get("/mi-perfil", response_model=PerfilUsuario)
def obtener_mi_perfil(
    response: Response,
    usuario_actual: UserContext = Depends(get_current_user),
    caso_uso: CasoUsoObtenerPerfilUsuario = Depends(obtener_caso_uso_obtener_perfil)
):
    """
    Obtiene los datos del perfil del usuario autenticado para el encabezado.
    Forzamos que no haya cacheo para que los datos cambien inmediatamente al cambiar de cuenta.
    """
    # Evitar cacheo en el navegador y proxies
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    
    return caso_uso.ejecutar(usuario_actual.user_id)

@router.put("/mi-perfil")
def actualizar_mi_perfil(
    datos: dict,
    usuario_actual: UserContext = Depends(get_current_user),
    caso_uso: CasoUsoObtenerPerfilUsuario = Depends(obtener_caso_uso_obtener_perfil)
):
    """
    Actualiza los datos del perfil del usuario autenticado.
    """
    exito = caso_uso.actualizar(usuario_actual.user_id, datos)
    return {"success": exito}
