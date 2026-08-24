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

# Alias para compatibilidad con frontend antiguo que busca /auth-context
@router.get("/auth-context")
@cached(ttl=5)
def auth_context_compat(user: UserContext = Depends(get_current_user)):
    repo = RepositorioPerfilPostgres()
    perfil = repo.obtener_perfil_usuario(user.user_id)
    return perfil or {"id": user.user_id, "email": user.email, "rol": "tutor"}
