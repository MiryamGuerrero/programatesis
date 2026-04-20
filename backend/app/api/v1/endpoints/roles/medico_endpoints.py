from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import require_roles
from app.schemas.domain import (
    AlergiaGrupoRequest,
    AlergiaIngredienteRequest,
    AlergiasPacienteResponse,
    ActualizarVinculoTutorPacienteRequest,
    AdherenciaCalculoRequest,
    AdherenciaCalculoResponse,
    ActualizarCondicionesTemporalesRequest,
    CondicionesTemporalesResponse,
    ControlClinicoActualResponse,
    ControlClinicoInicialRequest,
    DiagnosticoOmsRequest,
    DiagnosticoOmsResponse,
    ImcRequest,
    ImcResponse,
    ReglasEvaluacionRequest,
    ReglasEvaluacionResponse,
    RegistroPacienteRequest,
    RegistroPacienteSoloRequest,
    RegistroTutorRequest,
    RegistroTutorSoloRequest,
    VincularTutorPacienteRequest,
    CondicionCreateRequest,
    CondicionUpdateRequest,
    EvolucionPacienteResumenResponse,
    TipoCondicionCreateRequest,
    TipoCondicionUpdateRequest,
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
    actualizar_condicion,
    actualizar_condiciones_temporales_control_actual,
    actualizar_control_clinico_actual,
    actualizar_vinculo_tutor_paciente,
    buscar_pacientes,
    buscar_tutores,
    desactivar_alergia_grupo,
    desactivar_alergia_ingrediente,
    desvincular_tutor_paciente,
    listar_alergias_paciente,
    listar_condiciones_temporales_activas_control_actual,
    listar_vinculos_tutor_paciente,
    obtener_control_clinico_actual,
    registrar_alergia_grupo,
    registrar_alergia_ingrediente,
    registrar_paciente,
    registrar_paciente_y_vincular,
    registrar_tutor,
    registrar_tutor_paciente,
    vincular_tutor_paciente,
    actualizar_tipo_condicion,
    crear_condicion,
    crear_tipo_condicion,
    obtener_resumen_evolucion_paciente,
)
from app.services.shared.rule_engine_service import evaluate_rules

router = APIRouter(tags=["Medico"])


@router.get("/tutores-buscar")
def buscar_tutores_endpoint(
    q: str = Query(..., min_length=1),
    limit: int = Query(10, ge=1, le=50),
    _=Depends(require_roles("admin", "medico")),
) -> list[dict]:
    return buscar_tutores(q, limit)


@router.get("/pacientes-buscar")
def buscar_pacientes_endpoint(
    q: str = Query(default="", min_length=0),
    limit: int = Query(10, ge=1, le=50),
    _=Depends(require_roles("admin", "medico", "nutricionista")),
) -> list[dict]:
    return buscar_pacientes(q, limit)


