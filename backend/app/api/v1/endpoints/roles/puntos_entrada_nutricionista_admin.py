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
    codigo_externo: str | None = None
    id_grupo_alimentario: int | None = Field(default=None, gt=0)
    grupo_nombre: str | None = None
    id_subgrupo_alimentario: int | None = Field(default=None, gt=0)
    subgrupo_nombre: str | None = None
    unidad_base: str | None = None
    parte_comestible_factor: float | None = Field(default=None, ge=0, le=1)
    precio_referencia: float | None = Field(default=None, ge=0)
    costo_estimado_por_100g: float | None = Field(default=None, ge=0)
    sinonimos: list[str] = Field(default_factory=list)

class VariableCreateRequest(BaseModel):
    codigo: str
    nombre_visible: str
    tipo_dato: str = "numeric"
    categoria_funcional: str | None = None
    unidad: str | None = None
    descripcion: str | None = None

class VariableValueUpsertItem(BaseModel):
    id_ingrediente: int = Field(gt=0)
    variable_codigo: str
    valor_numerico: float | None = None
    valor_texto: str | None = None
    valor_booleano: bool | None = None

class VariableBulkUpsertRequest(BaseModel):
    items: list[VariableValueUpsertItem] = Field(default_factory=list)

class LabelCreateRequest(BaseModel):
    codigo: str | None = None
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

@router.post("/variables")
def create_or_update_variable_catalog(
    payload: VariableCreateRequest,
    caso_uso: CasoUsoGestionarVariables = Depends(obtener_caso_uso_gestionar_variables),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        var_id = caso_uso.upsert_catalogo_variable(payload.model_dump())
        return {"id": var_id}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/variables/valor-unitario")
def upsert_variable_value_unit(
    payload: VariableValueUpsertItem,
    caso_uso: CasoUsoGestionarVariables = Depends(obtener_caso_uso_gestionar_variables),
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        caso_uso.upsert_valor(payload.model_dump(), user.user_id)
        return {"ok": True}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

# --- ENDPOINTS ETIQUETAS (MANUALES) ---

@router.get("/etiquetas")
def list_labels_catalog(
    q: str | None = Query(default=None),
    limit: int = Query(default=300, ge=1, le=1000),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> list[dict[str, Any]]:
    with db_cursor() as cur:
        sql = """
            select id, codigo, nombre_visible, descripcion, created_at
            from nutricion.etiqueta_nutricional
        """
        params: list[Any] = []
        if q and q.strip():
            sql += " where (codigo ilike %s or nombre_visible ilike %s)"
            search_pattern = f"%{q.strip()}%"
            params.extend([search_pattern, search_pattern])
        
        sql += " order by created_at desc, nombre_visible limit %s"
        params.append(limit)
        
        cur.execute(sql, tuple(params))
        columns = [desc[0] for desc in cur.description]
        return [dict(zip(columns, row)) for row in cur.fetchall()]

@router.post("/etiquetas")
def upsert_label_catalog(
    payload: LabelCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        # Resolvemos si insertamos con código o solo nombre
        if payload.codigo:
            cur.execute(
                """
                insert into nutricion.etiqueta_nutricional (
                    codigo, nombre_visible, descripcion, created_at
                ) values (%s, %s, %s, now())
                on conflict (codigo) do update set
                    nombre_visible = excluded.nombre_visible,
                    descripcion = excluded.descripcion
                returning id
                """,
                (payload.codigo, payload.nombre_visible, payload.descripcion),
            )
        else:
            cur.execute(
                """
                insert into nutricion.etiqueta_nutricional (
                    nombre_visible, descripcion, updated_at
                ) values (%s, %s, now())
                returning id
                """,
                (payload.nombre_visible, payload.descripcion),
            )
        return {"id": cur.fetchone()[0]}

@router.post("/ingredientes/{id_ingrediente}/etiquetas/{id_etiqueta}")
def assign_label_to_ingredient(
    id_ingrediente: int,
    id_etiqueta: int,
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    """Asignación MANUAL de etiqueta a ingrediente."""
    with db_cursor() as cur:
        cur.execute(
            "insert into nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta) values (%s, %s) on conflict do nothing",
            (id_ingrediente, id_etiqueta)
        )
        return {"success": True}

@router.delete("/ingredientes/{id_ingrediente}/etiquetas/{id_etiqueta}")
def remove_label_from_ingredient(
    id_ingrediente: int,
    id_etiqueta: int,
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    """Eliminación MANUAL de etiqueta de ingrediente."""
    with db_cursor() as cur:
        cur.execute(
            "delete from nutricion.ingrediente_etiqueta where id_ingrediente = %s and id_etiqueta = %s",
            (id_ingrediente, id_etiqueta)
        )
        return {"success": True}
