from fastapi import APIRouter, Depends, Query, HTTPException
from datetime import date, datetime
from app.api.deps import require_roles
from app.core.security import UserContext
from app.api.v1.dependencias import (
    obtener_caso_uso_gestionar_ingredientes, 
    obtener_caso_uso_gestionar_catalogos,
    obtener_caso_uso_evaluar_reglas
)
from app.api.v1.dtos.nutricion import RecetasPermitidasRequest, RecetasPermitidasResponse
from app.aplicacion.nutricion.gestionar_ingredientes import CasoUsoGestionarIngredientes
from app.aplicacion.clinica.gestionar_catalogos import CasoUsoGestionarCatalogos
from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
from app.api.v1.simple_cache import cached

router = APIRouter(tags=["Compatibilidad"])


def _asegurar_tabla_validacion_nutri(cur) -> None:
    cur.execute(
        """
        create table if not exists clinico.validacion_control_nutricional_mensual (
            id bigserial primary key,
            id_control bigint not null,
            id_paciente uuid not null,
            anio integer not null,
            mes integer not null,
            confirmado boolean not null default true,
            fecha_confirmacion timestamp without time zone not null default now(),
            unique (id_control, anio, mes)
        )
        """
    )

@router.get("/pacientes/{id_paciente}/planes")
def obtener_planes_paciente(
    id_paciente: str,
    _=Depends(require_roles("admin", "nutricionista", "medico", "tutor"))
):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            """
            select column_name
            from information_schema.columns
            where table_schema = 'interaccion'
              and table_name = 'plan_nutricional'
            """
        )
        cols_plan = {r[0] for r in cur.fetchall()}
        objetivo_col = "p.objetivo" if "objetivo" in cols_plan else "NULL::text as objetivo"
        tipo_plan_col = "tp.nombre" if "id_tipo_plan" in cols_plan else "'MANUAL'::text"
        origen_plan_col = "op.nombre" if "id_origen_plan" in cols_plan else "'NUTRICIONISTA'::text"
        comidas_col = "p.comidas_por_dia" if "comidas_por_dia" in cols_plan else "NULL::int as comidas_por_dia"

        cur.execute(
            f"""
            select
                p.id,
                p.id_paciente,
                p.fecha_inicio,
                p.fecha_fin,
                p.vigente,
                {objetivo_col},
                {tipo_plan_col} as tipo_plan,
                {origen_plan_col} as origen_plan,
                {comidas_col},
                p.created_at,
                count(pi.id) as total_items,
                count(pi.id) filter (where coalesce(pi.consumida, false) = true) as consumidos,
                case 
                    when count(pi.id) > 0 then round((count(pi.id) filter (where coalesce(pi.consumida, false) = true)::numeric / count(pi.id)) * 100, 2) 
                    else 0 
                end as porcentaje_adherencia
            from interaccion.plan_nutricional p
            left join interaccion.plan_item pi on pi.id_plan = p.id
            left join interaccion.catalogo_tipo_plan tp on tp.id = p.id_tipo_plan
            left join interaccion.catalogo_origen_plan op on op.id = p.id_origen_plan
            where p.id_paciente = %s
            group by p.id, tp.nombre, op.nombre
            order by p.created_at desc nulls last, p.id desc
            """,
            (id_paciente,),
        )
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


@router.get("/planes/{id_plan}")
def obtener_detalle_plan(id_plan: int, _=Depends(require_roles("admin", "nutricionista", "medico", "tutor"))):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            """
            select
                pi.fecha_programada as fecha,
                pi.id_momento,
                pi.id_receta,
                r.nombre as nombre_receta,
                r.imagen_url as imagen_url
            from interaccion.plan_item pi
            join nutricion.receta r on r.id = pi.id_receta
            where pi.id_plan = %s
            order by pi.fecha_programada, pi.id_momento, pi.id
            """,
            (id_plan,),
        )
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


@router.delete("/planes/{id_plan}")
def eliminar_plan(id_plan: int, _=Depends(require_roles("admin", "nutricionista", "medico"))):
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "delete from interaccion.seguimiento_plan_item where id_plan_item in (select id from interaccion.plan_item where id_plan = %s)",
            (id_plan,),
        )
        cur.execute("delete from interaccion.plan_item where id_plan = %s", (id_plan,))
        cur.execute("delete from interaccion.plan_nutricional where id = %s", (id_plan,))
        return {"success": cur.rowcount > 0}

