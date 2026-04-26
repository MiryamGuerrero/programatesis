from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from app.api.deps import require_roles, UserContext
from app.api.v1.use_cases import obtener_caso_uso_gestionar_usuarios, obtener_caso_uso_gestionar_catalogos
from app.aplicacion.clinica.gestionar_usuarios import CasoUsoGestionarUsuarios
from app.aplicacion.clinica.gestionar_catalogos import CasoUsoGestionarCatalogos
from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres

router = APIRouter(tags=["Administrador"])

class CreateUserRequest(BaseModel):
    email: str
    nombre_completo: str
    id_rol: int = Field(gt=0)
    password: str
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None

class UpdateUserRequest(BaseModel):
    email: Optional[str] = None
    nombre_completo: Optional[str] = None
    id_rol: Optional[int] = None
    activo: Optional[bool] = None
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None

@router.get("/usuarios")
def listar_usuarios(
    caso_uso: CasoUsoGestionarUsuarios = Depends(obtener_caso_uso_gestionar_usuarios),
    _=Depends(require_roles("admin"))
) -> List[dict[str, Any]]:
    return caso_uso.listar_todos()

@router.post("/usuarios")
def registrar_usuario(
    payload: CreateUserRequest,
    caso_uso: CasoUsoGestionarUsuarios = Depends(obtener_caso_uso_gestionar_usuarios),
    _=Depends(require_roles("admin"))
) -> dict[str, Any]:
    try:
        id_usuario = caso_uso.registrar_usuario(payload.model_dump())
        return {"id": id_usuario, "message": "Usuario registrado con éxito"}
    except Exception as exc:
        print(f"DEBUG: Error al registrar usuario: {str(exc)}")
        # Devolvemos el error real para diagnóstico
        raise HTTPException(status_code=400, detail=f"No se pudo crear el usuario: {str(exc)}")

@router.put("/usuarios/{user_id}")
@router.put("/crud/users/{user_id}") # Alias para compatibilidad con frontend antiguo
def actualizar_usuario(
    user_id: str,
    payload: UpdateUserRequest,
    _=Depends(require_roles("admin"))
):
    """Actualiza un usuario (Resuelve el 404 del PUT)."""
    repo = RepositorioPerfilPostgres()
    exito = repo.actualizar_usuario(user_id, payload.model_dump(exclude_none=True))
    if not exito:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"id": user_id, "updated": True}

@router.get("/crud/catalog")
def obtener_catalogo_maestro(
    schema: str = Query(...),
    table: str = Query(...),
    caso_uso: CasoUsoGestionarCatalogos = Depends(obtener_caso_uso_gestionar_catalogos),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    try:
        return caso_uso.obtener_maestro(schema, table)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
