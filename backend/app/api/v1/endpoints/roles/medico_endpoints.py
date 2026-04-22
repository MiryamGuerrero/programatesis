from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.api.deps import require_roles, UserContext
from app.schemas.domain import (
    AlergiaGrupoRequest, AlergiaIngredienteRequest, AlergiasPacienteResponse,
    ActualizarVinculoTutorPacienteRequest, AdherenciaCalculoRequest, AdherenciaCalculoResponse,
    ActualizarCondicionesTemporalesRequest, CondicionesTemporalesResponse,
    ControlClinicoActualResponse, ControlClinicoInicialRequest,
    DiagnosticoOmsRequest, DiagnosticoOmsResponse,
    ImcRequest, ImcResponse,
    ReglasEvaluacionRequest, ReglasEvaluacionResponse,
    RegistroPacienteRequest, RegistroPacienteSoloRequest,
    RegistroTutorRequest, RegistroTutorSoloRequest,
    VincularTutorPacienteRequest, CondicionCreateRequest,
    CondicionUpdateRequest, EvolucionPacienteResumenResponse,
    TipoCondicionCreateRequest, TipoCondicionUpdateRequest,
    MedicalConditionCreate, MedicalConditionUpdate,
    MedicalRuleCreate, MedicalRuleUpdate,
    PreDiagnosticoRequest, PreDiagnosticoResponse
)
from app.repositories.medico_tutor_repository import (
    actualizar_condicion, actualizar_condiciones_temporales_control_actual,
    actualizar_control_clinico_actual, actualizar_vinculo_tutor_paciente,
    buscar_pacientes, buscar_tutores, desactivar_alergia_subgrupo,
    desactivar_alergia_ingrediente, desvincular_tutor_paciente,
    listar_alergias_paciente, listar_condiciones_temporales_activas_control_actual,
    listar_vinculos_tutor_paciente, obtener_control_clinico_actual,
    registrar_alergia_subgrupo, registrar_alergia_ingrediente,
    registrar_paciente, registrar_paciente_y_vincular,
    registrar_tutor, registrar_tutor_paciente, vincular_tutor_paciente,
    actualizar_tipo_condicion, crear_condicion, crear_tipo_condicion,
    obtener_resumen_evolucion_paciente
)
from app.repositories.medical_conditions_repository import (
    list_medical_conditions, create_medical_condition,
    update_medical_condition, delete_medical_condition_safe
)
from app.repositories.medical_rules_repository import (
    list_medical_rules, get_medical_rule_form_data,
    create_medical_rule, update_medical_rule, delete_medical_rule
)
from app.services.roles.medico.modules.adherencia.adherence_analysis_service import calculate_adherence
from app.services.shared.cerebro.clasificacion_estado_nutricional_oms.anthropometry_diagnosis_service import (
    calcular_imc, clasificar_imc_general, diagnostico_oms
)
from app.services.shared.rule_engine_service import evaluate_rules
from app.services.shared.oms_service import calcular_edad_detallada, clasificar_oms_imc

router = APIRouter(tags=["Medico"])

# --- ENDPOINTS CATÁLOGO DE CONDICIONES MÉDICAS (CLÍNICAS Y TEMPORALES) ---

@router.post("/pre-diagnostico-nutricional", response_model=PreDiagnosticoResponse)
def pre_diagnostico_nutricional(payload: PreDiagnosticoRequest, _=Depends(require_roles("admin", "medico"))):
    """Calcula el estado nutricional al instante sin guardar nada."""
    try:
        anios, meses = calcular_edad_detallada(payload.fecha_nacimiento)
        imc = round(payload.peso_kg / ((payload.talla_cm / 100) ** 2), 2)
        id_cond, texto = clasificar_oms_imc(payload.id_sexo, meses, imc)
        return {
            "imc": imc,
            "anios": anios,
            "meses": meses,
            "id_condicion_nutricional": id_cond,
            "diagnostico_nutri_texto": texto
        }
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/condiciones-medicas")
def route_list_medical_conditions(_=Depends(require_roles("admin", "medico", "nutricionista"))):
    return list_medical_conditions()

@router.post("/condiciones-medicas")
def route_create_medical_condition(payload: MedicalConditionCreate, _=Depends(require_roles("admin", "medico"))):
    id_cond = create_medical_condition(payload)
    return {"id": id_cond, "success": True}

@router.put("/condiciones-medicas/{id_condicion}")
def route_update_medical_condition(id_condicion: int, payload: MedicalConditionUpdate, _=Depends(require_roles("admin", "medico"))):
    success = update_medical_condition(id_condicion, payload)
    return {"success": success}

@router.delete("/condiciones-medicas/{id_condicion}")
def route_delete_medical_condition(id_condicion: int, _=Depends(require_roles("admin", "medico"))):
    success = delete_medical_condition_safe(id_condicion)
    return {"success": success}

# --- ENDPOINTS GESTIÓN DE REGLAS MÉDICAS ---

@router.get("/reglas-medicas")
def route_list_medical_rules(_=Depends(require_roles("admin", "medico", "nutricionista"))):
    return list_medical_rules()

