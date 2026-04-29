from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import require_roles, UserContext
from app.api.v1.use_cases import obtener_caso_uso_gestionar_clinico, obtener_caso_uso_supervisar_adherencia, obtener_caso_uso_gestionar_pacientes
from app.aplicacion.clinica.gestionar_control_clinico import CasoUsoGestionarControlClinico
from app.aplicacion.clinica.supervisar_adherencia import CasoUsoSupervisarAdherenciaPacientes
from app.aplicacion.clinica.gestionar_pacientes import CasoUsoGestionarPacientes
from app.api.v1.dtos.clinico import PreDiagnosticoRequest, PreDiagnosticoResponse

router = APIRouter(tags=["Medico"])

@router.post("/pre-diagnostico-nutricional", response_model=PreDiagnosticoResponse)
def pre_diagnostico_nutricional(
    payload: PreDiagnosticoRequest, 
    caso_uso: CasoUsoGestionarControlClinico = Depends(obtener_caso_uso_gestionar_clinico),
    _=Depends(require_roles("admin", "medico"))
):
    """Calcula el estado nutricional al instante sin guardar nada."""
    try:
        from app.domain.servicios.servicio_oms import ServicioOMS
        _, meses = ServicioOMS.calcular_edad_detallada(payload.fecha_nacimiento)
        
        result = caso_uso.calcular_estado_nutricional(
            peso=payload.peso_kg,
            talla=payload.talla_cm,
            edad_meses=meses,
            id_sexo=payload.id_sexo
        )
        
        return {
            **result,
            "anios": meses // 12,
            "meses": meses % 12
        }
    except Exception as exc:
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
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.obtener_resumen_evolucion(id_paciente)

@router.get("/pacientes")
def listar_todos_los_pacientes(
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    print("DEBUG: Endpoint /pacientes invocado")
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.listar_todos_pacientes()

@router.delete("/pacientes/{id_paciente}")
def eliminar_paciente_clinico(
    id_paciente: str,
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico"))
):
    """Elimina un paciente y sus datos clínicos. Limpia tutores huérfanos."""
    exito = caso_uso.eliminar(id_paciente)
    return {"success": exito}

@router.get("/usuarios/tutor-by-cedula/{cedula}")
def obtener_tutor_por_cedula(
    cedula: str,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    res = repo.buscar_tutor_por_cedula(cedula)
    if not res:
        return {"existe": False}

    # Aseguramos que retorne el flag de existencia
    res["existe"] = True
    return res
@router.get("/pacientes/{id_paciente}/expediente-completo")
def obtener_expediente_completo(
    id_paciente: str,
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.obtener_expediente_completo(id_paciente)

@router.post("/pacientes/{id_paciente}/control-mensual")
def registrar_control_mensual(
    id_paciente: str,
    payload: dict,
    user: UserContext = Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    try:
        id_control = repo.registrar_control_mensual(id_paciente, payload, id_medico=user.user_id)
        return {"id": id_control, "message": "Control mensual registrado"}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.put("/pacientes/{id_paciente}/expediente-maestro")
def actualizar_expediente_maestro(
    id_paciente: str,
    payload: dict,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    try:
        exito = repo.actualizar_paciente_integral(id_paciente, payload)
        return {"success": exito, "message": "Expediente actualizado correctamente"}
    except Exception as exc:
        print(f"DEBUG ERROR ACTUALIZAR: {str(exc)}")
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/registro/paciente-integral")
def registro_paciente_integral(
    payload: dict,
    user: UserContext = Depends(require_roles("admin", "medico"))
):
    print(f"DEBUG: Endpoint /registro/paciente-integral invocado por {user.user_id}")
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    try:
        resultado = repo.registrar_paciente_integral(payload, id_usuario_creador=user.user_id)
        return {
            "id": resultado["id"], 
            "message": "Paciente registrado exitosamente",
            "temp_password": resultado.get("temp_password")
        }
    except Exception as exc:
        print(f"DEBUG ERROR: {str(exc)}")
        raise HTTPException(status_code=400, detail=str(exc))

# --- GESTIÓN DE REGLAS MÉDICAS ---

@router.get("/reglas-medicas")
def listar_reglas_medicas(
    _=Depends(require_roles("admin", "medico"))
):
    print("DEBUG: Endpoint /reglas-medicas invocado")
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    return repo.listar_reglas_detalladas()

@router.get("/reglas-medicas/form-data")
def obtener_form_data_reglas(
    _=Depends(require_roles("admin", "medico"))
):
    print("DEBUG: Endpoint /reglas-medicas/form-data invocado")
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return {
        "condiciones": repo.obtener_catalogo("heuristico", "condicion"),
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
    id_regla = repo.guardar_regla(payload)
    return {"id": id_regla, "success": True}

@router.delete("/reglas-medicas/{id_regla}")
def eliminar_regla_medica(
    id_regla: int,
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    repo.eliminar_regla(id_regla)
    return {"success": True}

# --- ACCESO A CATÁLOGOS NUTRICIONALES PARA MÉDICO ---

@router.get("/ingredientes")
def listar_ingredientes_medico(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "ingrediente")

@router.get("/etiquetas")
def listar_etiquetas_medico(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "etiqueta_nutricional")

# --- CRUD CATÁLOGO DE CONDICIONES ---

@router.get("/catalogos/condiciones")
def listar_condiciones_catalogo(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("heuristico", "condicion")

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
        id_c = repo.crear_condicion(payload)
        return {"id": id_c, "success": True}
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
        exito = repo.actualizar_condicion(id_condicion, payload)
        return {"success": exito}
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
        exito = repo.eliminar_condicion(id_condicion)
        return {"success": exito}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))
