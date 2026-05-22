from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException
from app.api.deps import require_roles, UserContext
from app.api.v1.use_cases import (
    obtener_caso_uso_evaluar_reglas, obtener_caso_uso_gestionar_pacientes,
    obtener_caso_uso_generar_plan, obtener_caso_uso_gestionar_ingredientes
)
from app.aplicacion.nutricion.evaluar_reglas_paciente import CasoUsoEvaluarReglasPaciente
from app.aplicacion.clinica.gestionar_pacientes import CasoUsoGestionarPacientes
from app.aplicacion.nutricion.generar_plan_semanal import CasoUsoGenerarPlanSemanal
from app.aplicacion.nutricion.gestionar_ingredientes import CasoUsoGestionarIngredientes
from app.api.v1.dtos.clinico import PacienteRegistroCompleto
from app.api.v1.dtos.nutricion import (
    PlanManualRequest, PlanManualResponse,
    RecetasPermitidasRequest, RecetasPermitidasResponse,
    RecomendacionIngredienteRequest
)
from app.core.db import db_cursor

router = APIRouter(tags=["Nutricionista"])


def _resolver_id_profesional_interno(auth_user_id: str, email: str | None) -> str:
    with db_cursor() as cur:
        cur.execute(
            """
            select id::text
            from usuarios.usuario
            where auth_user_id::text = %s or id::text = %s
            limit 1
            """,
            (auth_user_id, auth_user_id),
        )
        row = cur.fetchone()
        if row and row[0]:
            return row[0]
        if email:
            cur.execute(
                """
                select id::text
                from usuarios.usuario
                where lower(email) = lower(%s)
                limit 1
                """,
                (email,),
            )
            row = cur.fetchone()
            if row and row[0]:
                return row[0]
    raise HTTPException(
        status_code=400,
        detail="No se pudo resolver el profesional autenticado en usuarios.usuario",
    )

@router.post("/ingredientes/recomendar")
def recomendar_ingrediente(
    payload: RecomendacionIngredienteRequest,
    user: UserContext = Depends(require_roles("admin", "nutricionista", "medico")),
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes)
):
    """Registra un ingrediente como seguro/recomendado para un paciente."""
    try:
        # El id_rol depende de si es nutricionista (3) o medico (2)
        role_map = {"admin": 1, "medico": 2, "nutricionista": 3, "tutor": 4}
        rol_id = role_map.get(user.role, 3) 
        id_profesional_interno = _resolver_id_profesional_interno(user.user_id, user.email)
        
        success = caso_uso.recomendar_ingrediente(
            payload.id_paciente,
            payload.id_ingrediente,
            id_profesional_interno,
            rol_id,
            payload.motivo,
            payload.prioridad
        )
        return {"success": success}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.delete("/ingredientes/recomendar/{id_paciente}/{id_ingrediente}")
def eliminar_recomendacion_ingrediente(
    id_paciente: str,
    id_ingrediente: int,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Elimina una recomendación de ingrediente."""
    try:
        success = caso_uso.eliminar_recomendacion(id_paciente, id_ingrediente)
        return {"success": success}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/ingredientes/recomendados/{id_paciente}")
def listar_recomendaciones_ingredientes(
    id_paciente: str,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista", "medico", "tutor"))
):
    """Lista los ingredientes recomendados para un paciente."""
    try:
        return caso_uso.listar_recomendaciones(id_paciente)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/ingredientes/buscar-para-paciente/{id_paciente}")
def buscar_ingredientes_para_paciente(
    id_paciente: str,
    q: str = Query(default=""),
    limit: int = 50,
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """
    Busca ingredientes aplicando filtros inteligentes de alergias y subgrupos prohibidos
    específicamente para un paciente.
    """
    try:
        return caso_uso.buscar_para_paciente(id_paciente, q, limit)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.post("/plan-automatico")
def generar_plan_automatico(
    id_paciente: str, 
    fecha_inicio: date = date.today(),
    caso_uso: CasoUsoGenerarPlanSemanal = Depends(obtener_caso_uso_generar_plan),
    _=Depends(require_roles("admin", "nutricionista"))
):
    try:
        return caso_uso.ejecutar(id_paciente, fecha_inicio)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/paciente/{id_paciente}/evaluar-reglas")
def route_evaluar_reglas(
    id_paciente: str, 
    caso_uso: CasoUsoEvaluarReglasPaciente = Depends(obtener_caso_uso_evaluar_reglas),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    return caso_uso.ejecutar(id_paciente)

@router.get("/buscar-pacientes")
def buscar_pacientes_nutri(
    q: str = Query(default=""), 
    limit: int = 50, 
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    return caso_uso.buscar(q, limit)

@router.post("/gestion-pacientes/registrar")
def registrar_paciente_nutri(
    payload: PacienteRegistroCompleto, 
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico"))
):
    try:
        id_p = caso_uso.registrar_nuevo_paciente(payload.model_dump())
        return {"id": id_p, "success": True}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/nutricion/subgrupos")
def listar_subgrupos_nutricion(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "subgrupo_alimentario")

@router.get("/nutricion/ingredientes")
def listar_ingredientes_nutricion(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "ingrediente")