@router.get("/reglas-medicas/form-data")
def route_get_medical_rule_form_data(_=Depends(require_roles("admin", "medico"))):
    return get_medical_rule_form_data()

@router.post("/reglas-medicas")
def route_create_medical_rule(payload: MedicalRuleCreate, user: UserContext = Depends(require_roles("admin", "medico"))):
    id_regla = create_medical_rule(payload, created_by=user.user_id)
    return {"id": id_regla, "success": True}

@router.put("/reglas-medicas/{id_regla}")
def route_update_medical_rule(id_regla: int, payload: MedicalRuleUpdate, _=Depends(require_roles("admin", "medico"))):
    success = update_medical_rule(id_regla, payload)
    return {"success": success}

@router.delete("/reglas-medicas/{id_regla}")
def route_delete_medical_rule(id_regla: int, _=Depends(require_roles("admin", "medico"))):
    success = delete_medical_rule(id_regla)
    return {"success": success}

# --- ENDPOINTS EXISTENTES (MANTENIDOS) ---

@router.get("/tutores-buscar")
def buscar_tutores_endpoint(q: str = Query(..., min_length=1), limit: int = Query(10, ge=1, le=50), _=Depends(require_roles("admin", "medico"))):
    return buscar_tutores(q, limit)

@router.get("/pacientes-buscar")
def buscar_pacientes_endpoint(q: str = Query(default="", min_length=0), limit: int = Query(10, ge=1, le=50), _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return buscar_pacientes(q, limit)

@router.get("/pacientes/{id_paciente}/alergias", response_model=AlergiasPacienteResponse)
def listar_alergias_paciente_endpoint(id_paciente: str, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return listar_alergias_paciente(id_paciente)

@router.post("/pacientes/{id_paciente}/alergias/ingredientes")
def registrar_alergia_ingrediente_endpoint(id_paciente: str, payload: AlergiaIngredienteRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        registrar_alergia_ingrediente(id_paciente=id_paciente, id_ingrediente=payload.id_ingrediente, observacion=payload.observacion)
        return {"created": True}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/pacientes/{id_paciente}/alergias/ingredientes/{id_ingrediente}")
def desactivar_alergia_ingrediente_endpoint(id_paciente: str, id_ingrediente: int, _=Depends(require_roles("admin", "medico"))):
    try:
        deleted = desactivar_alergia_ingrediente(id_paciente=id_paciente, id_ingrediente=id_ingrediente)
        return {"deleted": deleted}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.post("/pacientes/{id_paciente}/alergias/subgrupos")
def registrar_alergia_subgrupo_endpoint(id_paciente: str, payload: AlergiaGrupoRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        # id_grupo_alimentario en el schema AlergiaGrupoRequest mapea a id_subgrupo_alimentario
        registrar_alergia_subgrupo(id_paciente=id_paciente, id_subgrupo_alimentario=payload.id_grupo_alimentario, observacion=payload.observacion)
        return {"created": True}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/pacientes/{id_paciente}/alergias/subgrupos/{id_subgrupo_alimentario}")
def desactivar_alergia_subgrupo_endpoint(id_paciente: str, id_subgrupo_alimentario: int, _=Depends(require_roles("admin", "medico"))):
    try:
        deleted = desactivar_alergia_subgrupo(id_paciente=id_paciente, id_subgrupo_alimentario=id_subgrupo_alimentario)
        return {"deleted": deleted}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.get("/pacientes/{id_paciente}/condiciones-temporales", response_model=CondicionesTemporalesResponse)
def listar_condiciones_temporales_endpoint(id_paciente: str, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return listar_condiciones_temporales_activas_control_actual(id_paciente)

@router.get("/pacientes/{id_paciente}/evolucion-resumen", response_model=EvolucionPacienteResumenResponse)
def obtener_resumen_evolucion_paciente_endpoint(id_paciente: str, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return obtener_resumen_evolucion_paciente(id_paciente)

@router.put("/pacientes/{id_paciente}/condiciones-temporales")
def actualizar_condiciones_temporales_endpoint(id_paciente: str, payload: ActualizarCondicionesTemporalesRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        id_control = actualizar_condiciones_temporales_control_actual(id_paciente=id_paciente, id_condiciones_temporales=payload.id_condiciones_temporales)
        return {"id_control": id_control}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.get("/pacientes/{id_paciente}/control-clinico-actual", response_model=ControlClinicoActualResponse)
def obtener_control_clinico_actual_endpoint(id_paciente: str, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    control = obtener_control_clinico_actual(id_paciente)
    if not control: raise HTTPException(status_code=404, detail="El paciente no tiene control clínico registrado.")
    return control

@router.put("/pacientes/{id_paciente}/control-clinico-actual")
def actualizar_control_clinico_actual_endpoint(id_paciente: str, payload: ControlClinicoInicialRequest, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    try:
        id_control = actualizar_control_clinico_actual(id_paciente=id_paciente, control_clinico=payload.model_dump())
        return {"id_control": id_control}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.post("/imc-calculo", response_model=ImcResponse)
def imc_calculo(payload: ImcRequest, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    imc = calcular_imc(payload.peso_kg, payload.talla_cm)
    return {"imc": imc, "clasificacion": clasificar_imc_general(imc)}

@router.post("/diagnostico-oms", response_model=DiagnosticoOmsResponse)
def diagnostico_oms_endpoint(payload: DiagnosticoOmsRequest, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    try:
        return diagnostico_oms(indicador_codigo=payload.indicador_codigo, id_sexo=payload.id_sexo, edad_meses=payload.edad_meses, valor=payload.valor)
    except ValueError as exc: raise HTTPException(status_code=404, detail=str(exc))

@router.post("/reglas-evaluacion", response_model=ReglasEvaluacionResponse)
def reglas_evaluacion(payload: ReglasEvaluacionRequest, _=Depends(require_roles("admin", "medico", "nutricionista"))):
    return evaluate_rules(condition_ids=payload.id_condiciones, ingrediente_ids=payload.ingrediente_ids, grupo_ids=payload.grupo_ids, etiqueta_ids=payload.etiqueta_ids)

@router.post("/adherencia-calculo", response_model=AdherenciaCalculoResponse)
def adherencia_calculo(payload: AdherenciaCalculoRequest, _=Depends(require_roles("admin", "medico", "nutricionista", "tutor"))):
    return calculate_adherence(id_plan=payload.id_plan, id_paciente=payload.id_paciente)

@router.post("/tutores-registro")
def registro_tutor_endpoint(payload: RegistroTutorRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        nuevo_id = registrar_tutor_paciente(email=payload.email, nombre_completo=payload.nombre_completo, id_paciente=payload.id_paciente, id_parentesco=payload.id_parentesco, es_principal=payload.es_principal)
        return {"id": nuevo_id}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.post("/tutores")
def registro_tutor_solo_endpoint(payload: RegistroTutorSoloRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        nuevo_id = registrar_tutor(email=payload.email, nombre_completo=payload.nombre_completo)
        return {"id": nuevo_id}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.post("/pacientes-registro")
def registro_paciente_endpoint(payload: RegistroPacienteRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        print(f"\n[API] Recibida solicitud de registro completo de paciente: {payload.nombre_completo}")
        print(f"[API] Payload: {payload.model_dump_json(indent=2)}")
        result = registrar_paciente_y_vincular(
            nombre_completo=payload.nombre_completo,
            fecha_nacimiento=payload.fecha_nacimiento,
            id_sexo=payload.id_sexo,
            id_provincia=payload.id_provincia,
            control_clinico_inicial=(payload.control_clinico_inicial.model_dump() if payload.control_clinico_inicial is not None else None),
            id_usuario_tutor=payload.id_usuario_tutor,
            id_parentesco=payload.id_parentesco,
            es_principal=payload.es_principal
        )
        return result
    except Exception as exc:
        print(f"[API] ERROR en registro de paciente: {exc}")
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/pacientes")
def registro_paciente_solo_endpoint(payload: RegistroPacienteSoloRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        print(f"\n[API] Recibida solicitud de registro simple de paciente: {payload.nombre_completo}")
        print(f"[API] Payload: {payload.model_dump_json(indent=2)}")
        result = registrar_paciente(
            nombre_completo=payload.nombre_completo,
            fecha_nacimiento=payload.fecha_nacimiento,
            id_sexo=payload.id_sexo,
            id_provincia=payload.id_provincia,
            control_clinico_inicial=(payload.control_clinico_inicial.model_dump() if payload.control_clinico_inicial is not None else None)
        )
        return result
    except Exception as exc:
        print(f"[API] ERROR en registro de paciente (solo): {exc}")
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/tutor-paciente-vinculo")
def vincular_tutor_paciente_endpoint(payload: VincularTutorPacienteRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        nuevo_id = vincular_tutor_paciente(id_usuario_tutor=payload.id_usuario_tutor, id_paciente=payload.id_paciente, id_parentesco=payload.id_parentesco, es_principal=payload.es_principal)
        return {"id": nuevo_id}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.get("/tutor-paciente-vinculo")
def listar_vinculos_tutor_paciente_endpoint(_=Depends(require_roles("admin", "medico"))):
    return listar_vinculos_tutor_paciente()

@router.put("/tutor-paciente-vinculo/{id_vinculo}")
def actualizar_vinculo_tutor_paciente_endpoint(id_vinculo: int, payload: ActualizarVinculoTutorPacienteRequest, _=Depends(require_roles("admin", "medico"))):
    try:
        updated = actualizar_vinculo_tutor_paciente(id_vinculo=id_vinculo, id_parentesco=payload.id_parentesco, es_principal=payload.es_principal)
        return {"updated": updated}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/tutor-paciente-vinculo/{id_vinculo}")
def desvincular_tutor_paciente_endpoint(id_vinculo: int, _=Depends(require_roles("admin", "medico"))):
    try:
        deleted = desvincular_tutor_paciente(id_vinculo)
        return {"deleted": deleted}
    except Exception as exc: raise HTTPException(status_code=400, detail=str(exc))
