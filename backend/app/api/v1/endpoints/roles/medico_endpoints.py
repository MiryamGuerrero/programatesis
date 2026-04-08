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
    RegistroPacienteRequest,
    RegistroTutorRequest,
)
from app.services.roles.medico.modules.adherencia.adherence_analysis_service import (
    calculate_adherence,
)
from app.services.shared.cerebro.clasificacion_estado_nutricional_oms.anthropometry_diagnosis_service import (
    calcular_imc,
    clasificar_imc_general,
    diagnostico_oms,
)
from app.repositories.medico_tutor_repository import (
    registrar_paciente_y_vincular,
    registrar_tutor_paciente,
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


@router.post("/tutores-registro")
def registro_tutor_endpoint(
    payload: RegistroTutorRequest,
    _=Depends(require_roles("admin", "medico")),
):
    try:
        nuevo_id = registrar_tutor_paciente(
            email=payload.email,
            nombre_completo=payload.nombre_completo,
            id_paciente=payload.id_paciente,
            id_parentesco=payload.id_parentesco,
            es_principal=payload.es_principal,
        )
        return {"id": nuevo_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/pacientes-registro")
def registro_paciente_endpoint(
    payload: RegistroPacienteRequest,
    _=Depends(require_roles("admin", "medico")),
):
    try:
        nuevo_id = registrar_paciente_y_vincular(
            nombre_completo=payload.nombre_completo,
            fecha_nacimiento=payload.fecha_nacimiento,
            id_sexo=payload.id_sexo,
            id_provincia=payload.id_provincia,
            id_usuario_tutor=payload.id_usuario_tutor,
            id_parentesco=payload.id_parentesco,
            es_principal=payload.es_principal,
        )
        return {"id": nuevo_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