@router.put("/pacientes/{id_paciente}/control-mensual-actual")
def actualizar_control_mensual_actual_desde_nutri(
    id_paciente: str,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    from app.infraestructura.database.db import db_cursor
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    hoy = date.today()

    with db_cursor() as cur:
        _asegurar_tabla_validacion_nutri(cur)
        cur.execute(
            """
            select id, peso_kg, talla_cm, puntos_dolor, escala_inflamacion,
                   nivel_fatiga, articulaciones_inflamadas, articulaciones_dolorosas, minutos_rigidez,
                   en_brote, estado_enfermedad, nota_evolucion, fecha_proxima_cita
            from clinico.control_paciente
            where id_paciente = %s
            order by fecha_control desc, id desc
            limit 1
            """,
            (id_paciente,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="No existe control mensual para este paciente")

        id_control = row[0]
        datos = {
            "peso_kg": payload.get("peso_kg", row[1]),
            "talla_cm": payload.get("talla_cm", row[2]),
            "puntos_dolor": payload.get("puntos_dolor", row[3]),
            "escala_inflamacion": payload.get("escala_inflamacion", row[4]),
            "fatiga": payload.get("fatiga", row[5]),
            "articulaciones_inflamadas": payload.get("articulaciones_inflamadas", row[6]),
            "articulaciones_dolorosas": payload.get("articulaciones_dolorosas", row[7]),
            "minutos_rigidez": payload.get("minutos_rigidez", row[8]),
            "en_brote": payload.get("en_brote", row[9]),
            "estado_enfermedad": payload.get("estado_enfermedad", row[10]),
            "nota_evolucion": payload.get("nota_evolucion", row[11]),
            "fecha_proxima_cita": payload.get("fecha_proxima_cita", row[12]),
            "id_condicion_nutricional_peso": payload.get("id_condicion_nutricional_peso"),
            "id_condicion_nutricional_talla": payload.get("id_condicion_nutricional_talla"),
            "condiciones_temporales": payload.get("condiciones_temporales", []),
            "recomendaciones_ingredientes": payload.get("recomendaciones_ingredientes", []),
        }

    repo = RepositorioPacientePostgres()
    ok = repo.actualizar_control_mensual_especifico(id_control, datos)
    with db_cursor() as cur:
        _asegurar_tabla_validacion_nutri(cur)
        cur.execute(
            """
            insert into clinico.validacion_control_nutricional_mensual
            (id_control, id_paciente, anio, mes, confirmado)
            values (%s, %s, %s, %s, true)
            on conflict (id_control, anio, mes)
            do update set confirmado = true, fecha_confirmacion = now()
            """,
            (id_control, id_paciente, hoy.year, hoy.month),
        )
    return {"success": ok, "id_control": id_control}


@router.get("/pacientes/{id_paciente}/control-mensual-actual/estado-validacion")
def obtener_estado_validacion_control_mensual(
    id_paciente: str,
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    hoy = date.today()
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        _asegurar_tabla_validacion_nutri(cur)
        cur.execute(
            """
            select id
            from clinico.control_paciente
            where id_paciente = %s
            order by fecha_control desc, id desc
            limit 1
            """,
            (id_paciente,),
        )
        row_control = cur.fetchone()
        if not row_control:
            return {"mostrar_modal": False, "motivo": "sin_control_mensual"}
        id_control = row_control[0]

        cur.execute(
            """
            select confirmado
            from clinico.validacion_control_nutricional_mensual
            where id_control = %s and anio = %s and mes = %s
            limit 1
            """,
            (id_control, hoy.year, hoy.month),
        )
        row_validado = cur.fetchone()
        confirmado = bool(row_validado and row_validado[0] is True)
        return {
            "mostrar_modal": not confirmado,
            "id_control": id_control,
            "anio": hoy.year,
            "mes": hoy.month,
            "confirmado": confirmado,
        }


@router.get("/pacientes/{id_paciente}/prefetch-planificacion")
def prefetch_planificacion_paciente(
    id_paciente: str,
    include_ingredientes: bool = Query(default=False),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """
    Precarga en una sola llamada lo necesario para plan manual:
    - estado de validación nutricional
    - diagnóstico y expediente mínimo
    - ingredientes seguros
    - ingredientes recomendados (potenciadores)
    - condiciones separadas por peso/talla para la validación clínica
    """
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    from app.infraestructura.repositorios.repositorio_ingrediente import RepositorioIngredientePostgres
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    from app.infraestructura.database.db import db_cursor

    expediente = RepositorioPacientePostgres().obtener_expediente_completo(id_paciente)
    estado_validacion = obtener_estado_validacion_control_mensual(id_paciente)

    plan_vigente = None
    with db_cursor() as cur:
        cur.execute(
            """
            select
                p.id,
                p.fecha_inicio::text,
                p.fecha_fin::text,
                p.vigente,
                coalesce(ctp.nombre, p.id_tipo_plan::text, 'MANUAL') as tipo_plan,
                coalesce(cop.nombre, p.id_origen_plan::text, 'NUTRICIONISTA') as origen_plan,
                p.comidas_por_dia,
                p.created_at::text
            from interaccion.plan_nutricional p
            left join interaccion.catalogo_tipo_plan ctp on ctp.id = p.id_tipo_plan
            left join interaccion.catalogo_origen_plan cop on cop.id = p.id_origen_plan
            where p.id_paciente = %s
              and coalesce(p.vigente, false) = true
            order by p.created_at desc nulls last, p.id desc
            limit 1
            """,
            (id_paciente,),
        )
        row_plan = cur.fetchone()
        if row_plan:
            plan_vigente = dict(zip([d[0] for d in cur.description], row_plan))

    ingredientes_seguros = []
    ingredientes_recomendados = []
    if include_ingredientes:
        repo_ing = RepositorioIngredientePostgres()
        ingredientes_seguros = repo_ing.buscar_ingredientes_filtrados(id_paciente, consulta="", limite=300)
        ingredientes_recomendados = repo_ing.listar_recomendaciones_paciente(id_paciente)

    condiciones = RepositorioPerfilPostgres().obtener_catalogo("heuristico", "condicion", filtro_tipos=[3])
    condiciones_peso = []
    condiciones_talla = []
    for c in condiciones:
        nombre = (c.get("nombre") or "").lower()
        if ("peso" in nombre) or ("sobrepeso" in nombre) or ("obes" in nombre):
            condiciones_peso.append(c)
        if ("talla" in nombre) or ("estatura" in nombre):
            condiciones_talla.append(c)

    if not condiciones_peso:
        condiciones_peso = condiciones
    if not condiciones_talla:
        condiciones_talla = condiciones

    return {
        "estado_validacion": estado_validacion,
        "expediente": expediente,
        "diagnostico": expediente.get("diagnostico") if isinstance(expediente, dict) else {},
        "plan_vigente": plan_vigente,
        "ingredientes_seguros": ingredientes_seguros,
        "ingredientes_recomendados": ingredientes_recomendados,
        "condiciones": {
            "peso": condiciones_peso,
            "talla": condiciones_talla,
        },
    }


@router.post("/pacientes/{id_paciente}/control-mensual-actual/confirmar")
def confirmar_control_mensual_actual(
    id_paciente: str,
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    hoy = date.today()
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        _asegurar_tabla_validacion_nutri(cur)
        cur.execute(
            """
            select id
            from clinico.control_paciente
            where id_paciente = %s
            order by fecha_control desc, id desc
            limit 1
            """,
            (id_paciente,),
        )
        row_control = cur.fetchone()
        if not row_control:
            raise HTTPException(status_code=404, detail="No existe control mensual para este paciente")
        id_control = row_control[0]
        cur.execute(
            """
            insert into clinico.validacion_control_nutricional_mensual
            (id_control, id_paciente, anio, mes, confirmado)
            values (%s, %s, %s, %s, true)
            on conflict (id_control, anio, mes)
            do update set confirmado = true, fecha_confirmacion = now()
            """,
            (id_control, id_paciente, hoy.year, hoy.month),
        )
        return {"success": True, "id_control": id_control, "anio": hoy.year, "mes": hoy.month}

@router.get("/etiquetas-lista")
def etiquetas_lista_compat(
    caso_uso: CasoUsoGestionarCatalogos = Depends(obtener_caso_uso_gestionar_catalogos),
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    return caso_uso.obtener_maestro("nutricion", "etiqueta_nutricional")

@router.get("/buscar-pacientes")
def buscar_pacientes_compat(
    q: str = Query(default=""),
    limit: int = 50,
    _=Depends(require_roles("admin", "medico", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.buscar_pacientes(q, limit)

@router.get("/gestion-pacientes/buscar")
def gestion_pacientes_buscar_compat(q: str = Query(default="")):
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    return repo.buscar_pacientes(q, 50)

@router.get("/reglas-nutricionales")
def reglas_nutricionales_compat(
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Filtramos para que el nutricionista solo vea condiciones Nutricionales (3)
    return repo.listar_reglas_detalladas(tipos_condicion=[3])

@router.get("/reglas-nutricionales/form-data")
@cached(ttl=30)
def reglas_form_data_compat(
    compact: bool = Query(default=False, description="Si true, devuelve solo metadatos ligeros para carga inicial"),
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Solo Nutricionales (3)
    condiciones = repo.obtener_catalogo("heuristico", "condicion", filtro_tipos=[3])
    acciones = repo.obtener_catalogo("heuristico", "catalogo_accion")
    objetivos = repo.obtener_catalogo("heuristico", "catalogo_objetivo_regla")

    if compact:
        # Respuesta reducida para carga inicial: evitar payloads grandes (ingredientes, grupos)
        return {
            "condiciones": condiciones,
            "acciones": acciones,
            "objetivos": objetivos,
        }

    # Respuesta completa (por defecto)
    return {
        "condiciones": condiciones,
        "acciones": acciones,
        "objetivos": objetivos,
        "ingredientes": repo.obtener_catalogo("nutricion", "ingrediente"),
        "grupos": repo.obtener_catalogo("nutricion", "grupo_alimentario"),
        "subgrupos": repo.obtener_catalogo("nutricion", "subgrupo_alimentario"),
        "etiquetas": repo.obtener_catalogo("nutricion", "etiqueta_nutricional")
    }

@router.post("/reglas-nutricionales")
def guardar_nueva_regla_nutri(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Forzamos el origen como NUTRICIONAL
    payload["origen_regla"] = "NUTRICIONAL"
    id_regla = repo.guardar_regla(payload)
    return {"id": id_regla, "success": True}

@router.put("/reglas-nutricionales/{id_regla}")
def actualizar_regla_nutri(
    id_regla: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    # Mantenemos el origen como NUTRICIONAL en las actualizaciones
    payload["origen_regla"] = "NUTRICIONAL"
    exito = repo.actualizar_regla(id_regla, payload)
    return {"success": exito}

@router.delete("/reglas-nutricionales/{id_regla}")
def eliminar_regla_nutri(
    id_regla: int,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_regla import RepositorioReglaPostgres
    repo = RepositorioReglaPostgres()
    repo.eliminar_regla(id_regla)
    return {"success": True}

@router.get("/ingredientes-lista")
def ingredientes_lista_compat(
    q: str = Query(default=""),
    cat: int = Query(default=None),
    subcat: int = Query(default=None),
    limit: int = Query(default=10),
    offset: int = Query(default=0),
    caso_uso: CasoUsoGestionarIngredientes = Depends(obtener_caso_uso_gestionar_ingredientes),
    _=Depends(require_roles("admin", "nutricionista", "medico", "tutor"))
):
    """Soporte para la tabla principal de ingredientes con datos enriquecidos."""
    # Obtener ingredientes con filtros aplicados directamente en el caso de uso
    items_filtrados = caso_uso.listar_ingredientes(
        consulta=q, 
        limite=limit, 
        desplazamiento=offset,
        id_grupo=cat,
        id_subgrupo=subcat
    )
    
    # Para el total, como PaginatedDataTable lo necesita, hacemos una consulta rápida o estimada
    # En este caso, para no complicar el repo, podemos retornar un total aproximado o el tamaño de la lista si es menor al limite
    total = 0
    if len(items_filtrados) < limit and offset == 0:
        total = len(items_filtrados)
    else:
        # Si hay más, asumimos un número alto o implementamos un count en el repo
        # Por ahora, para que la paginación funcione, retornamos el offset + items + 1 si está lleno
        total = offset + len(items_filtrados) + (1 if len(items_filtrados) == limit else 0)

    total = caso_uso.contar_ingredientes(
        consulta=q,
        id_grupo=cat,
        id_subgrupo=subcat,
    )

    return {
        "items": items_filtrados,
        "total": total
    }

@router.get("/paciente-perfil/{id_paciente}")
def obtener_perfil_detallado_paciente(
    id_paciente: str,
    _=Depends(require_roles("admin", "nutricionista", "medico", "tutor"))
):
    """Retorna la ficha clínica completa para el planificador manual."""
    from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
    repo = RepositorioPacientePostgres()
    # Mock de datos para la prueba, en real vendría de una consulta join
    return {
        "id": id_paciente,
        "nombre": "Paciente de Prueba",
        "sexo": "Masc",
        "nutricional": "Normal",
        "clinico": "AIJ",
        "temporal": "Ninguna",
        "alergias": "Maní, Gluten",
        "reglas_clinicas": ["Evitar Inflamatorios"],
        "reglas_nutricionales": ["Bajo en Sodio"]
    }

@router.post("/recetas-permitidas", response_model=RecetasPermitidasResponse)
def listar_recetas_seguras(
    payload: RecetasPermitidasRequest,
    _=Depends(require_roles("admin", "nutricionista", "medico", "tutor"))
):
    """
    Motor de Inferencia KBRS - Heurística de Exclusión y Priorización.
    Filtra recetas prohibidas y destaca las potenciadas por recomendaciones médicas/nutricionales.
    """
    id_paciente = payload.id_paciente
    id_momento = payload.id_momento
    id_tipo_plato = payload.id_tipo_plato
    limite = payload.limite
    offset = payload.offset
    
    if not id_paciente:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="ID de paciente requerido")

    # Usamos el nuevo método del repositorio que centraliza la lógica de filtrado y potenciación
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo_receta = RepositorioRecetaPostgres()
    
    try:
        permitidas = repo_receta.obtener_recetas_seguras_para_paciente(
            id_paciente, 
            int(id_momento) if id_momento else None,
            int(id_tipo_plato) if id_tipo_plato else None,
            consulta=payload.consulta,
            limite=limite,
            offset=offset
        )
        
        # Formateamos la respuesta para incluir el mensaje de recomendación
        for r in permitidas:
            if r.get("es_potenciada"):
                r["recomendacion"] = "POTENCIADA: Contiene ingredientes recomendados para su salud"
            else:
                r["recomendacion"] = "Segura para el paciente"
                
        return {"id_paciente": id_paciente, "recetas": permitidas}
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/recetas-permitidas/tipos-disponibles")
def listar_tipos_disponibles_recetas_seguras(
    id_paciente: str,
    id_momento: int | None = None,
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    if not id_paciente:
        raise HTTPException(status_code=400, detail="ID de paciente requerido")
    repo_receta = RepositorioRecetaPostgres()
    return repo_receta.listar_tipos_plato_disponibles_para_paciente(
        id_paciente=id_paciente,
        id_momento=id_momento,
    )

@router.post("/plan-manual")
def guardar_plan_manual(
    payload: dict,
    user: UserContext = Depends(require_roles("admin", "nutricionista"))
):
    """Guarda plan y potenciadores; opcionalmente confirma/actualiza el control mensual actual."""
    id_paciente = payload.get("id_paciente")
    boosters = payload.get("boosters", []) # IDs de ingredientes recomendados para este plan
    plan_items = payload.get("plan", [])
    confirmar_control = bool(payload.get("confirmar_control_mensual", False))
    datos_control = payload.get("control_mensual_actual") or {}
    
    if confirmar_control:
        from app.infraestructura.database.db import db_cursor
        from app.infraestructura.repositorios.repositorio_paciente import RepositorioPacientePostgres
        with db_cursor() as cur_control:
            cur_control.execute(
                """
                select id
                from clinico.control_paciente
                where id_paciente = %s
                order by fecha_control desc, id desc
                limit 1
                """,
                (id_paciente,),
            )
            row_control = cur_control.fetchone()

        repo_paciente = RepositorioPacientePostgres()
        if row_control:
            repo_paciente.actualizar_control_mensual_especifico(row_control[0], datos_control)
        else:
            repo_paciente.registrar_control_mensual(
                id_paciente=id_paciente,
                datos=datos_control,
                id_medico=user.user_id,
            )

    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        # Resolver usuario interno para trazabilidad y FKs de recomendaciones
        id_profesional_interno = None
        cur.execute(
            """
            select id
            from usuarios.usuario
            where auth_user_id::text = %s or id::text = %s
            limit 1
            """,
            (user.user_id, user.user_id),
        )
        row_user = cur.fetchone()
        if row_user:
            id_profesional_interno = row_user[0]
        else:
            cur.execute(
                """
                select id
                from usuarios.usuario
                where lower(email) = lower(%s)
                limit 1
                """,
                (user.email or "",),
            )
            row_user = cur.fetchone()
            if row_user:
                id_profesional_interno = row_user[0]

        id_plan = None
        if plan_items:
            # Regla de seguridad nutricional para semáforo amarillo:
            # 1) máximo 2 veces por semana
            # 2) nunca en días consecutivos
            amarillos_por_receta: dict[int, list[date]] = {}
            for i in plan_items:
                if str(i.get("semaforo", "")).lower() != "amarillo":
                    continue
                rid = int(i.get("id_receta") or 0)
                if rid <= 0:
                    continue
                f = datetime.fromisoformat(str(i.get("fecha"))).date()
                amarillos_por_receta.setdefault(rid, []).append(f)

            for rid, fechas in amarillos_por_receta.items():
                fechas_orden = sorted(set(fechas))
                # no consecutivos
                for idx in range(1, len(fechas_orden)):
                    if (fechas_orden[idx] - fechas_orden[idx - 1]).days == 1:
                        raise HTTPException(
                            status_code=400,
                            detail=f"La receta {rid} (amarilla) no puede estar en días consecutivos.",
                        )
                # máximo 2 por semana ISO
                conteo_semana: dict[tuple[int, int], int] = {}
                for f in fechas_orden:
                    yw = f.isocalendar()
                    key = (yw.year, yw.week)
                    conteo_semana[key] = conteo_semana.get(key, 0) + 1
                    if conteo_semana[key] > 2:
                        raise HTTPException(
                            status_code=400,
                            detail=f"La receta {rid} (amarilla) supera 2 veces en la misma semana.",
                        )

            fechas = sorted(
                {
                    str(i.get("fecha"))
                    for i in plan_items
                    if i.get("fecha") is not None
                }
            )
            if not fechas:
                raise HTTPException(status_code=400, detail="El plan no contiene fechas válidas")

            cur.execute(
                """
                select column_name
                from information_schema.columns
                where table_schema = 'interaccion'
                  and table_name = 'plan_nutricional'
                """
            )
            cols_plan = {r[0] for r in cur.fetchall()}
            cols = ["id_paciente", "fecha_inicio", "fecha_fin", "vigente"]
            vals = [id_paciente, fechas[0], fechas[-1], True]
            if "creado_por" in cols_plan and id_profesional_interno is not None:
                cols.append("creado_por")
                vals.append(id_profesional_interno)
            if "tipo_plan" in cols_plan:
                cols.append("tipo_plan")
                vals.append("MANUAL")
            if "id_tipo_plan" in cols_plan:
                id_tipo_plan = payload.get("id_tipo_plan")
                if not id_tipo_plan:
                    cur.execute(
                        """
                        select c.column_name
                        from information_schema.columns c
                        where c.table_schema = 'interaccion'
                          and c.table_name in ('catalogo_tipo_plan', 'tipo_plan')
                        limit 1
                        """
                    )
                    has_catalog = cur.fetchone()
                    if has_catalog:
                        try:
                            cur.execute(
                                """
                                select id from interaccion.catalogo_tipo_plan
                                where upper(nombre) in ('MANUAL', 'PLAN MANUAL')
                                order by id
                                limit 1
                                """
                            )
                            row_tipo = cur.fetchone()
                            if not row_tipo:
                                cur.execute("select min(id) from interaccion.catalogo_tipo_plan")
                                row_tipo = cur.fetchone()
                            if row_tipo and row_tipo[0] is not None:
                                id_tipo_plan = int(row_tipo[0])
                        except Exception:
                            cur.execute(
                                """
                                select id from interaccion.tipo_plan
                                where upper(nombre) in ('MANUAL', 'PLAN MANUAL')
                                order by id
                                limit 1
                                """
                            )
                            row_tipo = cur.fetchone()
                            if not row_tipo:
                                cur.execute("select min(id) from interaccion.tipo_plan")
                                row_tipo = cur.fetchone()
                            if row_tipo and row_tipo[0] is not None:
                                id_tipo_plan = int(row_tipo[0])
                if not id_tipo_plan:
                    raise HTTPException(
                        status_code=400,
                        detail="No se pudo determinar id_tipo_plan para guardar el plan manual.",
                    )
                cols.append("id_tipo_plan")
                vals.append(id_tipo_plan)
            if "id_origen_plan" in cols_plan:
                id_origen_plan = payload.get("id_origen_plan")
                if not id_origen_plan:
                    for tabla in ("catalogo_origen_plan", "origen_plan"):
                        try:
                            cur.execute(
                                f"""
                                select id
                                from interaccion.{tabla}
                                where upper(nombre) in ('NUTRICIONISTA', 'MANUAL', 'NUTRICION')
                                order by id
                                limit 1
                                """
                            )
                            row_origen = cur.fetchone()
                            if not row_origen:
                                cur.execute(f"select min(id) from interaccion.{tabla}")
                                row_origen = cur.fetchone()
                            if row_origen and row_origen[0] is not None:
                                id_origen_plan = int(row_origen[0])
                                break
                        except Exception:
                            continue
                if not id_origen_plan:
                    raise HTTPException(
                        status_code=400,
                        detail="No se pudo determinar id_origen_plan para guardar el plan manual.",
                    )
                cols.append("id_origen_plan")
                vals.append(id_origen_plan)
            if "id_estado_plan" in cols_plan:
                id_estado_plan = payload.get("id_estado_plan")
                if not id_estado_plan:
                    for tabla in ("catalogo_estado_plan", "estado_plan"):
                        try:
                            cur.execute(
                                f"""
                                select id
                                from interaccion.{tabla}
                                where upper(nombre) in ('VIGENTE', 'ACTIVO', 'ACTIVA')
                                order by id
                                limit 1
                                """
                            )
                            row_estado = cur.fetchone()
                            if not row_estado:
                                cur.execute(f"select min(id) from interaccion.{tabla}")
                                row_estado = cur.fetchone()
                            if row_estado and row_estado[0] is not None:
                                id_estado_plan = int(row_estado[0])
                                break
                        except Exception:
                            continue
                if not id_estado_plan:
                    raise HTTPException(
                        status_code=400,
                        detail="No se pudo determinar id_estado_plan para guardar el plan manual.",
                    )
                cols.append("id_estado_plan")
                vals.append(id_estado_plan)
            if "origen_plan" in cols_plan:
                cols.append("origen_plan")
                vals.append("NUTRICIONISTA")
            if "comidas_por_dia" in cols_plan:
                cols.append("comidas_por_dia")
                vals.append(max(int(i.get("comidas_por_dia") or 0) for i in plan_items))
            if "created_at" in cols_plan:
                cols.append("created_at")
                vals.append("now()")

            cols_sql = []
            placeholders = []
            params = []
            for c, v in zip(cols, vals):
                cols_sql.append(c)
                if v == "now()":
                    placeholders.append("now()")
                else:
                    placeholders.append("%s")
                    params.append(v)

            cur.execute(
                f"insert into interaccion.plan_nutricional ({', '.join(cols_sql)}) values ({', '.join(placeholders)}) returning id",
                tuple(params),
            )
            id_plan = cur.fetchone()[0]

            cur.execute(
                """
                select column_name
                from information_schema.columns
                where table_schema = 'interaccion'
                  and table_name = 'plan_item'
                """
            )
            cols_item = {r[0] for r in cur.fetchall()}
            for item in plan_items:
                item_cols = ["id_plan", "id_momento", "id_receta", "fecha_programada"]
                item_vals = [id_plan, item.get("id_momento"), item.get("id_receta"), item.get("fecha")]
                if "created_at" in cols_item:
                    item_cols.append("created_at")
                    item_vals.append("now()")
                if "comidas_por_dia" in cols_item:
                    item_cols.append("comidas_por_dia")
                    item_vals.append(item.get("comidas_por_dia"))

                icols = []
                iph = []
                iparams = []
                for c, v in zip(item_cols, item_vals):
                    icols.append(c)
                    if v == "now()":
                        iph.append("now()")
                    else:
                        iph.append("%s")
                        iparams.append(v)
                cur.execute(
                    f"insert into interaccion.plan_item ({', '.join(icols)}) values ({', '.join(iph)})",
                    tuple(iparams),
                )

        # 1. Limpiar recomendaciones previas de la nutri para este paciente (opcional, según lógica de negocio)
        # Aquí asumimos que las recomendaciones del plan mensual reemplazan las anteriores de la nutri
        cur.execute("""
            delete from clinico.recomendacion_ingrediente 
            where id_paciente = %s and id_rol_recomienda = 3
        """, (id_paciente,))
        
        # 2. Insertar nuevos potenciadores
        if boosters and id_profesional_interno is None:
            raise HTTPException(
                status_code=400,
                detail="No se pudo resolver el profesional autenticado para guardar potenciadores.",
            )
        for ing_id in boosters:
            cur.execute("""
                insert into clinico.recomendacion_ingrediente 
                (id_paciente, id_ingrediente, id_profesional, id_rol_recomienda, motivo, prioridad)
                values (%s, %s, %s, 3, 'Potenciador de Plan Mensual', 3)
            """, (id_paciente, ing_id, id_profesional_interno))
            
    return {"success": True, "message": "Plan y potenciadores activados", "id_plan": id_plan}

@router.get("/condiciones-nutricionales")
def condiciones_nutricionales_compat(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Traemos las condiciones nutricionales (tipo 3)
    return repo.obtener_catalogo("heuristico", "condicion", filtro_tipos=[3])

@router.post("/condiciones-nutricionales")
def crear_condicion_nutri(
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Forzar id_tipo_condicion = 3 para nutricionistas
    payload["id_tipo_condicion"] = 3
    id_c = repo.crear_condicion(payload)
    return {"id": id_c, "success": True}

@router.put("/condiciones-nutricionales/{id_condicion}")
def actualizar_condicion_nutri(
    id_condicion: int,
    payload: dict,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    exito = repo.actualizar_condicion(id_condicion, payload)
    return {"success": exito}

@router.delete("/condiciones-nutricionales/{id_condicion}")
def eliminar_condicion_nutri(
    id_condicion: int,
    _=Depends(require_roles("admin", "nutricionista"))
):
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    exito = repo.eliminar_condicion(id_condicion)
    return {"success": exito}

@router.get("/ingredientes")
def listar_ingredientes_compat(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Endpoint unificado para el selector de ingredientes de recetas."""
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    # Obtenemos el catálogo básico con nombre y categoría
    return repo.obtener_catalogo("nutricion", "ingrediente")

@router.get("/etiquetas")
def listar_etiquetas_compat(
    _=Depends(require_roles("admin", "nutricionista", "medico"))
):
    """Endpoint unificado para el catálogo de etiquetas."""
    from app.infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres
    repo = RepositorioPerfilPostgres()
    return repo.obtener_catalogo("nutricion", "etiqueta_nutricional")

@router.get("/crud/momentos")
def listar_momentos_comida_compat():
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    return repo.listar_momentos_comida()

@router.get("/crud/tipos-plato")
def listar_tipos_plato_compat():
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    return repo.listar_tipos_plato()

@router.get("/crud/recetas")
def crud_recetas_compat(
    q: str = Query(default=""),
    limit: int = Query(default=1000),
    offset: int = Query(default=0),
    id_momento: int = Query(default=None),
    id_tipo_plato: int = Query(default=None),
    include_total: bool = Query(default=False),
):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    items = repo.listar_recetas(
        consulta=q,
        limite=limit,
        offset=offset,
        id_momento=id_momento,
        id_tipo_plato=id_tipo_plato,
    )
    if include_total:
        return {
            "items": items,
            "total": repo.contar_recetas(
                consulta=q,
                id_momento=id_momento,
                id_tipo_plato=id_tipo_plato,
            ),
        }
    return items

@router.get("/crud/recetas/{id_receta}")
def obtener_receta_detalle_completo(id_receta: int):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    res = repo.obtener_detalle_completo(id_receta)
    if not res:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Receta no encontrada")
    return res

@router.post("/crud/recetas")
def guardar_receta_completa(payload: dict):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    import traceback
    import sys
    import json
    repo = RepositorioRecetaPostgres()
    try:
        id_receta = repo.guardar_receta(payload)
        return {
            "success": True,
            "id": id_receta,
            "estado": "APTA_REUMATICA",
            "permitir_guardado": True,
            "mostrar_motivo": False,
        }
    except Exception as e:
        raw_msg = str(e)
        if raw_msg.startswith("__REUMA_BLOCK__"):
            try:
                violaciones = json.loads(raw_msg.replace("__REUMA_BLOCK__", "", 1))
            except Exception:
                violaciones = [raw_msg.replace("__REUMA_BLOCK__", "", 1)]
            raise HTTPException(
                status_code=422,
                detail={
                    "success": False,
                    "estado": "NO_APTA_REUMATICA",
                    "permitir_guardado": False,
                    "mostrar_motivo": True,
                    "motivos": violaciones,
                    "opciones": ["DESCARTAR_RECETA", "CAMBIAR_INGREDIENTE"],
                },
            )
        error_msg = f"Error guardando receta: {raw_msg}"
        print(error_msg, file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        raise HTTPException(status_code=400, detail=error_msg)

@router.delete("/crud/recetas/{id_receta}")
def eliminar_receta_completa(id_receta: int):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    exito = repo.eliminar_receta(id_receta)
    return {"success": exito}

@router.patch("/crud/recetas/{id_receta}/estado")
def cambiar_estado_receta_compat(id_receta: int, payload: dict):
    from app.infraestructura.repositorios.repositorio_receta import RepositorioRecetaPostgres
    repo = RepositorioRecetaPostgres()
    exito = repo.cambiar_estado_receta(id_receta, payload.get("activa", True))
    return {"success": exito}

@router.post("/crud/recetas/{id_receta}/etiquetas/{id_etiqueta}")
def asignar_etiqueta_receta(id_receta: int, id_etiqueta: int):
    """Vincula una etiqueta nutricional a una receta."""
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta) VALUES (%s, %s) ON CONFLICT DO NOTHING",
            (id_receta, id_etiqueta)
        )
        return {"success": True}

@router.delete("/crud/recetas/{id_receta}/etiquetas/{id_etiqueta}")
def desvincular_etiqueta_receta(id_receta: int, id_etiqueta: int):
    """Desvincula una etiqueta nutricional de una receta."""
    from app.infraestructura.database.db import db_cursor
    with db_cursor() as cur:
        cur.execute(
            "DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s AND id_etiqueta = %s",
            (id_receta, id_etiqueta)
        )
        return {"success": True}
