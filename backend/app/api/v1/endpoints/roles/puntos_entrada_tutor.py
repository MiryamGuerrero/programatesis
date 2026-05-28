from datetime import date
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import require_roles
from app.core.security import UserContext
from app.api.v1.use_cases import obtener_caso_uso_gestionar_seguimiento
from app.aplicacion.nutricion.gestionar_seguimiento import CasoUsoGestionarSeguimiento
from app.core.db import db_cursor
from pydantic import BaseModel

router = APIRouter(prefix="/tutor", tags=["Tutor"])

class RegistroConsumoRequest(BaseModel):
    id_plan_item: int
    id_estado_consumo: int
    observacion: str | None = None

@router.get("/mis-pacientes")
def obtener_mis_pacientes(
    user: UserContext = Depends(require_roles("tutor", "admin")),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento)
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.listar_pacientes_por_tutor(user.user_id)

@router.get("/verificar-onboarding/{id_paciente}")
def verificar_onboarding(id_paciente: str, _=Depends(require_roles("tutor", "admin"))):
    with db_cursor() as cur:
        cur.execute("SELECT preferencias_configuradas FROM usuarios.paciente WHERE id = %s", (id_paciente,))
        res = cur.fetchone()
        return {"configuradas": res[0] if res else False}

@router.get("/subgrupos-preferencia/{id_paciente}")
def listar_subgrupos_preferencia(id_paciente: str, _=Depends(require_roles("tutor", "admin"))):
    with db_cursor() as cur:
        cur.execute("""
            select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo 
            where id_paciente = %s and activa = true
        """, (id_paciente,))
        bloqueados = [r[0] for r in cur.fetchall()]

        cur.execute("""
            select s.id, s.nombre, s.emoji, g.nombre as grupo,
                   exists(select 1 from interaccion.preferencia_paciente pp 
                          where pp.id_paciente = %s and pp.id_subgrupo_alimentario = s.id) as es_preferido
            from nutricion.subgrupo_alimentario s
            join nutricion.grupo_alimentario g on g.id = s.id_grupo_alimentario
            order by g.nombre, s.nombre
        """, (id_paciente,))
        cols = [d[0] for d in cur.description]
        todos = [dict(zip(cols, row)) for row in cur.fetchall()]
        return [s for s in todos if s['id'] not in bloqueados]

@router.post("/guardar-preferencias")
def guardar_preferencias(payload: Dict[str, Any], _=Depends(require_roles("tutor", "admin"))):
    id_paciente = payload.get("id_paciente")
    subgrupos_ids = payload.get("subgrupos_ids", [])
    if not id_paciente:
        raise HTTPException(status_code=400, detail="ID de paciente requerido")
    with db_cursor() as cur:
        cur.execute("DELETE FROM interaccion.preferencia_paciente WHERE id_paciente = %s", (id_paciente,))
        if subgrupos_ids:
            values = [(id_paciente, sid) for sid in subgrupos_ids]
            cur.executemany("INSERT INTO interaccion.preferencia_paciente (id_paciente, id_subgrupo_alimentario) VALUES (%s, %s)", values)
        cur.execute("UPDATE usuarios.paciente SET preferencias_configuradas = true WHERE id = %s", (id_paciente,))
        return {"success": True}

@router.post("/marcar-consumida")
def marcar_consumida(payload: Dict[str, Any], _=Depends(require_roles("tutor", "admin"))):
    id_plan_item = payload.get("id_plan_item")
    consumida = bool(payload.get("consumida", True))
    if not id_plan_item:
        raise HTTPException(status_code=400, detail="ID de plan_item requerido")
    from app.infraestructura.repositorios.repositorio_seguimiento import RepositorioSeguimientoPostgres
    repo = RepositorioSeguimientoPostgres()
    exito = repo.marcar_item_consumido(id_plan_item, consumida)
    return {"success": exito}

@router.get("/plan-diario/{id_paciente}")
def obtener_plan_diario(
    id_paciente: str,
    fecha: date = date.today(),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_plan_del_dia(id_paciente, fecha)

@router.get("/dias-con-plan/{id_paciente}")
def obtener_dias_con_plan(
    id_paciente: str,
    mes: int = Query(...),
    anio: int = Query(...),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_dias_con_plan(id_paciente, mes, anio)

@router.get("/receta-detalle/{id_receta}")
def obtener_detalle_tutor(
    id_receta: int,
    id_paciente: str | None = Query(default=None),
    _=Depends(require_roles("tutor", "admin"))
):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    res = repo.obtener_detalle_completo(id_receta, id_paciente)
    if not res:
        raise HTTPException(status_code=404, detail="Receta no encontrada")
    return res

@router.get("/motivos-rechazo")
def listar_motivos_rechazo(_=Depends(require_roles("tutor", "admin"))):
    with db_cursor() as cur:
        cur.execute("SELECT id, nombre FROM interaccion.catalogo_motivo_rechazo ORDER BY id")
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

@router.post("/evaluar-receta")
def evaluar_receta(payload: Dict[str, Any], _=Depends(require_roles("tutor", "admin"))):
    id_paciente = payload.get("id_paciente")
    id_receta = payload.get("id_receta")
    estrellas = payload.get("estrellas")
    id_motivo = payload.get("id_motivo_rechazo")
    comentario = payload.get("comentario")
    
    if not id_paciente or not id_receta or not estrellas:
        raise HTTPException(status_code=400, detail="Faltan datos obligatorios")

    with db_cursor() as cur:
        cur.execute("""
            INSERT INTO interaccion.evaluacion_receta 
                (id_paciente, id_receta, estrellas, id_motivo_rechazo, comentario, origen_evaluacion)
            VALUES (%s, %s, %s, %s, %s, 'App Móvil')
            ON CONFLICT (id_paciente, id_receta) 
            DO UPDATE SET 
                estrellas = EXCLUDED.estrellas,
                id_motivo_rechazo = EXCLUDED.id_motivo_rechazo,
                comentario = EXCLUDED.comentario,
                updated_at = NOW()
        """, (id_paciente, id_receta, estrellas, id_motivo, comentario))
        return {"success": True}

@router.post("/registrar-consumo")
def registrar_consumo(
    payload: RegistroConsumoRequest,
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    try:
        exito = caso_uso.registrar_comida_consumida(payload.model_dump())
        return {"success": exito}
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

@router.get("/adherencia/{id_paciente}")
def obtener_estadisticas_adherencia(
    id_paciente: str,
    dias: int = Query(default=7, ge=1, le=30),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_estadisticas_adherencia(id_paciente, dias)

@router.get("/lista-compras/{id_paciente}")
def obtener_lista_compras(
    id_paciente: str,
    fecha_inicio: date = date.today(),
    fecha_fin: date = date.today(),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_lista_compras(id_paciente, fecha_inicio, fecha_fin)
