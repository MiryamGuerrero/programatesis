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

class RoleAsignadoInput(BaseModel):
    id_rol: int
    titulo_profesional: Optional[str] = None
    institucion_titulo: Optional[str] = None

class CreateUserRequest(BaseModel):
    email: str
    nombre_completo: str
    id_rol: Optional[int] = None
    roles_asignados: Optional[List[RoleAsignadoInput]] = None
    password: Optional[str] = None
    username: Optional[str] = None
    cedula: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None

class UpdateUserRequest(BaseModel):
    email: Optional[str] = None
    nombre_completo: Optional[str] = None
    username: Optional[str] = None
    id_rol: Optional[int] = None
    roles_asignados: Optional[List[RoleAsignadoInput]] = None
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
    activo: Optional[bool] = Query(default=None),
    caso_uso: CasoUsoGestionarUsuarios = Depends(obtener_caso_uso_gestionar_usuarios),
    _=Depends(require_roles("admin"))
) -> dict[str, Any] | List[dict[str, Any]]:
    if q or rol_ids or limit != 10 or offset != 0 or include_total or (activo is not None):
        repo = RepositorioPerfilPostgres()
        return repo.listar_usuarios_paginado(
            q=q, 
            rol_ids=rol_ids, 
            limit=limit, 
            offset=offset, 
            include_total=include_total,
            activo=activo
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
    try:
        exito = repo.actualizar_usuario(user_id, payload.model_dump(exclude_none=True))
        if not exito:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        return {"id": user_id, "updated": True}
    except ValueError as val_err:
        raise HTTPException(status_code=400, detail=str(val_err))

@router.delete("/usuarios/{user_id}")
def eliminar_usuario(
    user_id: str,
    _=Depends(require_roles("admin"))
):
    repo = RepositorioPerfilPostgres()
    exito = repo.eliminar_usuario(user_id)
    if not exito:
        raise HTTPException(status_code=404, detail="Usuario no encontrado o no se pudo eliminar")
    return {"id": user_id, "deleted": True}

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

@router.get("/auditoria/controles")
def listar_controles_auditoria(
    q: Optional[str] = Query(default=None),
    activo: Optional[bool] = Query(default=None),
    en_brote: Optional[bool] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    _=Depends(require_roles("admin"))
):
    from app.infraestructura.database.db import db_cursor
    
    where_clauses = []
    params = []
    
    if q and isinstance(q, str) and q.strip():
        where_clauses.append("(p.nombre_completo ilike %s or u.nombre_completo ilike %s)")
        params.extend([f"%{q}%", f"%{q}%"])
        
    if activo is not None and isinstance(activo, bool):
        where_clauses.append("u.activo = %s")
        params.append(activo)
        
    if en_brote is not None and isinstance(en_brote, bool):
        where_clauses.append("cp.en_brote = %s")
        params.append(en_brote)
        
    where_str = f"where {' and '.join(where_clauses)}" if where_clauses else ""
    
    with db_cursor() as cur:
        count_sql = f"""
            select count(*)
            from clinico.control_paciente cp
            join usuarios.paciente p on p.id = cp.id_paciente
            left join usuarios.usuario u on u.id = cp.id_medico
            {where_str}
        """
        cur.execute(count_sql, tuple(params))
        total = cur.fetchone()[0]
        
        items_sql = f"""
            select 
                cp.id::text,
                cp.fecha_control::text,
                p.nombre_completo::text as paciente_nombre,
                u.nombre_completo::text as especialista_nombre,
                u.activo as especialista_activo,
                r.nombre::text as especialista_rol,
                cp.peso_kg,
                cp.talla_cm,
                cp.imc_calculado,
                cp.puntos_dolor,
                cp.escala_inflamacion,
                cp.nivel_fatiga,
                cp.en_brote,
                cp.nota_evolucion::text
            from clinico.control_paciente cp
            join usuarios.paciente p on p.id = cp.id_paciente
            left join usuarios.usuario u on u.id = cp.id_medico
            left join usuarios.rol r on r.id = u.id_rol
            {where_str}
            order by cp.fecha_control desc, cp.id desc
            limit %s offset %s
        """
        cur.execute(items_sql, tuple(params + [limit, offset]))
        cols = [d[0] for d in cur.description]
        items = [dict(zip(cols, row)) for row in cur.fetchall()]
        
        return {"items": items, "total": total}
