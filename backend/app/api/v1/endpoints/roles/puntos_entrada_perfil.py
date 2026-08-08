from fastapi import APIRouter, Depends, Response, HTTPException
from pydantic import BaseModel
from app.core.security import UserContext
from app.api.deps import get_current_user
from app.api.v1.dependencias import obtener_caso_uso_obtener_perfil
from app.aplicacion.clinica.gestionar_perfil_usuario import CasoUsoObtenerPerfilUsuario
from app.domain.modelos.usuario import PerfilUsuario

router = APIRouter(prefix="/perfil", tags=["Perfil"])

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


class CambiarRolRequest(BaseModel):
    id_rol: int

@router.post("/cambiar-rol")
def cambiar_rol_activo(
    payload: CambiarRolRequest,
    usuario_actual: UserContext = Depends(get_current_user),
):
    """
    Permite al usuario cambiar su rol activo si tiene los permisos asignados.
    """
    from app.infraestructura.database.db import db_cursor
    from app.infraestructura.supabase.client import get_supabase_admin_client
    
    auth_user_id = usuario_actual.user_id
    id_rol = payload.id_rol
    
    with db_cursor() as cur:
        # Obtener el ID interno del usuario
        cur.execute("select id from usuarios.usuario where auth_user_id::text = %s", (auth_user_id,))
        user_row = cur.fetchone()
        if not user_row:
            raise HTTPException(status_code=404, detail="Usuario no registrado en la base de datos.")
        internal_user_id = user_row[0]
        
        # 1. Verificar si el usuario posee el rol solicitado en usuarios.usuario_rol
        cur.execute(
            "select 1 from usuarios.usuario_rol where id_usuario = %s and id_rol = %s",
            (internal_user_id, id_rol)
        )
        if not cur.fetchone():
            raise HTTPException(status_code=403, detail="No tiene permisos para este rol.")
            
        # 2. Actualizar el rol activo en usuarios.usuario
        cur.execute(
            "update usuarios.usuario set id_rol = %s where id = %s",
            (id_rol, internal_user_id)
        )
        
        # 3. Obtener el nombre y código del rol
        cur.execute("select nombre from usuarios.rol where id = %s", (id_rol,))
        rol_nombre = cur.fetchone()[0]
        
        # Traducir nombre del rol a código para Supabase Auth
        nombre_lower = rol_nombre.lower().strip()
        if "admin" in nombre_lower:
            rol_codigo = "admin"
        elif "médico" in nombre_lower or "medico" in nombre_lower:
            rol_codigo = "medico"
        elif "nutricionista" in nombre_lower:
            rol_codigo = "nutricionista"
        else:
            rol_codigo = "tutor"
            
    # 4. Actualizar Supabase Auth Metadata para el usuario
    admin_client = get_supabase_admin_client()
    try:
        admin_client.auth.admin.update_user_by_id(
            auth_user_id,
            {
                "user_metadata": {
                    "role": rol_codigo
                },
                "app_metadata": {
                    "role": rol_codigo
                }
            }
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Error actualizando metadatos de sesión en Supabase: {exc}"
        )
        
    return {"success": True, "rol_codigo": rol_codigo, "rol_nombre": rol_nombre}

