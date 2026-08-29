from datetime import date, time, datetime
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import require_roles
from app.core.security import UserContext
from app.api.v1.dependencias import (
    obtener_caso_uso_gestionar_seguimiento,
    obtener_caso_uso_generar_plan
)
from app.aplicacion.nutricion.gestionar_seguimiento import CasoUsoGestionarSeguimiento
from app.aplicacion.nutricion.generar_plan_automatico import CasoUsoGenerarPlanAutomatico
from app.infraestructura.database.db import db_cursor
from app.schemas.v1.tutor import (
    RegistroConsumoRequest, 
    GenerarPlanRequest, 
    IntercambiarRecetaRequest,
    SuccessResponse,
    TipSaludableResponse,
    SubgrupoPreferenciaResponse
)

router = APIRouter(prefix="/tutor", tags=["Tutor"])

@router.get("/mis-pacientes", response_model=List[Dict[str, Any]])
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

@router.get("/subgrupos-preferencia/{id_paciente}", response_model=List[SubgrupoPreferenciaResponse])
def listar_subgrupos_preferencia(id_paciente: str, _=Depends(require_roles("tutor", "admin"))):
    with db_cursor() as cur:
        cur.execute("""
            with conds as (
              select id as id_condicion from heuristico.condicion 
              where activa = true and (indicador_codigo = 'GENERAL_REUMATICOS' or nombre = 'general reumaticos')
              union
              select id_condicion from clinico.diagnostico_paciente where id_paciente = %s::uuid and esta_activo = true
              union
              select cca.id_condicion from clinico.control_condicion_activa cca join clinico.control_paciente cp on cp.id = cca.id_control
              where cp.id_paciente = %s::uuid and cca.esta_activa = true
            ),
            restricciones_bloqueantes as (
              select distinct
                coalesce(
                  cra.etiqueta_bloqueante_codigo,
                  case upper(coalesce(rp.codigo_restriccion, ''))
                    when 'INTOLERANCIA_LACTOSA' then 'NO_APTO_PARA_INTOLERANTES_A_LACTOSA'
                    when 'INTOLERANCIA_GLUTEN' then 'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN'
                    when 'CELIAQUIA' then 'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN'
                    when 'ALERGIA_GLUTEN' then 'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN'
                    when 'INTOLERANCIA_FRUCTOSA' then 'NO_APTO_INTOLERANCIA_FRUCTOSA'
                    when 'INTOLERANCIA_SULFITOS' then 'NO_APTO_PARA_INTOLERANTES_A_SULFITO'
                    when 'ALERGIA_SULFITOS' then 'NO_APTO_PARA_INTOLERANTES_A_SULFITO'
                    when 'VEGETARIANO' then 'NO_APTO_VEGETARIANOS'
                    when 'VEGETARIANA' then 'NO_APTO_VEGETARIANOS'
                    when 'DIABETES' then 'NO_APTO_DIABETICOS'
                    when 'DIABETES_MELLITUS' then 'NO_APTO_DIABETICOS'
                    else null
                  end
                ) as codigo
              from clinico.restriccion_paciente rp
              left join clinico.catalogo_restriccion_alimentaria cra
                on cra.codigo = rp.codigo_restriccion
               and coalesce(cra.activa,false)=true
              where rp.id_paciente = %s::uuid
                and coalesce(rp.activa,false)=true
            ),
            reglas_aplicables as (
              select upper(ca.nombre) as accion, r.id_ingrediente, r.id_subgrupo_alimentario, r.id_grupo_alimentario
              from heuristico.regla r 
              join heuristico.catalogo_accion ca on ca.id = r.id_accion 
              join heuristico.condicion_regla cr on cr.id_regla = r.id
              where cr.id_condicion in (select id_condicion from conds)
            ),
            ingredientes_alergicos as (
              select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s::uuid and activa = true
              union
              select id_ingrediente from reglas_aplicables where accion = 'ELIMINAR' and id_ingrediente is not null
              union
              select ie.id_ingrediente from nutricion.ingrediente_etiqueta ie 
              join nutricion.etiqueta_nutricional en on en.id = ie.id_etiqueta
              where en.codigo in (select codigo from restricciones_bloqueantes where codigo is not null)
            ),
            subgrupos_bloqueados as (
              select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s::uuid and activa = true
              union
              select id_subgrupo_alimentario from reglas_aplicables where accion = 'ELIMINAR' and id_subgrupo_alimentario is not null
              union
              select s.id from nutricion.subgrupo_alimentario s
              join reglas_aplicables ra on ra.id_grupo_alimentario = s.id_grupo_alimentario
              where ra.accion = 'ELIMINAR'
              union
              select distinct i.id_subgrupo_alimentario from nutricion.ingrediente i
              where i.id in (select id_ingrediente from ingredientes_alergicos)
            )
            select s.id, s.nombre, s.emoji, g.nombre as grupo,
                   exists(select 1 from interaccion.preferencia_paciente pp 
                          where pp.id_paciente = %s::uuid and pp.id_subgrupo_alimentario = s.id) as es_preferido
            from nutricion.subgrupo_alimentario s
            join nutricion.grupo_alimentario g on g.id = s.id_grupo_alimentario
            where s.id not in (select id_subgrupo_alimentario from subgrupos_bloqueados where id_subgrupo_alimentario is not null)
            order by g.nombre, s.nombre
        """, (id_paciente, id_paciente, id_paciente, id_paciente, id_paciente, id_paciente))
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

