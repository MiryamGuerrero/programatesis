from __future__ import annotations
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.api.deps import require_roles
from app.api.v1.use_cases import obtener_caso_uso_gestionar_ingredientes, obtener_caso_uso_gestionar_variables
from app.aplicacion.nutricion.gestionar_ingredientes import CasoUsoGestionarIngredientes
from app.aplicacion.nutricion.gestionar_variables import CasoUsoGestionarVariables
from app.core.security import UserContext
from app.core.db import db_cursor

router = APIRouter(prefix="/nutricionista", tags=["Nutricionista Admin"])

# --- DTOs ---

class IngredientCreateRequest(BaseModel):
    nombre: str
    id_grupo_alimentario: int | None = Field(default=None, gt=0)
    id_subgrupo_alimentario: int | None = Field(default=None, gt=0)
    unidad_base: str | None = None
    parte_comestible_factor: float | None = Field(default=None, ge=0, le=1)
    precio_referencia: float | None = Field(default=None, ge=0)
    costo_estimado_por_100g: float | None = Field(default=None, ge=0)
    sinonimos: list[str] = Field(default_factory=list)

class VariableCreateRequest(BaseModel):
    nombre_visible: str
    tipo_dato: str = "numeric"
    categoria_funcional: str | None = None
    unidad: str | None = None
    descripcion: str | None = None

class VariableValueUpsertItem(BaseModel):
    id_ingrediente: int = Field(gt=0)
    variable_id: int
    valor_numerico: float | None = None
    valor_texto: str | None = None
    valor_booleano: bool | None = None

class LabelCreateRequest(BaseModel):
    nombre_visible: str
    descripcion: str | None = None

# --- ENDPOINTS INGREDIENTES ---

@router.post("/ingredientes")
def create_ingredient_admin(
    payload: IngredientCreateRequest,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        id_ingrediente = caso_uso.crear_ingrediente(payload.model_dump())
        return {"id": id_ingrediente, "message": "Ingrediente creado con éxito"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/ingredientes/{id_ingrediente}")
def get_ingredient_detail(
    id_ingrediente: int,
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    from app.infraestructura.repositorios.repositorio_ingrediente import RepositorioIngredientePostgres
    repo = RepositorioIngredientePostgres()
    detalle = repo.obtener_ingrediente(id_ingrediente)
    if not detalle:
        raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    return detalle

# --- ENDPOINTS VARIABLES ---

@router.get("/variables")
def list_variables_catalog(
    q: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=500),
    caso_uso: CasoUsoGestionarVariables = Depends(obtener_caso_uso_gestionar_variables),
    _=Depends(require_roles("admin", "nutricionista")),
) -> list[dict[str, Any]]:
    return caso_uso.listar_variables(q, limit)

# --- ENDPOINTS ETIQUETAS ---

@router.get("/etiquetas")
def list_labels_catalog(
    q: str | None = Query(default=None),
    limit: int = Query(default=300, ge=1, le=1000),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> list[dict[str, Any]]:
    with db_cursor() as cur:
        sql = "select id, nombre_visible, descripcion, created_at from nutricion.etiqueta_nutricional"
        params: list[Any] = []
        if q and q.strip():
            sql += " where nombre_visible ilike %s"
            params.append(f"%{q.strip()}%")
        sql += " order by created_at desc limit %s"
        params.append(limit)
        cur.execute(sql, tuple(params))
        cols = [desc[0] for desc in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

@router.post("/etiquetas")
def upsert_label_catalog(
    payload: LabelCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            insert into nutricion.etiqueta_nutricional (nombre_visible, descripcion, updated_at) 
            values (%s, %s, now())
            on conflict (nombre_visible) do update set descripcion = excluded.descripcion, updated_at = now()
            returning id
            """,
            (payload.nombre_visible, payload.descripcion),
        )
        return {"id": cur.fetchone()[0]}

# --- ENDPOINTS GESTIÓN DE COMPOSICIÓN (MOMENTOS Y TIPOS) ---

from app.infraestructura.repositorios.repositorio_composicion import RepositorioComposicionPostgres

@router.get("/momentos-comida")
def list_meal_moments(
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.listar_momentos()

@router.post("/momentos-comida")
def create_meal_moment(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    mid = repo.crear_momento(payload)
    return {"id": mid, "success": True}

@router.put("/momentos-comida/{mid}")
def update_meal_moment(
    mid: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    exito = repo.actualizar_momento(mid, payload)
    return {"success": exito}

@router.delete("/momentos-comida/{mid}")
def delete_meal_moment(
    mid: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    exito = repo.eliminar_momento(mid)
    return {"success": exito}

@router.get("/tipos-plato")
def list_dish_types(
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.listar_tipos_plato()

@router.post("/tipos-plato")
def create_dish_type(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    tid = repo.crear_tipo_plato(payload["nombre"])
    return {"id": tid, "success": True}

# --- ENDPOINTS REGLAS DE COMPOSICIÓN ---

@router.get("/reglas-generales")
def list_general_composition_rules(
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.listar_reglas_generales()

@router.get("/reglas-generales/por-momento/{mid}")
def get_full_rule_by_moment(
    mid: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    res = repo.obtener_regla_completa_por_momento(mid)
    if not res:
        raise HTTPException(status_code=404, detail="No hay regla definida para este momento")
    return res

@router.post("/reglas-generales")
def upsert_general_rule(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    rid = repo.crear_regla_general(payload)
    return {"id": rid, "success": True}

@router.post("/reglas-generales/detalle")
def save_rule_detail(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    did = repo.crear_tipo_permitido(payload)
    return {"id": did, "success": True}

@router.delete("/reglas-generales/detalle/{did}")
def delete_rule_detail(
    did: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    exito = repo.eliminar_tipo_permitido(did)
    return {"success": exito}
