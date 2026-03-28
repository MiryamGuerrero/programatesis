from fastapi import APIRouter, Depends

from app.api.deps import require_roles
from app.schemas.domain import (
    IngredientesPermitidosRequest,
    IngredientesPermitidosResponse,
    PlanAutomaticoRequest,
    PlanAutomaticoResponse,
    PreferenciasAprendidasRequest,
    PreferenciasAprendidasResponse,
    RecetasPermitidasRequest,
    RecetasPermitidasResponse,
    ReemplazoEquivalenteRequest,
    ReemplazoEquivalenteResponse,
)
from app.services.nutricion_tutor.ingredient_service import get_patient_ingredient_permissions
from app.services.nutricion_tutor.planning_service import generate_automatic_plan
from app.services.nutricion_tutor.preference_service import learn_preferences
from app.services.nutricion_tutor.recipe_service import get_recetas_permitidas
from app.services.nutricion_tutor.replacement_service import find_equivalent_replacements

router = APIRouter(tags=["Nutricionista Tutor"])


@router.post("/ingredientes-permitidos", response_model=IngredientesPermitidosResponse)
def ingredientes_permitidos(
    payload: IngredientesPermitidosRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
):
    return get_patient_ingredient_permissions(payload.id_paciente)


@router.post("/recetas-permitidas", response_model=RecetasPermitidasResponse)
def recetas_permitidas(
    payload: RecetasPermitidasRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
):
    return get_recetas_permitidas(
        id_paciente=payload.id_paciente,
        id_momento=payload.id_momento,
    )


@router.post("/plan-automatico", response_model=PlanAutomaticoResponse)
def plan_automatico(
    payload: PlanAutomaticoRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    return generate_automatic_plan(
        id_paciente=payload.id_paciente,
        fecha_inicio=payload.fecha_inicio,
        dias=payload.dias,
        comidas_por_dia=payload.comidas_por_dia,
    )


@router.post("/reemplazo-equivalente", response_model=ReemplazoEquivalenteResponse)
def reemplazo_equivalente(
    payload: ReemplazoEquivalenteRequest,
    _=Depends(require_roles("admin", "nutricionista", "tutor")),
):
    return find_equivalent_replacements(
        id_ingrediente_original=payload.id_ingrediente_original,
        cantidad_gramos=payload.cantidad_gramos,
    )


@router.post("/preferencias-aprendidas", response_model=PreferenciasAprendidasResponse)
def preferencias_aprendidas(
    payload: PreferenciasAprendidasRequest,
    _=Depends(require_roles("admin", "nutricionista")),
):
    return learn_preferences(
        id_paciente=payload.id_paciente,
        persist=payload.persistir,
    )
