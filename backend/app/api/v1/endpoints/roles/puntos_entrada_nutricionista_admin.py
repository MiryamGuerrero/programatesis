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
    unidad_base: str | None = "100g"
    parte_comestible_factor: float | None = Field(default=1.0, ge=0, le=1)
    sinonimos: list[str] = Field(default_factory=list)
    etiquetas: list[int] = Field(default_factory=list)
    
    # Composición Nutricional
    energia_kcal: float | None = 0
    agua_g: float | None = 0
    alcohol_g: float | None = 0
    proteinas_g: float | None = 0
    hidratos_carbono_g: float | None = 0
    almidon_g: float | None = 0
    azucares_sencillos_g: float | None = 0
    azucares_libres_g: float | None = 0
    fibra_vegetal_g: float | None = 0
    grasa_total_g: float | None = 0
    ags_g: float | None = 0
    agm_g: float | None = 0
    agp_g: float | None = 0
    colesterol_mg: float | None = 0
    vitamina_a_eq_retinol_ug: float | None = 0
    retinol_ug: float | None = 0
    carotenoides_eq_beta_caroteno_ug: float | None = 0
    vit_d_ug: float | None = 0
    vit_e_eq_alpha_tocoferol_mg: float | None = 0
    vit_k_ug: float | None = 0
    vitamina_b1_mg: float | None = 0
    vitamina_b2_mg: float | None = 0
    eq_niacina_mg: float | None = 0
    vit_b6_mg: float | None = 0
    eq_folato_dietetico_ug: float | None = 0
    vit_b12_ug: float | None = 0
    pantotenico_mg: float | None = 0
    biotina_ug: float | None = 0
    vit_c_mg: float | None = 0
    calcio_mg: float | None = 0
    fosforo_mg: float | None = 0
    hierro_mg: float | None = 0
    iodo_ug: float | None = 0
    cinc_mg: float | None = 0
    magnesio_mg: float | None = 0
    sodio_mg: float | None = 0
    potasio_mg: float | None = 0
    manganeso_mg: float | None = 0
    cobre_mg: float | None = 0
    selenio_ug: float | None = 0
    omega3_g: float | None = 0
    tipo_omega3: str | None = None
    grasas_trans_g: float | None = 0
    polifenoles_mg: float | None = 0
    probioticos_billones_ufc: float | None = 0

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

@router.put("/ingredientes/{id_ingrediente}")
def update_ingredient_admin(
    id_ingrediente: int,
    payload: IngredientCreateRequest,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        exito = caso_uso.actualizar_ingrediente(id_ingrediente, payload.model_dump())
        return {"success": exito, "message": "Ingrediente actualizado con éxito"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/ingredientes/{id_ingrediente}")
def delete_ingredient_admin(
    id_ingrediente: int,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    try:
        exito = caso_uso.eliminar_ingrediente(id_ingrediente)
        return {"success": exito, "message": "Ingrediente eliminado con éxito"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

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
        sql = """
            select 
                e.id, 
                e.nombre_visible, 
                e.descripcion, 
                e.created_at,
                (
                    select string_agg(i.nombre, ', ')
                    from nutricion.ingrediente_etiqueta ie
                    join nutricion.ingrediente i on i.id = ie.id_ingrediente
                    where ie.id_etiqueta = e.id
                ) as ingredientes
            from nutricion.etiqueta_nutricional e
        """
        params: list[Any] = []
        if q and q.strip():
            sql += " where e.nombre_visible ilike %s"
            params.append(f"%{q.strip()}%")
        sql += " order by e.created_at desc limit %s"
        params.append(limit)
        cur.execute(sql, tuple(params))
        cols = [desc[0] for desc in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

@router.post("/etiquetas")
def create_label_catalog(
    payload: LabelCreateRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista", "medico")),
) -> dict[str, Any]:
    with db_cursor() as cur:
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
        return {"success": True, "message": "Etiqueta actualizada con éxito"}

@router.delete("/etiquetas/{id_etiqueta}")
def delete_label_catalog(
    id_etiqueta: int,
    user: UserContext = Depends(require_roles("admin", "nutricionista")),
) -> dict[str, Any]:
    with db_cursor() as cur:
        # Eliminar asociaciones primero para evitar violaciones de integridad referencial
        cur.execute("DELETE FROM nutricion.ingrediente_etiqueta WHERE id_etiqueta = %s", (id_etiqueta,))
        cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_etiqueta = %s", (id_etiqueta,))
        cur.execute("UPDATE heuristico.regla SET id_etiqueta = NULL WHERE id_etiqueta = %s", (id_etiqueta,))
        
        cur.execute("DELETE FROM nutricion.etiqueta_nutricional WHERE id = %s", (id_etiqueta,))
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Etiqueta no encontrada")
        return {"success": True, "message": "Etiqueta eliminada con éxito"}

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
