from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException
from app.api.deps import require_roles, UserContext
from app.schemas.domain import (
    IngredientesPermitidosRequest, IngredientesPermitidosResponse,
    PlanAutomaticoRequest, PlanAutomaticoResponse,
    PlanManualRequest, PlanManualResponse,
    PreferenciasAprendidasRequest, PreferenciasAprendidasResponse,
    RecetasPermitidasRequest, RecetasPermitidasResponse,
    NutritionalRuleCreate, NutritionalRuleUpdate,
    NutritionalConditionCreate, NutritionalConditionUpdate,
    PatientFullCreate, ClinicalControlCreate
)
from pydantic import BaseModel
from app.repositories.medico_tutor_repository import buscar_pacientes
from app.services.roles.nutricionista.modules.plan_nutricional.patient_profile_service import get_patient_full_profile
from app.repositories.ingredientes_repository import list_ingredients_paged, get_ingredient_detail
from app.repositories.ingredientes_update_repository import update_ingredient_full
from app.repositories.etiquetas_nutricionales_repository import (
    list_etiquetas_catalogo, update_etiqueta_nombre, delete_etiqueta_full
)
from app.repositories.nutritional_rules_repository import (
    list_nutritional_rules, get_nutritional_rule_form_data,
    create_nutritional_rule, update_nutritional_rule, delete_nutritional_rule
)
from app.repositories.nutritional_conditions_repository import (
    list_nutritional_conditions, create_nutritional_condition,
    update_nutritional_condition, delete_nutritional_condition_safe
)
from app.repositories.paciente_gestion_repository import (
    registrar_paciente_full, registrar_control_clinico, 
    eliminar_paciente_full, buscar_pacientes_gestion,
    get_patient_management_catalogs, buscar_tutor_por_cedula
)
from app.repositories.paciente_expediente_repository import (
    obtener_expediente_paciente, guardar_alergias_y_temporales_full
)
from app.services.roles.nutricionista.modules.ingredientes.ingredient_permission_service import get_patient_ingredient_permissions
from app.services.roles.nutricionista.modules.plan_nutricional.manual_plan_service import save_manual_plan
from app.services.roles.nutricionista.modules.plan_nutricional.nutrition_plan_service import generate_automatic_plan
from app.services.roles.nutricionista.modules.preferencias.preference_learning_service import learn_preferences
from app.services.roles.nutricionista.modules.recetas.allowed_recipe_service import get_recetas_permitidas

router = APIRouter(tags=["Nutricionista"])

class TemporaryConditionItem(BaseModel):
    id: int
    fecha_fin: date

class AllergiesUpdateRequest(BaseModel):
    ingredientes: list[int]
    grupos: list[int]
    temporales: list[TemporaryConditionItem]

# --- ENDPOINTS EXPEDIENTE INTEGRAL ---

