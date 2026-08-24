from __future__ import annotations
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.api.deps import require_roles
from app.api.v1.dependencias import obtener_caso_uso_gestionar_ingredientes, obtener_caso_uso_gestionar_variables
from app.aplicacion.nutricion.gestionar_ingredientes import CasoUsoGestionarIngredientes
from app.aplicacion.nutricion.gestionar_variables import CasoUsoGestionarVariables
from app.core.security import UserContext
from app.infraestructura.database.db import db_cursor
from app.api.v1.simple_cache import cached

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

@router.get("/subgrupos/catalogo-simple")
def list_subgroups_simple_catalog(
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> list[dict[str, Any]]:
    with db_cursor() as cur:
        cur.execute("select id, nombre from nutricion.subgrupo_alimentario order by nombre")
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

@router.get("/ingredientes/catalogo-simple")
def list_ingredients_simple_catalog(
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> list[dict[str, Any]]:
    from app.infraestructura.repositorios.repositorio_ingrediente import RepositorioIngredientePostgres
    repo = RepositorioIngredientePostgres()
    return repo.buscar_ingredientes_filtrados(id_paciente=None, limite=1000)

@router.post("/ingredientes")
def create_ingredient_admin(
    payload: dict,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        id_ingrediente = caso_uso.crear_ingrediente(payload)
        return {"id": id_ingrediente, "message": "Ingrediente creado con éxito"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/ingredientes/{id_ingrediente}")
def update_ingredient_admin(
    id_ingrediente: int,
    payload: dict,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        exito = caso_uso.actualizar_ingrediente(id_ingrediente, payload)
        if not exito:
            raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
        return {"success": True, "message": "Ingrediente actualizado con éxito"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/ingredientes/{id_ingrediente}")
def delete_ingredient_admin(
    id_ingrediente: int,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        from app.infraestructura.repositorios.repositorio_ingrediente import RepositorioIngredientePostgres
        repo = RepositorioIngredientePostgres()
        exito = repo.eliminar_ingrediente(id_ingrediente)
        if not exito:
            raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
        return {"success": True, "message": "Ingrediente eliminado con éxito"}
    except HTTPException:
        raise
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
    limit: int = Query(default=10, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    include_total: bool = Query(default=False),
    _=Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any] | list[dict[str, Any]]:
    with db_cursor() as cur:
        # Base query
        sql_base = "from nutricion.etiqueta_nutricional e"
        where_clause = ""
        params: list[Any] = []
        
        if q and q.strip():
            where_clause = " where e.nombre_visible ilike %s"
            params.append(f"%{q.strip()}%")

        # 1. Total count if requested
        total = 0
        if include_total:
            cur.execute(f"select count(*) {sql_base} {where_clause}", tuple(params))
            total = cur.fetchone()[0]

        # 2. Main query
        sql = f"""
            select 
                e.id, 
                e.nombre_visible, 
                e.codigo, 
                e.descripcion, 
                e.created_at,
                (
                    select string_agg(i.nombre, ', ')
                    from (
                        select i2.nombre
                        from nutricion.ingrediente_etiqueta ie
                        join nutricion.ingrediente i2 on i2.id = ie.id_ingrediente
                        where ie.id_etiqueta = e.id
                        order by i2.nombre
                        limit 5
                    ) i
                ) as ingredientes
            {sql_base}
            {where_clause}
            order by e.created_at desc limit %s offset %s
        """
        cur.execute(sql, tuple(params + [limit, offset]))
        cols = [desc[0] for desc in cur.description]
        items = [dict(zip(cols, row)) for row in cur.fetchall()]

        if include_total:
            return {"items": items, "total": total}
        return items

@router.post("/etiquetas")
def upsert_label_catalog(
    payload: LabelCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        # Check if it already exists by name
        cur.execute("select id from nutricion.etiqueta_nutricional where nombre_visible ilike %s", (payload.nombre_visible,))
        row = cur.fetchone()
        if row:
            # Update existing
            id_etiqueta = row[0]
            cur.execute(
                """
                update nutricion.etiqueta_nutricional 
                set descripcion = %s
                where id = %s
                """,
                (payload.descripcion, id_etiqueta)
            )
            return {"id": id_etiqueta}
        else:
            # Insert new
            cur.execute(
                """
                insert into nutricion.etiqueta_nutricional (nombre_visible, descripcion) 
                values (%s, %s)
                returning id
                """,
                (payload.nombre_visible, payload.descripcion),
            )
            return {"id": cur.fetchone()[0]}

@router.put("/etiquetas/{id_etiqueta}")
def update_label_catalog(
    id_etiqueta: int,
    payload: LabelCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            update nutricion.etiqueta_nutricional 
            set nombre_visible = %s, descripcion = %s
            where id = %s
            """,
            (payload.nombre_visible, payload.descripcion, id_etiqueta),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Etiqueta no encontrada")
        return {"success": True}

@router.delete("/etiquetas/{id_etiqueta}")
def delete_label_catalog(
    id_etiqueta: int,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        # Prevent deletion if in use
        cur.execute("select count(*) from nutricion.ingrediente_etiqueta where id_etiqueta = %s", (id_etiqueta,))
        if cur.fetchone()[0] > 0:
            raise HTTPException(status_code=400, detail="La etiqueta está en uso por ingredientes")
            
        cur.execute("select count(*) from nutricion.receta_etiqueta where id_etiqueta = %s", (id_etiqueta,))
        if cur.fetchone()[0] > 0:
            raise HTTPException(status_code=400, detail="La etiqueta está en uso por recetas")

        cur.execute("delete from nutricion.etiqueta_nutricional where id = %s", (id_etiqueta,))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Etiqueta no encontrada")
        return {"success": True}

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
    try:
        exito = repo.eliminar_momento(mid)
        if not exito:
            raise HTTPException(status_code=404, detail="Momento de comida no encontrado")
        return {"success": True}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

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
    try:
        tid = repo.crear_tipo_plato(payload.get("nombre", ""))
        return {"id": tid, "success": True}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/tipos-plato/{tid}")
def update_dish_type(
    tid: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    try:
        exito = repo.actualizar_tipo_plato(tid, payload.get("nombre", ""))
        if not exito:
            raise HTTPException(status_code=404, detail="Tipo de plato no encontrado")
        return {"success": True}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/tipos-plato/{tid}")
def delete_dish_type(
    tid: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    try:
        exito = repo.eliminar_tipo_plato(tid)
        if not exito:
            raise HTTPException(status_code=404, detail="Tipo de plato no encontrado")
        return {"success": True}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

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
        raise HTTPException(status_code=404, detail="Momento de comida no encontrado")
    return res

@router.post("/reglas-generales")
def upsert_general_rule(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    rid = repo.crear_regla_general(payload)
    return {"id": rid, "success": True}

@router.delete("/reglas-generales")
def clear_general_composition_rules(
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return {"success": True, **repo.limpiar_reglas_composicion()}

@router.post("/reglas-generales/detalle")
def save_rule_detail(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    did = repo.crear_tipo_permitido(payload)
    return {"id": did, "success": True}

@router.post("/reglas-generales/por-momento/{mid}/importar-combinaciones")
def import_rule_combinations_by_moment(
    mid: int,
    payload: Any,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    try:
        combinaciones = payload.get("combinaciones") if isinstance(payload, dict) else payload
        if not isinstance(combinaciones, list):
            raise ValueError("El JSON debe incluir una lista llamada combinaciones")
        return {"success": True, **repo.importar_combinaciones_momento(mid, combinaciones)}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/reglas-generales/detalle/{did}")
def delete_rule_detail(
    did: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    exito = repo.eliminar_tipo_permitido(did)
    return {"success": exito}

# --- REGLAS INTELIGENTES DE COMBINACION POR CONDICIONES NUTRICIONALES ---

ROLES_COMBINACION_UI = [
    {"valor": "COMBINACION_LIGERA", "etiqueta": "Ligera", "icono": "feather", "color": "#4CAF50"},
    {"valor": "COMBINACION_EQUILIBRADA", "etiqueta": "Equilibrada", "icono": "balance", "color": "#2196F3"},
    {"valor": "COMBINACION_ENERGETICA", "etiqueta": "Energetica", "icono": "bolt", "color": "#FF9800"},
    {"valor": "COMBINACION_RECUPERACION_NUTRICIONAL", "etiqueta": "Recuperacion nutricional", "icono": "heart", "color": "#9C27B0"},
    {"valor": "COMBINACION_SUAVE", "etiqueta": "Suave", "icono": "cloud", "color": "#00BCD4"},
    {"valor": "COMBINACION_COMPLEMENTARIA", "etiqueta": "Complementaria", "icono": "add", "color": "#607D8B"},
]

@router.get("/roles-combinacion")
def list_combination_roles(
    _=Depends(require_roles("admin", "nutricionista")),
):
    return ROLES_COMBINACION_UI

@router.get("/configuracion-maestra-menu")
def obtener_configuracion_maestra_menu(
    id_momento_inicial: int = Query(default=None),
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.obtener_configuracion_maestra(id_momento_inicial)

@router.get("/reglas-menu-combinaciones")
@cached(ttl=30)
def list_all_menu_combination_rules(
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.listar_todas_reglas_menu_combinacion()

@router.get("/reglas-menu-combinaciones/por-momento/{mid}")
def list_menu_combination_rules(
    mid: int,
    limit: int = Query(default=12, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    include_total: bool = Query(default=True),
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.listar_reglas_menu_combinacion(
        mid,
        limite=limit,
        offset=offset,
    )

@router.get("/tipos-factibles/por-momento/{mid}")
def list_feasible_dish_types_by_moment(
    mid: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return repo.listar_tipos_factibles_por_momento(mid)

@router.post("/reglas-menu-combinaciones/por-momento/{mid}/importar-json")
def import_menu_combination_rules(
    mid: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    try:
        combinaciones = payload.get("combinaciones") if isinstance(payload, dict) else payload
        return {
            "success": True,
            **repo.importar_reglas_menu_combinacion(mid, combinaciones),
        }
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/reglas-menu-combinaciones")
def create_menu_combination_rule(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    try:
        resultado = repo.crear_regla_menu_combinacion(
            id_momento=int(payload["id_momento"]),
            rol=payload["rol"],
            platillos_nombres=payload.get("platillos", []),
            condiciones_ids=payload.get("condiciones_ids", []),
        )
        return {"success": True, **resultado}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/reglas-menu-combinaciones/{rid}")
def delete_menu_combination_rule(
    rid: int,
    _=Depends(require_roles("admin", "nutricionista")),
):
    repo = RepositorioComposicionPostgres()
    return {"success": repo.eliminar_regla_menu_combinacion(rid)}
