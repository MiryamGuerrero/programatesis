from typing import Any
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import require_roles, UserContext
from app.api.v1.use_cases import (
    obtener_caso_uso_gestionar_clinico,
    obtener_caso_uso_gestionar_catalogos,
    obtener_caso_uso_supervisar_adherencia,
    obtener_caso_uso_gestionar_pacientes,
    obtener_caso_uso_gestionar_usuarios,
)
from app.aplicacion.clinica.gestionar_catalogos import CasoUsoGestionarCatalogos
from app.aplicacion.clinica.gestionar_control_clinico import CasoUsoGestionarControlClinico
from app.aplicacion.clinica.supervisar_adherencia import CasoUsoSupervisarAdherenciaPacientes
from app.aplicacion.clinica.gestionar_pacientes import CasoUsoGestionarPacientes
from app.aplicacion.clinica.gestionar_usuarios import CasoUsoGestionarUsuarios
from app.api.v1.dtos.clinico import (
    EstadoNutricionalOMSRequest,
    PreDiagnosticoRequest,
    PreDiagnosticoResponse,
    RegistroPacienteIntegralRequest,
    ActualizarExpedienteFijoRequest,
)
from app.infraestructura.repositorios.repositorio_clinico import RepositorioClinicoPostgres
from app.domain.servicios.servicio_oms import ServicioOMS

router = APIRouter(tags=["Medico"])