@router.get("/gestion-pacientes/{id_paciente}/expediente")
def route_obtener_expediente(id_paciente: str, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    res = obtener_expediente_paciente(id_paciente)
    if not res: raise HTTPException(status_code=404, detail="Paciente no encontrado")
    return res

@router.post("/gestion-pacientes/{id_paciente}/alergias")
def route_guardar_alergias(id_paciente: str, payload: AllergiesUpdateRequest, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    guardar_alergias_y_temporales_full(
        id_paciente, 
        payload.ingredientes, 
        payload.grupos, 
        [t.model_dump() for t in payload.temporales]
    )
    return {"success": True}

@router.get("/gestion-pacientes/catalogo-grupos")
def route_catalogo_grupos(_=Depends(require_roles("admin", "medico", "nutricionista"))):
    from app.core.db import db_cursor
    with db_cursor() as cur:
        cur.execute("SELECT id, nombre FROM nutricion.grupo_alimentario ORDER BY nombre")
        return [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]

@router.get("/gestion-pacientes/catalogos")
def route_catalogos_registro(_=Depends(require_roles("admin", "medico"))):
    return get_patient_management_catalogs()

@router.get("/gestion-pacientes/buscar-tutor/{cedula}")
def route_buscar_tutor_cedula(cedula: str, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return buscar_tutor_por_cedula(cedula)

@router.get("/buscar-pacientes")
def route_buscar_pacientes(q: str = Query(default=""), limit: int = 50, _=Depends(require_roles("admin", "nutricionista", "medico"))):
    return buscar_pacientes(query=q, limit=limit)

# --- ENDPOINTS GESTIÓN INTEGRAL DE PACIENTES ---

@router.get("/gestion-pacientes/buscar")
def route_buscar_pacientes_gestion(q: str = Query(default=""), _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return buscar_pacientes_gestion(q)

@router.post("/gestion-pacientes/registrar")
def route_registrar_paciente_full(payload: PatientFullCreate, _=Depends(require_roles("admin", "medico"))):
    try:
        print(f"\n[API GESTIÓN] Recibida solicitud de registro integral: {payload.nombre}")
        print(f"[API GESTIÓN] Payload: {payload.model_dump_json(indent=2)}")
        id_p = registrar_paciente_full(payload.model_dump())
        return {"id": id_p, "success": True}
    except Exception as exc:
        print(f"[API GESTIÓN] ERROR en registro integral: {exc}")
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/gestion-pacientes/{id_paciente}")
def route_eliminar_paciente(id_paciente: str, _=Depends(require_roles("admin", "medico"))):
    success = eliminar_paciente_full(id_paciente)
    return {"success": success}

@router.post("/gestion-pacientes/control")
def route_registrar_control_clinico(payload: ClinicalControlCreate, user: UserContext = Depends(require_roles("admin", "medico", "nutricionista"))):
    try:
        print(f"\n[API GESTIÓN] Recibida solicitud de control clínico para paciente: {payload.id_paciente}")
        print(f"[API GESTIÓN] Payload: {payload.model_dump_json(indent=2)}")
        data = payload.model_dump()
        if user.role == "medico": data['id_medico'] = user.user_id
        elif user.role == "nutricionista": data['id_nutricionista'] = user.user_id
        id_control = registrar_control_clinico(data)
        return {"id": id_control, "success": True}
    except Exception as exc:
        print(f"[API GESTIÓN] ERROR en registro de control: {exc}")
        raise HTTPException(status_code=400, detail=str(exc))

# --- RESTO DE ENDPOINTS ---

@router.get("/condiciones-nutricionales")
def route_list_condiciones_nutricionales(_=Depends(require_roles("admin", "nutricionista"))):
    return list_nutritional_conditions()

@router.get("/reglas-nutricionales")
def route_list_nutritional_rules(_=Depends(require_roles("admin", "nutricionista"))):
    return list_nutritional_rules()

@router.get("/reglas-nutricionales/form-data")
def route_get_rule_form_data(_=Depends(require_roles("admin", "nutricionista"))):
    return get_nutritional_rule_form_data()

@router.get("/ingredientes-lista")
def route_ingredientes_lista(q: str = Query(default=""), cat: int = Query(default=None), active: bool = Query(default=None), limit: int = 15, offset: int = 0, _=Depends(require_roles("admin", "nutricionista", "medico"))):
    return list_ingredients_paged(query=q, category_id=cat, active=active, limit=limit, offset=offset)

@router.get("/ingredientes/{id_ingrediente}")
def route_ingrediente_detalle(id_ingrediente: int, _=Depends(require_roles("admin", "nutricionista", "medico"))):
    res = get_ingredient_detail(id_ingrediente)
    if not res: raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    return res

@router.put("/ingredientes/{id_ingrediente}")
def route_actualizar_ingrediente(id_ingrediente: int, payload: dict, _=Depends(require_roles("admin", "nutricionista"))):
    return {"success": update_ingredient_full(id_ingrediente, payload)}

@router.get("/etiquetas-lista")
def route_listar_etiquetas():
    return list_etiquetas_catalogo()

@router.post("/plan-manual", response_model=PlanManualResponse)
def route_plan_manual(payload: PlanManualRequest, _=Depends(require_roles("admin", "nutricionista"))):
    return save_manual_plan(id_paciente=payload.id_paciente, plan_data=payload.plan, replicar_mes=payload.replicate)

@router.post("/recetas-permitidas", response_model=RecetasPermitidasResponse)
def route_recetas_permitidas(payload: RecetasPermitidasRequest, _=Depends(require_roles("admin", "nutricionista", "tutor"))):
    return get_recetas_permitidas(id_paciente=payload.id_paciente, id_momento=payload.id_momento)
