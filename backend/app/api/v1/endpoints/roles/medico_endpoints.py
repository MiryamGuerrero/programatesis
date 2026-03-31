from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import require_roles
from app.schemas.domain import (
    AdherenciaCalculoRequest,
    AdherenciaCalculoResponse,
    DiagnosticoOmsRequest,
    DiagnosticoOmsResponse,
    ImcRequest,
    ImcResponse,
    ReglasEvaluacionRequest,
    ReglasEvaluacionResponse,
)
from app.services.roles.medico.modules.adherencia.adherence_analysis_service import (
    calculate_adherence,
)
from app.services.roles.medico.modules.diagnostico_oms.anthropometry_diagnosis_service import (
    calcular_imc,
    clasificar_imc_general,
    diagnostico_oms,
)
from app.services.shared.rule_engine_service import evaluate_rules

router = APIRouter(tags=["Medico"])


@router.post("/imc-calculo", response_model=ImcResponse)
def imc_calculo(
    payload: ImcRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    imc = calcular_imc(payload.peso_kg, payload.talla_cm)
    return {
        "imc": imc,
        "clasificacion": clasificar_imc_general(imc),
    }


@router.post("/diagnostico-oms", response_model=DiagnosticoOmsResponse)
def diagnostico_oms_endpoint(
    payload: DiagnosticoOmsRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    try:
        return diagnostico_oms(
            indicador_codigo=payload.indicador_codigo,
            id_sexo=payload.id_sexo,
            edad_meses=payload.edad_meses,
            valor=payload.valor,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/reglas-evaluacion", response_model=ReglasEvaluacionResponse)
def reglas_evaluacion(
    payload: ReglasEvaluacionRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    return evaluate_rules(
        condition_ids=payload.id_condiciones,
        ingrediente_ids=payload.ingrediente_ids,
        grupo_ids=payload.grupo_ids,
        etiqueta_ids=payload.etiqueta_ids,
    )


@router.post("/adherencia-calculo", response_model=AdherenciaCalculoResponse)
def adherencia_calculo(
    payload: AdherenciaCalculoRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor")),
):
    return calculate_adherence(
        id_plan=payload.id_plan,
        id_paciente=payload.id_paciente,
    )
