from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from app.api.deps import require_roles, UserContext
from app.api.v1.dependencias import obtener_caso_uso_gestionar_usuarios, obtener_caso_uso_gestionar_catalogos
from app.aplicacion.clinica.gestionar_usuarios import CasoUsoGestionarUsuarios
from app.aplicacion.clinica.gestionar_catalogos import CasoUsoGestionarCatalogos
from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
from app.api.v1.simple_cache import cached

router = APIRouter(tags=["Administrador"])

class CreateUserRequest(BaseModel):
    email: str
    nombre_completo: str
    id_rol: int = Field(gt=0)
    password: str
    username: Optional[str] = None
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None

class UpdateUserRequest(BaseModel):
    email: Optional[str] = None
    nombre_completo: Optional[str] = None
    username: Optional[str] = None
    id_rol: Optional[int] = None
    activo: Optional[bool] = None
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None

@router.get("/usuarios")
@cached(ttl=15)
def listar_usuarios(
    q: Optional[str] = Query(default=None),
    rol_ids: Optional[List[int]] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    include_total: bool = Query(default=False),
    caso_uso: CasoUsoGestionarUsuarios = Depends(obtener_caso_uso_gestionar_usuarios),
    _=Depends(require_roles("admin"))
) -> dict[str, Any] | List[dict[str, Any]]:
    if q or rol_ids or limit != 10 or offset != 0 or include_total:
        repo = RepositorioPerfilPostgres()
        return repo.listar_usuarios_paginado(
            q=q, 
            rol_ids=rol_ids, 
            limit=limit, 
            offset=offset, 
            include_total=include_total
        )
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
        raise HTTPException(status_code=400, detail=f"No se pudo crear el usuario: {str(exc)}")

@router.put("/usuarios/{user_id}")
@router.put("/crud/users/{user_id}")
def actualizar_usuario(
    user_id: str,
    payload: UpdateUserRequest,
    _=Depends(require_roles("admin"))
):
    repo = RepositorioPerfilPostgres()
    exito = repo.actualizar_usuario(user_id, payload.model_dump(exclude_none=True))
    if not exito:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"id": user_id, "updated": True}

# --- ENDPOINTS GESTIÓN DE ROLES (ADMIN) ---

@router.get("/roles")
def listar_roles_admin(
    _=Depends(require_roles("admin"))
):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute("SELECT id, nombre, descripcion, activo FROM usuarios.rol ORDER BY id")
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

@router.post("/roles")
def crear_rol_admin(
    payload: dict,
    _=Depends(require_roles("admin"))
):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "INSERT INTO usuarios.rol (nombre, descripcion, activo) VALUES (%s, %s, %s) RETURNING id",
            (payload["nombre"], payload.get("descripcion"), payload.get("activo", True))
        )
        return {"id": cur.fetchone()[0], "success": True}


@router.put("/roles/{rid}")
def actualizar_rol_admin(
    rid: int,
    payload: dict,
    _=Depends(require_roles("admin"))
):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "UPDATE usuarios.rol SET nombre = %s, descripcion = %s, activo = %s WHERE id = %s",
            (payload["nombre"], payload.get("descripcion"), payload.get("activo", True), rid)
        )
        return {"success": cur.rowcount > 0}

@router.delete("/roles/{rid}")
def eliminar_rol_admin(
    rid: int,
    _=Depends(require_roles("admin"))
):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute("DELETE FROM usuarios.rol WHERE id = %s", (rid,))
        return {"success": cur.rowcount > 0}

@router.get("/maintenance/clean-neutro")
def clean_neutro_action(
    _=Depends(require_roles("admin"))
):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute("DELETE FROM heuristico.catalogo_accion WHERE nombre ILIKE 'neutro'")
        return {"deleted_rows": cur.rowcount, "success": True}

@router.get("/crud/catalog")
@cached(ttl=30)
def obtener_catalogo_maestro(
    schema: str = Query(...),
    table: str = Query(...),
    caso_uso: CasoUsoGestionarCatalogos = Depends(obtener_caso_uso_gestionar_catalogos),
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor"))
):
    try:
        return caso_uso.obtener_maestro(schema, table)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