@router.post("/guardar-preferencias", response_model=SuccessResponse)
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
        return SuccessResponse()

@router.post("/marcar-consumida", response_model=SuccessResponse)
def marcar_consumida(payload: Dict[str, Any], _=Depends(require_roles("tutor", "admin"))):
    id_plan_item = payload.get("id_plan_item")
    consumida = bool(payload.get("consumida", True))
    if not id_plan_item:
        raise HTTPException(status_code=400, detail="ID de plan_item requerido")
    from app.infraestructura.repositorios.repositorio_seguimiento import RepositorioSeguimientoPostgres
    repo = RepositorioSeguimientoPostgres()
    ventana = repo.obtener_ventana_consumo(id_plan_item)
    if not ventana:
        raise HTTPException(status_code=404, detail="Plan item no encontrado")
    if not _consumo_dentro_de_horario(ventana, payload.get("fecha"), payload.get("hora")):
        raise HTTPException(
            status_code=409,
            detail="El horario del momento de comida ya venció, no se puede registrar el consumo"
        )
    exito = repo.marcar_item_consumido(id_plan_item, consumida)
    return SuccessResponse(success=exito)

def _parse_hora(value: Any) -> Optional[time]:
    if not isinstance(value, str):
        return None
    try:
        return datetime.strptime(value, "%H:%M").time()
    except ValueError:
        pass
    try:
        return datetime.strptime(value, "%H:%M:%S").time()
    except ValueError:
        return None

def _consumo_dentro_de_horario(ventana: dict, fecha: Any, hora: Any) -> bool:
    """Solo permite marcar/desmarcar consumo dentro de la ventana del momento de comida."""
    if not fecha or not hora:
        return False
    try:
        fecha_cliente = date.fromisoformat(str(fecha))
    except ValueError:
        return False
    if ventana.get("fecha_programada") != fecha_cliente:
        return False
    hora_inicio = ventana.get("hora_inicio")
    hora_fin = ventana.get("hora_fin")
    hora_cliente = _parse_hora(hora)
    if hora_cliente is None or not hora_inicio or not hora_fin:
        return False
    return hora_inicio <= hora_cliente <= hora_fin

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
                comentario = EXCLUDED.comentario
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

@router.get("/momentos-comida")
def listar_momentos(_=Depends(require_roles("tutor", "admin", "nutricionista"))):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    return repo.listar_momentos_comida()

@router.get("/tipos-plato")
def listar_tipos_plato(_=Depends(require_roles("tutor", "admin", "nutricionista"))):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    return repo.listar_tipos_plato()

