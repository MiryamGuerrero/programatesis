from typing import Any, Optional, List, Dict
from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.deps import require_roles, UserContext
from app.api.v1.dependencias import (
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
from app.infraestructura.database.db import db_cursor
from app.infraestructura.repositorios.repositorio_clinico import RepositorioClinicoPostgres
from app.infraestructura.servicios.servicio_oms import ServicioOMS

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

@router.get("/pacientes/cedula/{cedula}/existe")
def verificar_paciente_por_cedula(
    cedula: str,
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    limpia = "".join(ch for ch in str(cedula) if ch.isdigit())
    if len(limpia) != 10:
        return {"existe": False, "cedula": limpia}

    with db_cursor() as cur:
        cur.execute(
            """
            select id::text, nombre_completo::text
            from usuarios.paciente
            where cedula = %s
            limit 1
            """,
            (limpia,),
        )
        row = cur.fetchone()

    if not row:
        return {"existe": False, "cedula": limpia}
    return {
        "existe": True,
        "cedula": limpia,
        "paciente": {"id": row[0], "nombre_completo": row[1]},
    }

@router.get("/pacientes/{id_paciente}/evolucion-resumen")
def evolucion_paciente(
    id_paciente: str, 
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    return caso_uso.obtener_resumen_evolucion(id_paciente)

@router.get("/pacientes/{id_paciente}/evolucion-mensual")
def evolucion_mensual_paciente(
    id_paciente: str,
    fecha_inicio: str | None = Query(default=None),
    fecha_fin: str | None = Query(default=None),
    estado_enfermedad: str | None = Query(default=None),
    en_brote: bool | None = Query(default=None),
    estado_nutricional: str | None = Query(default=None),
    solo_alterados: bool = Query(default=False),
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    return caso_uso.obtener_evolucion_mensual(
        id_paciente,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        estado_enfermedad=estado_enfermedad,
        en_brote=en_brote,
        estado_nutricional=estado_nutricional,
        solo_alterados=solo_alterados,
    )


@router.get("/pacientes/{id_paciente}/consumo-alimentario")
def consumo_alimentario_paciente(
    id_paciente: str,
    dias: int = Query(default=180, ge=1, le=180),
    _=Depends(require_roles("admin", "medico", "nutricionista")),
):
    fecha_fin = date.today()
    fecha_inicio = fecha_fin - timedelta(days=max(dias - 1, 0))

    with db_cursor() as cur:
        cur.execute(
            """
            select
                p.id::text as id_plan,
                p.fecha_inicio,
                p.fecha_fin,
                pi.id::text as id_plan_item,
                pi.fecha_programada as fecha,
                m.nombre as momento,
                m.orden as momento_orden,
                pi.id_receta::text as id_receta,
                coalesce(r.nombre, 'Receta no encontrada') as receta_consumida,
                coalesce(r.nombre, 'Receta no encontrada') as receta_asignada,
                coalesce(r.descripcion, '') as descripcion_receta,
                coalesce(pi.consumida, false) as consumida,
                er.estrellas,
                er.comentario,
                er.id_motivo_rechazo,
                coalesce(cmr.nombre, '') as motivo_rechazo,
                case
                    when coalesce(pi.consumida, false) = true then 'Consumida'
                    when er.estrellas is not null and er.estrellas <= 2 then 'Rechazada'
                    when er.estrellas is null then 'Sin registro'
                    else 'Parcial'
                end as estado_consumo
            from interaccion.plan_nutricional p
            join interaccion.plan_item pi on pi.id_plan = p.id
            join nutricion.momento_comida m on m.id = pi.id_momento
            left join nutricion.receta r on r.id = pi.id_receta
            left join interaccion.evaluacion_receta er
                on er.id_paciente = p.id_paciente
               and er.id_receta = pi.id_receta
            left join interaccion.catalogo_motivo_rechazo cmr
                on cmr.id = er.id_motivo_rechazo
            where p.id_paciente = %s
              and pi.fecha_programada >= %s
              and pi.fecha_programada <= %s
            order by pi.fecha_programada asc, m.orden asc, pi.id asc
            """,
            (id_paciente, fecha_inicio, fecha_fin),
        )
        cols = [d[0] for d in cur.description]
        items = [dict(zip(cols, row)) for row in cur.fetchall()]

    for item in items:
        item["ingredientes"] = []

    if items:
        ids_receta = [item["id_receta"] for item in items if item.get("id_receta")]
        if ids_receta:
            with db_cursor() as cur:
                cur.execute(
                    """
                    select
                        pi.id_receta::text as id_receta,
                        i.nombre as nombre
                    from interaccion.plan_nutricional p
                    join interaccion.plan_item pi on pi.id_plan = p.id
                    join nutricion.receta_ingrediente ri on ri.id_receta = pi.id_receta
                    join nutricion.ingrediente i on i.id = ri.id_ingrediente
                    where p.id_paciente = %s
                      and pi.fecha_programada >= %s
                      and pi.fecha_programada <= %s
                      and coalesce(pi.consumida, false) = true
                    order by i.nombre asc
                    """,
                    (id_paciente, fecha_inicio, fecha_fin),
                )
                ingredientes_por_receta: dict[str, list[dict[str, Any]]] = {}
                for id_receta, nombre in cur.fetchall():
                    ingredientes_por_receta.setdefault(str(id_receta), []).append(
                        {"nombre": nombre}
                    )

            for item in items:
                item["ingredientes"] = ingredientes_por_receta.get(
                    str(item.get("id_receta") or ""),
                    [],
                )

    consumidos = sum(1 for item in items if item.get("consumida") is True)
    total = len(items)
    mala_aceptacion = sum(1 for item in items if int(item.get("estrellas") or 0) <= 2 and item.get("estrellas") is not None)

    ingredientes_contador: dict[str, int] = {}
    for item in items:
        if item.get("consumida") is not True:
            continue
        for ing in item.get("ingredientes") or []:
            nombre = (ing.get("nombre") or "").strip()
            if not nombre:
                continue
            ingredientes_contador[nombre] = ingredientes_contador.get(nombre, 0) + 1

    ingredientes_mas_consumidos = [
        {"nombre": nombre}
        for nombre, _total in sorted(
            ingredientes_contador.items(),
            key=lambda kv: (-kv[1], kv[0].lower()),
        )
    ][:10]

    alertas = []
    for item in items:
        estrellas = item.get("estrellas")
        if estrellas is None:
            continue
        try:
            estrellas_num = int(estrellas)
        except (TypeError, ValueError):
            continue
        if estrellas_num > 2:
            continue
        item_alerta = dict(item)
        item_alerta["motivo_rechazo"] = item_alerta.get("motivo_rechazo") or item_alerta.get("comentario") or "-"
        alertas.append(item_alerta)

    planes_unicos = {}
    for item in items:
        id_plan = item.get("id_plan")
        if not id_plan or id_plan in planes_unicos:
            continue
        planes_unicos[id_plan] = {
            "id_plan": id_plan,
            "fecha_inicio": item.get("fecha_inicio"),
            "fecha_fin": item.get("fecha_fin"),
        }

    adherencia = round((consumidos / total * 100), 2) if total else 0

    return {
        "resumen": {
            "adherencia_porcentaje": adherencia,
            "total_planificado": total,
            "total_consumido": consumidos,
            "total_mala_aceptacion": mala_aceptacion,
            "ingredientes_mas_consumidos": ingredientes_mas_consumidos,
            "alertas_aceptacion": alertas,
        },
        "items": items,
        "planes": list(planes_unicos.values()),
        "periodo": {
            "dias": dias,
            "fecha_inicio": fecha_inicio.isoformat(),
            "fecha_fin": fecha_fin.isoformat(),
        },
    }

@router.get("/pacientes")
def listar_todos_los_pacientes(
    q: Optional[str] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    include_total: bool = Query(default=False),
    caso_uso: CasoUsoGestionarPacientes = Depends(obtener_caso_uso_gestionar_pacientes),
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    if q or limit != 10 or offset != 0 or include_total:
        from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
        repo = RepositorioPacientePostgres()
        return repo.listar_pacientes_paginado(
            q=q,
            limit=limit,
            offset=offset,
            include_total=include_total
        )
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
        msg = str(exc)
        if msg.startswith("__PACIENTE_CEDULA_DUP__"):
            raise HTTPException(
                status_code=409,
                detail=msg.replace("__PACIENTE_CEDULA_DUP__", "", 1),
            )
        raise HTTPException(status_code=400, detail=msg)

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
    limit: int = Query(10, ge=1, le=100),
    offset: int = Query(0, ge=0),
    include_total: bool = Query(False),
    origen: Optional[str] = Query(None, description="CLINICA | TEMPORAL"),
    q: Optional[str] = Query(None, description="Búsqueda por objetivo/mensaje"),
    id_condicion: Optional[int] = Query(None),
    id_accion: Optional[int] = Query(None),
    id_tipo_objetivo: Optional[int] = Query(None),
    id_objetivo: Optional[int] = Query(None),
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Para el médico, filtramos por tipos: 1 (Enfermedad) y 2 (Temporal/Clínica)
    return repo.listar_reglas_detalladas(
        tipos_condicion=[1, 2],
        limite=limit,
        offset=offset,
        include_total=include_total,
        origen_regla=origen,
        q=q,
        id_condicion=id_condicion,
        id_accion=id_accion,
        id_tipo_objetivo=id_tipo_objetivo,
        id_objetivo=id_objetivo
    )

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

@router.get("/reglas-medicas/estadisticas")
def obtener_estadisticas_reglas_medicas(
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    return repo.obtener_estadisticas_medicas()

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

# --- CRUD CATÁLOGO DE CONDICIONES (Standardized Pagination) ---

@router.get("/catalogos/condiciones")
def listar_condiciones_catalogo(
    q: Optional[str] = Query(default=None),
    limit: int = Query(default=10, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    include_total: bool = Query(default=False),
    indicador: Optional[str] = Query(default=None),
    tipo: Optional[int] = Query(default=None),
    _=Depends(require_roles("admin", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    
    # Si se pasan parámetros de paginación o búsqueda, usamos la v2
    if q or limit != 10 or offset != 0 or include_total or indicador or tipo:
        # Los tipos para el médico son 1 (Crónica/Joint) y 2 (Temporal)
        # Si no se especifica tipo, filtramos por ambos
        filtro_tipos = [tipo] if tipo else [1, 2]
        return repo.obtener_catalogo_paginado_v2(
            "heuristico", "condicion",
            q=q,
            limit=limit,
            offset=offset,
            include_total=include_total,
            indicador=indicador,
            filtro_tipos=filtro_tipos
        )
        
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