@router.post("/pre-diagnostico-nutricional", response_model=PreDiagnosticoResponse)
def pre_diagnostico_nutricional(
    payload: PreDiagnosticoRequest,
    caso_uso: CasoUsoGestionarControlClinico = Depends(obtener_caso_uso_gestionar_clinico),
    _=Depends(require_roles("admin", "medico"))
):
    """Calcula el estado nutricional al instante sin guardar nada."""
    try:
        # Convertir a objeto date de forma segura
        dob = payload.fecha_nacimiento
        if isinstance(dob, str):
            dob = date.fromisoformat(dob)

        today = date.today()

        result = ServicioOMS.evaluar_paciente_integral(
            payload.peso_kg,
            payload.talla_cm,
            payload.id_sexo,
            dob,
            today
        )

        return {
            "imc": result["imc"],
            "z_score": result["z_score_principal"] or 0.0,
            "id_condicion_nutricional": result["id_condicion_nutricional_heuristica"] or 110,
            "id_condicion_nutricional_oms": result["id_condicion_nutricional_principal"] or 0,
            "diagnostico_nutri_texto": result["diagnostico_nutri_texto"],
            "diagnostico_talla_texto": result["diagnostico_talla_texto"],
            "diagnostico_peso_complementario": result["diagnostico_peso_complementario"],
            "diagnostico_combinado": result["diagnostico_combinado"],
            "resumen_clinico": result["resumen_clinico"],
            "z_score_talla": result["talla_edad"]["z_score"] or 0.0,
            "peso_ideal": result["peso_ideal_estimado"],
            "talla_ideal": result["talla_ideal"],
            "ganancia_peso_necesaria": result["ganancia_peso_necesaria"],
            "ganancia_talla_necesaria": result["ganancia_talla_necesaria"],
            "estado_peso": result["estado_peso"],
            "anios": result["edad_meses"] // 12,
            "meses": result["edad_meses"] % 12
        }
    except Exception as exc:
        import logging
        logging.error(f"Error en pre_diagnostico_nutricional: {str(exc)}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(exc))
@router.post("/diagnostico-oms")
def diagnostico_oms(
    payload: dict,
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    repo = RepositorioClinicoPostgres()
    res = repo.obtener_datos_referencia_oms(
        payload["id_sexo"], 
        payload["edad_meses"], 
        payload.get("indicador_id", 1)
    )
    if not res: return {"error": "No hay referencia"}
    
    valor = float(payload["valor"])
    z_score = ServicioOMS.calcular_z_score(valor, res["l"], res["m"], res["s"])
    
    # Se requiere edad_meses para clasificar correctamente
    edad_meses = payload.get("edad_meses", 0)
    indicador = str(payload.get("indicador_id", "BMI"))
    
    clasif = ServicioOMS.clasificar_zscore(indicador, z_score, edad_meses)
    
    return {
        "z_score": round(z_score, 2),
        "id_condicion": clasif["id"],
        "diagnostico": clasif["diagnostico"]
    }


@router.post("/estado-nutricional-oms")
def estado_nutricional_oms(
    payload: EstadoNutricionalOMSRequest,
    _=Depends(require_roles("admin", "medico")),
):
    """Devuelve la evaluacion OMS completa sin guardar datos."""
    try:
        return ServicioOMS.evaluar_estado_nutricional(
            sexo_id=payload.sexo_id,
            fecha_nacimiento=payload.fecha_nacimiento,
            fecha_control=payload.fecha_control,
            peso_kg=payload.peso_kg,
            talla_cm=payload.talla_cm,
            tipo_medicion=payload.tipo_medicion,
        )
    except Exception as exc:
        import logging
        logging.error(f"Error en estado_nutricional_oms: {str(exc)}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/supervisar-adherencia-pacientes")
def supervisar_adherencia(
    user: UserContext = Depends(require_roles("admin", "medico")),
    caso_uso: CasoUsoSupervisarAdherenciaPacientes = Depends(obtener_caso_uso_supervisar_adherencia)
) -> list[dict[str, Any]]:
    return caso_uso.ejecutar(user.user_id)

@router.get("/pacientes-buscar")
def buscar_pacientes_clinicos(
    q: str = Query(default=""), 
    limit: int = Query(10, ge=1, le=50), 
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    return caso_uso.buscar(q, limit)

@router.get("/pacientes/{id_paciente}/evolucion-resumen")
def evolucion_paciente(
    id_paciente: str, 
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    return caso_uso.obtener_resumen_evolucion(id_paciente)

@router.get("/pacientes")
def listar_todos_los_pacientes(
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    return caso_uso.listar_todos()

@router.delete("/pacientes/{id_paciente}")
def eliminar_paciente_clinico(
    id_paciente: str,
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico"))
):
    exito = caso_uso.eliminar(id_paciente)
    return {"success": exito}

@router.get("/usuarios/tutor-by-cedula/{cedula}")
def obtener_tutor_por_cedula(
    cedula: str,
    caso_uso: CasoUsoGestionarUsuarios = Depends(obtener_caso_uso_gestionar_usuarios),
    _=Depends(require_roles("admin", "medico"))
):
    return caso_uso.buscar_tutor_por_cedula(cedula)

@router.get("/registro/paciente-integral/catalogos")
def obtener_catalogos_registro_paciente(
    caso_uso: CasoUsoGestionarCatalogos = Depends(obtener_caso_uso_gestionar_catalogos),
    _=Depends(require_roles("admin", "medico"))
):
    return caso_uso.obtener_catalogos_registro_paciente()

@router.get("/pacientes/{id_paciente}/expediente-completo")
def obtener_expediente_completo(
    id_paciente: str,
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista", "tutor"))
):
    return caso_uso.obtener_expediente_completo(id_paciente)

@router.post("/pacientes/{id_paciente}/control-mensual")
def registrar_control_mensual(
    id_paciente: str,
    payload: dict,
    user: UserContext = Depends(require_roles("admin", "medico")),
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
):
    try:
        id_control = caso_uso.registrar_control_mensual(id_paciente, payload, id_medico=user.user_id)
        return {"id": id_control, "message": "Control mensual registrado"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/pacientes/control-mensual/{id_control}")
def actualizar_control_mensual(
    id_control: int,
    payload: dict,
    user: UserContext = Depends(require_roles("admin", "medico")),
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
):
    try:
        exito = caso_uso.actualizar_control_mensual(id_control, payload)
        return {"success": exito, "message": "Control actualizado correctamente"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/pacientes/{id_paciente}/expediente-maestro")
def actualizar_expediente_maestro(
    id_paciente: str,
    payload: ActualizarExpedienteFijoRequest,
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    try:
        exito = caso_uso.actualizar_expediente(
            id_paciente,
            payload.model_dump(mode="json"),
        )
        return {"success": exito, "message": "Expediente actualizado correctamente"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/registro/paciente-integral")
def registro_paciente_integral(
    payload: RegistroPacienteIntegralRequest,
    user: UserContext = Depends(require_roles("admin", "medico")),
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
):
    try:
        resultado = caso_uso.registrar_nuevo_paciente(
            payload.model_dump(mode="json"),
            id_usuario_creador=user.user_id,
        )
        return {
            "id": resultado["id"], 
            "message": "Paciente registrado exitosamente",
            "temp_password": resultado.get("temp_password")
        }
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/registro/tutor-solo")
def registrar_tutor_solo(
    payload: dict,
    user: UserContext = Depends(require_roles("admin", "medico")),
    caso_uso: CasoUsoGestionarUsuarios = Depends(obtener_caso_uso_gestionar_usuarios),
):
    try:
        id_t = caso_uso.registrar_tutor_solo(payload)
        return {"id": id_t, "message": "Tutor registrado exitosamente"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

# --- GESTIÓN DE REGLAS MÉDICAS ---

@router.get("/reglas-medicas")
def listar_reglas_medicas(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    return repo.listar_reglas_detalladas()

@router.get("/reglas-medicas/form-data")
def obtener_form_data_reglas(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return {
        "condiciones": repo.obtener_catalogo("heuristico", "condicion", filtro_tipos=[1, 2]),
        "acciones": repo.obtener_catalogo("heuristico", "catalogo_accion"),
        "objetivos": repo.obtener_catalogo("heuristico", "catalogo_objetivo_regla"),
        "ingredientes": repo.obtener_catalogo("nutricion", "ingrediente"),
        "grupos": repo.obtener_catalogo("nutricion", "grupo_alimentario"),
        "subgrupos": repo.obtener_catalogo("nutricion", "subgrupo_alimentario"),
        "etiquetas": repo.obtener_catalogo("nutricion", "etiqueta_nutricional")
    }

@router.post("/reglas-medicas")
def guardar_nueva_regla(
    payload: dict,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    return {"id": repo.guardar_regla(payload), "success": True}

@router.put("/reglas-medicas/{id_regla}")
def actualizar_regla_medica(
    id_regla: int,
    payload: dict,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    return {"success": repo.actualizar_regla(id_regla, payload)}

@router.delete("/reglas-medicas/{id_regla}")
def eliminar_regla_medica(
    id_regla: int,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    repo.eliminar_regla(id_regla)
    return {"success": True}

# --- CRUD CATÁLOGO DE CONDICIONES ---

@router.get("/catalogos/condiciones")
def listar_condiciones_catalogo(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("heuristico", "condicion", filtro_tipos=[1, 2])

@router.get("/catalogos/tipos-condicion")
def listar_tipos_condicion(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("heuristico", "catalogo_tipo_condicion")

@router.post("/catalogos/condiciones")
def crear_nueva_condicion(
    payload: dict,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    try:
        payload["id_tipo_condicion"] = payload.get("id_tipo") or payload.get("id_tipo_condicion")
        return {"id": repo.crear_condicion(payload), "success": True}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/catalogos/condiciones/{id_condicion}")
def actualizar_condicion_catalogo(
    id_condicion: int,
    payload: dict,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    try:
        return {"success": repo.actualizar_condicion(id_condicion, payload)}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/catalogos/condiciones/{id_condicion}")
def eliminar_condicion_catalogo(
    id_condicion: int,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    try:
        return {"success": repo.eliminar_condicion(id_condicion)}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))