@router.get("/recetas-seguras/{id_paciente}")
def listar_recetas_seguras(
    id_paciente: str,
    consulta: str = Query(default=""),
    id_momento: int | None = Query(default=None),
    id_tipo_plato: int | None = Query(default=None),
    limite: int = Query(default=20),
    offset: int = Query(default=0),
    _=Depends(require_roles("tutor", "admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    return repo.obtener_recetas_seguras_para_paciente(
        id_paciente=id_paciente,
        id_momento=id_momento,
        id_tipo_plato=id_tipo_plato,
        consulta=consulta,
        limite=limite,
        offset=offset
    )

@router.get("/lista-compras/{id_paciente}")
def obtener_lista_compras(
    id_paciente: str,
    fecha_inicio: date = date.today(),
    fecha_fin: date = date.today(),
    caso_uso: CasoUsoGestionarSeguimiento = Depends(obtener_caso_uso_gestionar_seguimiento),
    _=Depends(require_roles("tutor", "admin"))
):
    return caso_uso.obtener_lista_compras(id_paciente, fecha_inicio, fecha_fin)

@router.post("/generar-plan-automatico")
def generar_plan_automatico(
    request: GenerarPlanRequest,
    user: UserContext = Depends(require_roles("tutor", "admin")),
    caso_uso: CasoUsoGenerarPlanAutomatico = Depends(obtener_caso_uso_generar_plan)
):
    try:
        def simple_logger(msg: str):
            print(f"[GEN_PLAN] {msg}")

        return caso_uso.ejecutar_tutor(
            id_paciente=request.id_paciente,
            dias=request.dias,
            fecha_inicio=request.fecha_inicio,
            momentos_obligatorios=request.momentos_obligatorios,
            momentos_opcionales=request.momentos_opcionales,
            log_callback=simple_logger
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/intercambiar-receta-plan")
def intercambiar_receta_plan(
    request: IntercambiarRecetaRequest,
    user: UserContext = Depends(require_roles("tutor", "admin")),
    caso_uso: CasoUsoGenerarPlanAutomatico = Depends(obtener_caso_uso_generar_plan)
):
    try:
        return caso_uso.intercambiar_receta(request.id_plan_item)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/tips-saludables", response_model=TipSaludableResponse)
def obtener_tip_saludable(_=Depends(require_roles("tutor", "admin"))):
    import random
    tips = [
        {"mensaje": "Pequeñas **decisiones** hoy, grandes **cambios** mañana.", "categoria": "crecimiento"},
        {"mensaje": "La **hidratación** es la clave para un cuerpo con **energía**.", "categoria": "agua"},
        {"mensaje": "Prefiere **alimentos naturales**, tu cuerpo te lo **agradecerá**.", "categoria": "nutricion"},
        {"mensaje": "**Camina** 30 minutos al día para un **corazón** fuerte.", "categoria": "ejercicio"},
        {"mensaje": "El **descanso** es tan importante como el **ejercicio**.", "categoria": "descanso"},
        {"mensaje": "Añade **colores** a tu plato con **frutas** y verduras.", "categoria": "nutricion"},
        {"mensaje": "**Masticar** despacio mejora tu **digestión** notablemente.", "categoria": "habito"},
        {"mensaje": "La **constancia** vence a la **perfección** siempre.", "categoria": "mente"},
        {"mensaje": "Reduce el **azúcar**, aumenta tu **vitalidad** diaria.", "categoria": "salud"},
        {"mensaje": "**Cocinar** en casa es el primer paso hacia la **salud**.", "categoria": "hogar"},
        {"mensaje": "**Escucha** a tu cuerpo, él sabe lo que **necesita**.", "categoria": "bienestar"},
        {"mensaje": "Un **desayuno nutritivo** activa tu **mente** temprano.", "categoria": "energia"},
        {"mensaje": "La **salud mental** es parte esencial del **bienestar**.", "categoria": "mente"},
        {"mensaje": "Evita **ultraprocesados** para mantener tu **inflamación** baja.", "categoria": "clinico"},
        {"mensaje": "**Snacks saludables**: nueces, frutas y mucha **agua**.", "categoria": "nutricion"},
        {"mensaje": "El **sol** es fuente vital de **vitamina D**.", "categoria": "naturaleza"},
        {"mensaje": "**Estirarse** al despertar prepara tus **músculos** mejor.", "categoria": "ejercicio"},
        {"mensaje": "Menos **sal**, más **sabor** con especias naturales.", "categoria": "habito"},
        {"mensaje": "La **fibra** es el mejor amigo de tu **intestino**.", "categoria": "nutricion"},
        {"mensaje": "Cada **paso** cuenta en tu camino al **bienestar**.", "categoria": "crecimiento"}
    ]
    return TipSaludableResponse(**random.choice(tips))
