from fastapi import APIRouter, Depends, Query, HTTPException
from app.api.deps import require_roles
from app.schemas.domain import (
    IngredientesPermitidosRequest, IngredientesPermitidosResponse,
    PlanAutomaticoRequest, PlanAutomaticoResponse,
    PlanManualRequest, PlanManualResponse,
    PreferenciasAprendidasRequest, PreferenciasAprendidasResponse,
    RecetasPermitidasRequest, RecetasPermitidasResponse
)
from app.repositories.medico_tutor_repository import buscar_pacientes
from app.services.roles.nutricionista.modules.plan_nutricional.patient_profile_service import get_patient_full_profile
from app.repositories.ingredientes_repository import list_ingredients_paged, get_ingredient_detail
from app.repositories.ingredientes_update_repository import update_ingredient_full
from app.services.roles.nutricionista.modules.ingredientes.ingredient_permission_service import get_patient_ingredient_permissions
from app.services.roles.nutricionista.modules.plan_nutricional.manual_plan_service import save_manual_plan
from app.services.roles.nutricionista.modules.plan_nutricional.nutrition_plan_service import generate_automatic_plan
from app.services.roles.nutricionista.modules.preferencias.preference_learning_service import learn_preferences
from app.services.roles.nutricionista.modules.recetas.allowed_recipe_service import get_recetas_permitidas

router = APIRouter(tags=["Nutricionista"])

# --- ENDPOINTS SIN PREFIJOS PARA EVITAR 404 ---

@router.get("/buscar-pacientes")
def route_buscar_pacientes(q: str = Query(default=""), limit: int = 50, _=Depends(require_roles("admin", "nutricionista"))):
    return buscar_pacientes(query=q, limit=limit)

@router.get("/paciente-perfil/{id_paciente}")
def route_paciente_perfil(id_paciente: str, _=Depends(require_roles("admin", "nutricionista"))):
    return get_patient_full_profile(id_paciente)

@router.get("/ingredientes-lista")
def route_ingredientes_lista(q: str = Query(default=""), cat: int = Query(default=None), active: bool = Query(default=None), limit: int = 15, offset: int = 0, _=Depends(require_roles("admin", "nutricionista"))):
    return list_ingredients_paged(query=q, category_id=cat, active=active, limit=limit, offset=offset)

@router.get("/ingredientes/{id_ingrediente}")
def route_ingrediente_detalle(id_ingrediente: int, _=Depends(require_roles("admin", "nutricionista"))):
    res = get_ingredient_detail(id_ingrediente)
    if not res: raise HTTPException(status_code=404, detail="No encontrado")
    return res

@router.put("/ingredientes/{id_ingrediente}")
def route_actualizar_ingrediente(id_ingrediente: int, payload: dict, _=Depends(require_roles("admin", "nutricionista"))):
    return {"success": update_ingredient_full(id_ingrediente, payload)}

@router.post("/plan-manual", response_model=PlanManualResponse)
def route_plan_manual(payload: PlanManualRequest, _=Depends(require_roles("admin", "nutricionista"))):
    return save_manual_plan(id_paciente=payload.id_paciente, plan_data=payload.plan, replicar_mes=payload.replicate)

@router.post("/ingredientes-permitidos", response_model=IngredientesPermitidosResponse)
def route_ingredientes_permitidos(payload: IngredientesPermitidosRequest, _=Depends(require_roles("admin", "nutricionista", "medico"))):
    return get_patient_ingredient_permissions(payload.id_paciente)

@router.post("/recetas-permitidas", response_model=RecetasPermitidasResponse)
def route_recetas_permitidas(payload: RecetasPermitidasRequest, _=Depends(require_roles("admin", "nutricionista", "tutor"))):
    return get_recetas_permitidas(id_paciente=payload.id_paciente, id_momento=payload.id_momento)

@router.post("/plan-automatico", response_model=PlanAutomaticoResponse)
def route_plan_automatico(payload: PlanAutomaticoRequest, _=Depends(require_roles("admin", "nutricionista"))):
    return generate_automatic_plan(
        id_paciente=payload.id_paciente,
        fecha_inicio=payload.fecha_inicio,
        dias=payload.dias,
        comidas_por_dia=payload.comidas_por_dia
    )

@router.post("/preferencias-aprendizaje", response_model=PreferenciasAprendidasResponse)
def route_preferencias_aprendizaje(payload: PreferenciasAprendidasRequest, _=Depends(require_roles("admin", "nutricionista"))):
    return learn_preferences(id_paciente=payload.id_paciente)