@router.get("/pacientes/{id_paciente}/alergias", response_model=AlergiasPacienteResponse)
def listar_alergias_paciente_endpoint(
    id_paciente: str,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    return listar_alergias_paciente(id_paciente)


@router.post("/pacientes/{id_paciente}/alergias/ingredientes")
def registrar_alergia_ingrediente_endpoint(
    id_paciente: str,
    payload: AlergiaIngredienteRequest,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        registrar_alergia_ingrediente(
            id_paciente=id_paciente,
            id_ingrediente=payload.id_ingrediente,
            observacion=payload.observacion,
        )
        return {"created": True}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/pacientes/{id_paciente}/alergias/ingredientes/{id_ingrediente}")
def desactivar_alergia_ingrediente_endpoint(
    id_paciente: str,
    id_ingrediente: int,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        deleted = desactivar_alergia_ingrediente(
            id_paciente=id_paciente,
            id_ingrediente=id_ingrediente,
        )
        return {"deleted": deleted}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/pacientes/{id_paciente}/alergias/grupos")
def registrar_alergia_grupo_endpoint(
    id_paciente: str,
    payload: AlergiaGrupoRequest,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        registrar_alergia_grupo(
            id_paciente=id_paciente,
            id_grupo_alimentario=payload.id_grupo_alimentario,
            observacion=payload.observacion,
        )
        return {"created": True}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/pacientes/{id_paciente}/alergias/grupos/{id_grupo_alimentario}")
def desactivar_alergia_grupo_endpoint(
    id_paciente: str,
    id_grupo_alimentario: int,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        deleted = desactivar_alergia_grupo(
            id_paciente=id_paciente,
            id_grupo_alimentario=id_grupo_alimentario,
        )
        return {"deleted": deleted}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/pacientes/{id_paciente}/condiciones-temporales", response_model=CondicionesTemporalesResponse)
def listar_condiciones_temporales_endpoint(
    id_paciente: str,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    return listar_condiciones_temporales_activas_control_actual(id_paciente)

@router.post("/catalogo-condiciones/tipos")
def crear_tipo_condicion_endpoint(
    payload: TipoCondicionCreateRequest,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, int]:
    try:
        created_id = crear_tipo_condicion(
            codigo=payload.codigo,
            nombre=payload.nombre,
        )
        return {"id": created_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

@router.put("/catalogo-condiciones/tipos/{id_tipo_condicion}")
def actualizar_tipo_condicion_endpoint(
    id_tipo_condicion: int,
    payload: TipoCondicionUpdateRequest,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        updated = actualizar_tipo_condicion(
            id_tipo_condicion=id_tipo_condicion,
            codigo=payload.codigo,
            nombre=payload.nombre,
        )
        return {"updated": updated}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

@router.post("/catalogo-condiciones/condiciones")
def crear_condicion_endpoint(
    payload: CondicionCreateRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
) -> dict[str, int]:
    try:
        created_id = crear_condicion(
            nombre=payload.nombre,
            id_tipo_condicion=payload.id_tipo_condicion,
            descripcion=payload.descripcion,
            activa=payload.activa,
        )
        return {"id": created_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

@router.put("/catalogo-condiciones/condiciones/{id_condicion}")
def actualizar_condicion_endpoint(
    id_condicion: int,
    payload: CondicionUpdateRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
) -> dict[str, bool]:
    try:
        updated = actualizar_condicion(
            id_condicion=id_condicion,
            nombre=payload.nombre,
            id_tipo_condicion=payload.id_tipo_condicion,
            descripcion=payload.descripcion,
            activa=payload.activa,
        )
        return {"updated": updated}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

@router.get("/pacientes/{id_paciente}/evolucion-resumen", response_model=EvolucionPacienteResumenResponse)
def obtener_resumen_evolucion_paciente_endpoint(
    id_paciente: str,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    return obtener_resumen_evolucion_paciente(id_paciente)


@router.put("/pacientes/{id_paciente}/condiciones-temporales")
def actualizar_condiciones_temporales_endpoint(
    id_paciente: str,
    payload: ActualizarCondicionesTemporalesRequest,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, int]:
    try:
        id_control = actualizar_condiciones_temporales_control_actual(
            id_paciente=id_paciente,
            id_condiciones_temporales=payload.id_condiciones_temporales,
        )
        return {"id_control": id_control}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/pacientes/{id_paciente}/control-clinico-actual", response_model=ControlClinicoActualResponse)
def obtener_control_clinico_actual_endpoint(
    id_paciente: str,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    control = obtener_control_clinico_actual(id_paciente)
    if not control:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El paciente no tiene control clínico registrado.",
        )
    return control


@router.put("/pacientes/{id_paciente}/control-clinico-actual")
def actualizar_control_clinico_actual_endpoint(
    id_paciente: str,
    payload: ControlClinicoInicialRequest,
    _=Depends(require_roles("admin", "medico", "nutricionista")),
) -> dict[str, int]:
    try:
        id_control = actualizar_control_clinico_actual(
            id_paciente=id_paciente,
            control_clinico=payload.model_dump(),
        )
        return {"id_control": id_control}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


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


@router.post("/tutores")
def registro_tutor_solo_endpoint(
    payload: RegistroTutorSoloRequest,
    _=Depends(require_roles("admin", "medico")),
):
    try:
        nuevo_id = registrar_tutor(
            email=payload.email,
            nombre_completo=payload.nombre_completo,
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
            control_clinico_inicial=(
                payload.control_clinico_inicial.model_dump()
                if payload.control_clinico_inicial is not None
                else None
            ),
            id_usuario_tutor=payload.id_usuario_tutor,
            id_parentesco=payload.id_parentesco,
            es_principal=payload.es_principal,
        )
        return {"id": nuevo_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/pacientes")
def registro_paciente_solo_endpoint(
    payload: RegistroPacienteSoloRequest,
    _=Depends(require_roles("admin", "medico")),
):
    try:
        nuevo_id = registrar_paciente(
            nombre_completo=payload.nombre_completo,
            fecha_nacimiento=payload.fecha_nacimiento,
            id_sexo=payload.id_sexo,
            id_provincia=payload.id_provincia,
            control_clinico_inicial=(
                payload.control_clinico_inicial.model_dump()
                if payload.control_clinico_inicial is not None
                else None
            ),
        )
        return {"id": nuevo_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/tutor-paciente-vinculo")
def vincular_tutor_paciente_endpoint(
    payload: VincularTutorPacienteRequest,
    _=Depends(require_roles("admin", "medico")),
):
    try:
        nuevo_id = vincular_tutor_paciente(
            id_usuario_tutor=payload.id_usuario_tutor,
            id_paciente=payload.id_paciente,
            id_parentesco=payload.id_parentesco,
            es_principal=payload.es_principal,
        )
        return {"id": nuevo_id}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/tutor-paciente-vinculo")
def listar_vinculos_tutor_paciente_endpoint(
    _=Depends(require_roles("admin", "medico")),
) -> list[dict]:
    return listar_vinculos_tutor_paciente()


@router.put("/tutor-paciente-vinculo/{id_vinculo}")
def actualizar_vinculo_tutor_paciente_endpoint(
    id_vinculo: int,
    payload: ActualizarVinculoTutorPacienteRequest,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        updated = actualizar_vinculo_tutor_paciente(
            id_vinculo=id_vinculo,
            id_parentesco=payload.id_parentesco,
            es_principal=payload.es_principal,
        )
        return {"updated": updated}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/tutor-paciente-vinculo/{id_vinculo}")
def desvincular_tutor_paciente_endpoint(
    id_vinculo: int,
    _=Depends(require_roles("admin", "medico")),
) -> dict[str, bool]:
    try:
        deleted = desvincular_tutor_paciente(id_vinculo)
        return {"deleted": deleted}
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
