from typing import List, Optional, Dict, Any
from copy import deepcopy
import threading
import time
import json
from app.infraestructura.database.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioReceta

class RepositorioRecetaPostgres(IRepositorioReceta):
    _safe_recipes_cache: dict = {}
    _safe_recipes_cache_lock = threading.Lock()
    _safe_recipes_cache_ttl_seconds = 45.0

    @classmethod
    def _limpiar_cache_recetas_seguras(cls) -> None:
        with cls._safe_recipes_cache_lock:
            cls._safe_recipes_cache.clear()

    @classmethod
    def _cache_recetas_seguras_get(cls, key):
        ahora = time.monotonic()
        with cls._safe_recipes_cache_lock:
            entrada = cls._safe_recipes_cache.get(key)
            if not entrada:
                return None
            ts, value = entrada
            if ahora - ts > cls._safe_recipes_cache_ttl_seconds:
                cls._safe_recipes_cache.pop(key, None)
                return None
            return deepcopy(value)

    @classmethod
    def _cache_recetas_seguras_set(cls, key, value) -> None:
        with cls._safe_recipes_cache_lock:
            cls._safe_recipes_cache[key] = (time.monotonic(), deepcopy(value))

    def _obtener_etiquetas_objetivo_les_aij(self, cur) -> set[int]:
        cur.execute(
            """
            select distinct r.id_etiqueta
            from heuristico.regla r
            join heuristico.condicion_regla cr on cr.id_regla = r.id
            join heuristico.condicion c on c.id = cr.id_condicion
            where r.id_etiqueta is not null
              and upper(coalesce(r.origen_regla, 'CLINICA')) = 'CLINICA'
              and upper(coalesce(c.indicador_codigo, '')) in (
                'LUPUS_ERITEMATOSO_SISTEMICO',
                'ARTRITIS_IDIOPATICA_JUVENIL'
              )
            """
        )
        return {int(r[0]) for r in cur.fetchall() if r and r[0] is not None}

    def _normalizar_dificultad(self, valor: Optional[str]) -> str:
        if not valor:
            return "Media"
        dificultad = str(valor).strip()
        mapa = {
            "facil": "Fácil",
            "fácil": "Fácil",
            "media": "Media",
            "dificil": "Difícil",
            "difícil": "Difícil",
        }
        return mapa.get(dificultad.lower(), "Media")

    def _entero_o_default(self, valor, default: int = 0) -> int:
        if valor is None or valor == "":
            return default
        try:
            return int(valor)
        except (TypeError, ValueError):
            return default

    def _obtener_condicion_general_reumaticos_id(self, cur) -> Optional[int]:
        cur.execute(
            """
            select id
            from heuristico.condicion
            where activa = true
              and (
                upper(coalesce(indicador_codigo, '')) = 'GENERAL_REUMATICOS'
                or lower(coalesce(nombre, '')) = 'general reumaticos'
              )
            order by id
            limit 1
            """
        )
        row = cur.fetchone()
        return int(row[0]) if row and row[0] is not None else None

    def _validar_receta_general_reumatica(self, cur, datos: dict) -> list[str]:
        id_cond_general = self._obtener_condicion_general_reumaticos_id(cur)
        if not id_cond_general:
            return []

        cur.execute(
            """
            select
                r.id_ingrediente,
                r.id_grupo_alimentario,
                r.id_subgrupo_alimentario,
                r.id_etiqueta,
                r.id_receta,
                coalesce(r.mensaje_error, 'Incumple regla clinica general reumatica') as mensaje,      
                i.nombre as ingrediente_nombre,
                g.nombre as grupo_nombre,
                s.nombre as subgrupo_nombre
            from heuristico.regla r
            join heuristico.catalogo_accion a on a.id = r.id_accion
            join heuristico.condicion_regla cr on cr.id_regla = r.id
            left join nutricion.ingrediente i on i.id = r.id_ingrediente
            left join nutricion.grupo_alimentario g on g.id = r.id_grupo_alimentario
            left join nutricion.subgrupo_alimentario s on s.id = r.id_subgrupo_alimentario
            where cr.id_condicion = %s
              and upper(a.nombre) = 'ELIMINAR'
            """,
            (id_cond_general,),
        )
        reglas = cur.fetchall()
        if not reglas:
            return []

        ingredientes_payload = set()
        for ing in (datos.get("ingredientes", []) or []):
            iid = ing.get("id_ingrediente")
            if iid is not None:
                ingredientes_payload.add(int(iid))

        grupos_payload: set[int] = set()
        subgrupos_payload: set[int] = set()
        if ingredientes_payload:
            cur.execute(
                """
                select id_grupo_alimentario, id_subgrupo_alimentario
                from nutricion.ingrediente
                where id = any(%s)
                """,
                (list(ingredientes_payload),),
            )
            for gid, sid in cur.fetchall():
                if gid is not None:
                    grupos_payload.add(int(gid))
                if sid is not None:
                    subgrupos_payload.add(int(sid))

        violaciones: list[str] = []
        for rid_ing, rid_grp, rid_sub, rid_etq, rid_rec, msg, ing_nombre, grp_nombre, sub_nombre in reglas:
            if rid_rec is not None and datos.get("id") and int(datos["id"]) == int(rid_rec):
                violaciones.append(f"Esta receta está bloqueada clínicamente. Sugerencia: Revisa los criterios clínicos o descarta la receta.")
                continue
            if rid_ing is not None and int(rid_ing) in ingredientes_payload:
                nombre = ing_nombre or f"ingrediente #{rid_ing}"
                violaciones.append(f"No apta para el filtro base reumático debido al ingrediente: {nombre}. Sugerencia: Sustituye el ingrediente o descarta la receta.")
                continue
            if rid_grp is not None and int(rid_grp) in grupos_payload:
                nombre = grp_nombre or f"grupo #{rid_grp}"
                violaciones.append(f"No apta para el filtro base reumático debido al grupo alimentario: {nombre}. Sugerencia: Elimina ingredientes de este grupo o descarta la receta.")
                continue
            if rid_sub is not None and int(rid_sub) in subgrupos_payload:
                nombre = sub_nombre or f"subgrupo #{rid_sub}"
                violaciones.append(f"No apta para el filtro base reumático debido al subgrupo: {nombre}. Sugerencia: Sustituye los ingredientes de este subgrupo o descarta la receta.")
                continue
            # Las etiquetas NO_APTO_* son advertencias/segmentacion clinica de la receta.
            # No deben impedir crear la receta; el filtrado por paciente se aplica despues.

        vistos = set()
        unicos: list[str] = []
        for v in violaciones:
            if v not in vistos:
                vistos.add(v)
                unicos.append(v)
        return unicos

    def obtener_estadisticas_recetas(self) -> dict:
        """Retorna conteos rapidos para los KPIs del nutricionista."""
        with db_cursor() as cur:
            cur.execute("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE activa = true) as activos,
                    COUNT(*) FILTER (WHERE activa = false) as inactivos
                FROM nutricion.receta
            """)
            row = cur.fetchone()
            return {
                "total": row[0] or 0,
                "activos": row[1] or 0,
                "inactivos": row[2] or 0
            }

    def _sql_receta_resumen_base(self, where_clause: str) -> str:
        """Version ligera de la consulta de recetas para listados y vistas previas."""
        return f"""
            SELECT 
                r.id, 
                r.nombre, 
                r.descripcion, 
                r.dificultad,
                r.porciones,
                r.tiempo_total_min,
                r.activa, 
                r.imagen_url,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.energia_kcal, 0))::numeric, 2), 0) AS calorias_totales,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.proteinas_g, 0))::numeric, 2), 0) AS proteinas_totales,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.hidratos_carbono_g, 0))::numeric, 2), 0) AS carbohidratos_totales,
                (
                    SELECT STRING_AGG(DISTINCT m.nombre, ', ' ORDER BY m.nombre)
                    FROM nutricion.receta_momento rm
                    JOIN nutricion.momento_comida m ON m.id = rm.id_momento
                    WHERE rm.id_receta = r.id
                ) AS momentos_nombres,
                (
                    SELECT STRING_AGG(DISTINCT tp.nombre, ', ' ORDER BY tp.nombre)
                    FROM nutricion.receta_tipo_plato rtp
                    JOIN nutricion.tipo_plato tp ON tp.id = rtp.id_tipo_plato
                    WHERE rtp.id_receta = r.id
                ) AS tipos_plato_nombres
            FROM nutricion.receta r
            LEFT JOIN nutricion.receta_ingrediente ri ON ri.id_receta = r.id
            LEFT JOIN nutricion.ingrediente i ON i.id = ri.id_ingrediente
            LEFT JOIN nutricion.ingrediente_composicion ic ON ic.id_ingrediente = ri.id_ingrediente
            WHERE {where_clause}
            GROUP BY r.id
        """

    def _sql_receta_detalle_base(self, where_clause: str) -> str:
        return f"""
            SELECT
                r.id,
                r.nombre,
                r.descripcion,
                r.descripcion_larga,
                r.dificultad,
                r.porciones,
                r.tiempo_preparacion_min,
                r.tiempo_coccion_min,
                r.tiempo_total_min,
                r.calorias_por_porcion,
                r.activa,
                r.imagen_url,
                r.created_at,
                r.updated_at,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.energia_kcal, 0))::numeric, 2), 0) AS calorias_totales,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.proteinas_g, 0))::numeric, 2), 0) AS proteinas_totales,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.hidratos_carbono_g, 0))::numeric, 2), 0) AS carbohidratos_totales,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.grasa_total_g, 0))::numeric, 2), 0) AS grasas_totales,
                COALESCE(ROUND(SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.fibra_vegetal_g, 0))::numeric, 2), 0) AS fibra_totales,
                COALESCE(ROUND(SUM(COALESCE(ri.peso_en_gramos, 0))::numeric, 2), 0) AS peso_total,
                (
                    SELECT STRING_AGG(DISTINCT m.nombre, ', ' ORDER BY m.nombre)
                    FROM nutricion.receta_momento rm
                    JOIN nutricion.momento_comida m ON m.id = rm.id_momento
                    WHERE rm.id_receta = r.id
                ) AS momentos_nombres,
                COALESCE((
                    SELECT ARRAY_AGG(DISTINCT rm.id_momento ORDER BY rm.id_momento)
                    FROM nutricion.receta_momento rm
                    WHERE rm.id_receta = r.id
                ), '{{}}'::int[]) AS momentos_ids,
                (
                    SELECT STRING_AGG(DISTINCT tp.nombre, ', ' ORDER BY tp.nombre)
                    FROM nutricion.receta_tipo_plato rtp
                    JOIN nutricion.tipo_plato tp ON tp.id = rtp.id_tipo_plato
                    WHERE rtp.id_receta = r.id
                ) AS tipos_plato_nombres,
                COALESCE((
                    SELECT ARRAY_AGG(DISTINCT rtp.id_tipo_plato ORDER BY rtp.id_tipo_plato)
                    FROM nutricion.receta_tipo_plato rtp
                    WHERE rtp.id_receta = r.id
                ), '{{}}'::int[]) AS tipos_plato_ids,
                (
                    SELECT m.nombre
                    FROM nutricion.receta_momento rm
                    JOIN nutricion.momento_comida m ON m.id = rm.id_momento
                    WHERE rm.id_receta = r.id
                    ORDER BY m.orden NULLS LAST, m.nombre
                    LIMIT 1
                ) AS categoria,
                COALESCE((
                    SELECT ROUND(AVG(estrellas)::numeric, 1)
                    FROM interaccion.evaluacion_receta
                    WHERE id_receta = r.id
                ), 0) AS puntuacion_promedio,
                COALESCE((
                    SELECT COUNT(*)
                    FROM interaccion.evaluacion_receta
                    WHERE id_receta = r.id
                ), 0) AS total_evaluaciones,
                COALESCE((
                    SELECT estrellas
                    FROM interaccion.evaluacion_receta
                    WHERE id_receta = r.id AND id_paciente = %s
                    LIMIT 1
                ), 0) AS calificacion_personal
            FROM nutricion.receta r
            LEFT JOIN nutricion.receta_ingrediente ri ON ri.id_receta = r.id
            LEFT JOIN nutricion.ingrediente i ON i.id = ri.id_ingrediente
            LEFT JOIN nutricion.ingrediente_composicion ic ON ic.id_ingrediente = ri.id_ingrediente
            WHERE {where_clause}
            GROUP BY r.id, r.calorias_por_porcion
        """

    def _recargar_indices_recetas_seguras(self, cur):
        """Asegura que los indices de busqueda esten listos (No hace nada si ya existen)"""
        pass

    def _build_recetas_filters(
        self,
        consulta: str = "",
        id_momento: int | None = None,
        id_tipo_plato: int | None = None,
    ) -> tuple[str, list]:
        where_clause = "TRUE"
        params = []
        if consulta:
            where_clause += " and r.nombre ilike %s"
            params.append(f"%{consulta}%")
        if id_momento:
            where_clause += " and exists (select 1 from nutricion.receta_momento rm where rm.id_receta = r.id and rm.id_momento = %s)"
            params.append(id_momento)
        if id_tipo_plato:
            where_clause += " and exists (select 1 from nutricion.receta_tipo_plato rtp where rtp.id_receta = r.id and rtp.id_tipo_plato = %s)"
            params.append(id_tipo_plato)
        return where_clause, params

    def listar_recetas(
        self,
        consulta: str = "",
        limite: int = 12,
        offset: int = 0,
        id_momento: int | None = None,
        id_tipo_plato: int | None = None,
    ) -> List[dict]:
        where_clause, filter_params = self._build_recetas_filters(
            consulta,
            id_momento,
            id_tipo_plato,
        )
        # En el resumen no necesitamos id_paciente, usamos None
        sql = self._sql_receta_resumen_base(where_clause) + " ORDER BY r.nombre LIMIT %s OFFSET %s"
        with db_cursor() as cur:
            cur.execute(sql, filter_params + [limite, offset])
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def contar_recetas(
        self,
        consulta: str = "",
        id_momento: int | None = None,
        id_tipo_plato: int | None = None,
    ) -> int:
        where_clause, params = self._build_recetas_filters(
            consulta,
            id_momento,
            id_tipo_plato,
        )
        with db_cursor() as cur:
            cur.execute(
                f"""
                select count(*)
                from nutricion.receta r
                where {where_clause}
                """,
                params,
            )
            return int(cur.fetchone()[0] or 0)

    def obtener_detalle_completo(self, id_receta: int, id_paciente: str | None = None) -> Optional[dict]:
        with db_cursor() as cur:
            cur.execute(self._sql_receta_detalle_base("r.id = %s"), (id_paciente, id_receta))
            row = cur.fetchone()
            if not row: return None
            receta = dict(zip([d[0] for d in cur.description], row))
            
            # Verificar si está en el plan de hoy para el paciente
            receta['en_plan_hoy'] = False
            if id_paciente:
                cur.execute("""
                    select pi.id, pi.consumida
                    from interaccion.plan_item pi
                    join interaccion.plan_nutricional p on p.id = pi.id_plan
                    where p.id_paciente = %s 
                      and pi.id_receta = %s 
                      and pi.fecha_programada = current_date
                    limit 1
                """, (id_paciente, id_receta))
                plan_row = cur.fetchone()
                if plan_row:
                    receta['en_plan_hoy'] = True
                    receta['id_plan_item_hoy'] = plan_row[0]
                    receta['consumida_hoy'] = plan_row[1]

            cur.execute("SELECT id_momento FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
            receta['momentos'] = [r[0] for r in cur.fetchall()]
            cur.execute("SELECT id_tipo_plato FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            receta['tipos_plato'] = [r[0] for r in cur.fetchall()]
            cur.execute("""
                SELECT ri.id_ingrediente, i.nombre, ri.cantidad_visual as cantidad, ri.unidad_visual as unidad, 
                       ri.peso_en_gramos as gramos, ri.observaciones, ri.es_principal
                FROM nutricion.receta_ingrediente ri
                JOIN nutricion.ingrediente i ON i.id = ri.id_ingrediente
                WHERE ri.id_receta = %s ORDER BY ri.id ASC
            """, (id_receta,))
            receta['ingredientes'] = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            cur.execute("""
                SELECT numero_paso as paso, descripcion, tiempo_estimado as tiempo, nota_adicional as nota
                FROM nutricion.receta_paso
                WHERE id_receta = %s ORDER BY numero_paso ASC
            """, (id_receta,))
            receta['preparacion'] = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # 4. Etiquetas de salud
            cur.execute("""
                SELECT e.id, e.nombre_visible as titulo, e.descripcion as explicacion, e.codigo        
                FROM nutricion.receta_etiqueta re
                JOIN nutricion.etiqueta_nutricional e ON e.id = re.id_etiqueta
                WHERE re.id_receta = %s
            """, (id_receta,))
            columnas_etq = [desc[0] for desc in cur.description]
            receta['etiquetas_salud'] = [dict(zip(columnas_etq, r)) for r in cur.fetchall()]

            # 5. Nutrición Detallada (Vitaminas y Minerales)
            cur.execute("""
                SELECT 
                    SUM(ic.vitamina_a_eq_retinol_ug) as vit_a,
                    SUM(ic.vit_c_mg) as vit_c,
                    SUM(ic.vit_e_eq_alpha_tocoferol_mg) as vit_e,
                    SUM(ic.hierro_mg) as hierro,
                    SUM(ic.magnesio_mg) as magnesio,
                    SUM(ic.potasio_mg) as potasio
                FROM nutricion.receta_ingrediente ri
                JOIN nutricion.ingrediente_composicion ic ON ri.id_ingrediente = ic.id_ingrediente     
                WHERE ri.id_receta = %s
            """, (id_receta,))
            micro = cur.fetchone()
            if micro:
                receta['nutricion_detallada'] = {
                    "vitaminas": [
                        {"nombre": "Vitamina A", "valor": round(float(micro[0] or 0), 2), "unidad": "µg"},
                        {"nombre": "Vitamina C", "valor": round(float(micro[1] or 0), 2), "unidad": "mg"},
                        {"nombre": "Vitamina E", "valor": round(float(micro[2] or 0), 2), "unidad": "mg"}
                    ],
                    "minerales": [
                        {"nombre": "Hierro", "valor": round(float(micro[3] or 0), 2), "unidad": "mg"}, 
                        {"nombre": "Magnesio", "valor": round(float(micro[4] or 0), 2), "unidad": "mg"},
                        {"nombre": "Potasio", "valor": round(float(micro[5] or 0), 2), "unidad": "mg"} 
                    ]
                }
            return receta

    def obtener_recetas_por_momento(self, id_momento: int) -> List[dict]:
        with db_cursor() as cur:
            sql = self._sql_receta_detalle_base("""
                r.activa = true
                AND EXISTS (
                    SELECT 1
                    FROM nutricion.receta_momento rm
                    WHERE rm.id_receta = r.id AND rm.id_momento = %s
                )
            """)
            cur.execute(sql, (None, id_momento))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_receta(self, id_receta: int) -> Optional[dict]:
        with db_cursor() as cur:
            sql = """
                select r.id, r.nombre, r.descripcion,
                       (SELECT array_agg(id_tipo_plato) FROM nutricion.receta_tipo_plato WHERE id_receta = r.id) as tipos_plato_ids
                from nutricion.receta r
                where r.id = %s
            """
            cur.execute(sql, (id_receta,))
            row = cur.fetchone()
            if not row: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, row))

    def obtener_recetas_seguras_bulk(self, id_paciente: str, limite: int = 1000) -> List[dict]:
        """
        VersiÃ³n de alto rendimiento para generaciÃ³n de planes masivos.
        Utiliza la funciÃ³n SQL optimizada en Supabase.
        """
        with db_cursor() as cur:
            cur.execute(
                "SELECT * FROM nutricion.obtener_recetas_seguras_eficiente(%s, %s)",
                (id_paciente, limite)
            )
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def obtener_recetas_seguras_para_paciente(
        self,
        id_paciente: str,
        id_momento: Optional[int] = None,
        id_tipo_plato: Optional[int] = None,
        consulta: Optional[str] = None,
        limite: int = 100,
        offset: int = 0
    ) -> List[dict]:
        # Tratar consulta vacía como None
        query_text = consulta if (consulta and consulta.strip()) else None

        cache_key = ("safe_recipes", id_paciente, id_momento, id_tipo_plato, query_text, limite, offset)
        cached = self._cache_recetas_seguras_get(cache_key)
        if cached is not None:
            return cached

        with db_cursor() as cur:
            sql = """
                with recetas_base as (
                  select * from nutricion.vista_recetas_detalle
                  where coalesce(activa,false)=true
                    and (%s::int is null or %s::int = any(momentos_ids))
                    and (%s::int is null or %s::int = any(tipos_plato_ids))
                    and (%s::text is null or nombre ilike '%%' || %s::text || '%%')
                ),
                stats as (
                  select id_receta, round(avg(estrellas)::numeric, 1) as puntuacion_promedio, count(*) as total_evaluaciones
                  from interaccion.evaluacion_receta group by id_receta
                ),
                conds as (
                  select id as id_condicion from heuristico.condicion 
                  where activa = true and (indicador_codigo = 'GENERAL_REUMATICOS' or nombre = 'general reumaticos')
                  union
                  select id_condicion from clinico.diagnostico_paciente where id_paciente = %s::uuid and esta_activo = true
                  union
                  select cca.id_condicion from clinico.control_condicion_activa cca join clinico.control_paciente cp on cp.id = cca.id_control
                  where cp.id_paciente = %s::uuid and cca.esta_activa = true
                ),
                prefs as (
                  select id_subgrupo_alimentario from interaccion.preferencia_paciente where id_paciente = %s::uuid
                ),
                reglas_aplicables as (
                  select upper(ca.nombre) as accion, r.id_ingrediente, r.id_subgrupo_alimentario, r.id_grupo_alimentario, r.id_etiqueta, r.id_receta
                  from heuristico.regla r join heuristico.catalogo_accion ca on ca.id = r.id_accion join heuristico.condicion_regla cr on cr.id_regla = r.id
                  where cr.id_condicion in (select id_condicion from conds)
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
                recoms as (
                   select id_ingrediente from clinico.recomendacion_ingrediente where id_paciente = %s::uuid and activa = true
                ),
                bloqueadas as (
                  select distinct rec.id from recetas_base rec
                  where exists (select 1 from clinico.alergia_paciente_ingrediente api where api.id_paciente = %s::uuid and api.activa = true and api.id_ingrediente = any(rec.ingredientes_ids))
                  or exists (select 1 from clinico.alergia_paciente_subgrupo aps where aps.id_paciente = %s::uuid and aps.activa = true and aps.id_subgrupo_alimentario = any(rec.subgrupos_ids))
                  or exists (select 1 from restricciones_bloqueantes rb where rb.codigo is not null and rb.codigo = any(rec.etiquetas_codigos))
                  or exists (select 1 from reglas_aplicables ra where ra.accion = 'ELIMINAR' and ( (ra.id_receta = rec.id) or (ra.id_ingrediente = any(rec.ingredientes_ids)) or (ra.id_subgrupo_alimentario = any(rec.subgrupos_ids)) or (ra.id_grupo_alimentario = any(rec.grupos_ids)) or (ra.id_etiqueta is not null and exists (select 1 from nutricion.etiqueta_nutricional e2 where e2.id = ra.id_etiqueta and e2.codigo = any(rec.etiquetas_codigos))) ))
                ),
                clasificadas as (
                  select rec.*, coalesce(s.puntuacion_promedio, 0) as puntuacion_promedio, coalesce(s.total_evaluaciones, 0) as total_evaluaciones,
                         (exists (select 1 from reglas_aplicables ra where ra.accion = 'PRIORIZAR' and (ra.id_receta = rec.id or ra.id_ingrediente = any(rec.ingredientes_ids) or ra.id_subgrupo_alimentario = any(rec.subgrupos_ids) or ra.id_grupo_alimentario = any(rec.grupos_ids) or (ra.id_etiqueta is not null and exists (select 1 from nutricion.etiqueta_nutricional e2 where e2.id = ra.id_etiqueta and e2.codigo = any(rec.etiquetas_codigos))))) 
                          or exists (select 1 from recoms rem where rem.id_ingrediente = any(rec.ingredientes_ids))) as es_potenciada,
                         exists (select 1 from reglas_aplicables ra where ra.accion = 'DISMINUIR' and (ra.id_receta = rec.id or ra.id_ingrediente = any(rec.ingredientes_ids) or ra.id_subgrupo_alimentario = any(rec.subgrupos_ids) or ra.id_grupo_alimentario = any(rec.grupos_ids) or (ra.id_etiqueta is not null and exists (select 1 from nutricion.etiqueta_nutricional e2 where e2.id = ra.id_etiqueta and e2.codigo = any(rec.etiquetas_codigos))))) as es_disminuida,
                         exists (select 1 from unnest(rec.subgrupos_ids) as s_id where s_id in (select id_subgrupo_alimentario from prefs)) as es_preferida
                  from recetas_base rec
                  left join stats s on s.id_receta = rec.id
                  where rec.id not in (select id from bloqueadas)
                )
                select c.*,
                       case when c.es_potenciada then 'verde' when c.es_disminuida then 'amarillo' else 'neutral' end as semaforo,
                       case when c.es_potenciada then 'Recomendada' when c.es_disminuida then 'Menos recomendada' else 'Normal' end as clasificacion_recomendacion,
                       case when c.es_potenciada then 'PRIORIZAR: recomendada para este paciente' when c.es_disminuida then 'DISMINUIR: usar con menor frecuencia' else 'Segura para el paciente' end as mensaje_regla
                from clasificadas c 
                order by 
                  case when c.es_potenciada then 0 when c.es_disminuida then 2 else 1 end, 
                  case when c.es_preferida then 0 else 1 end,
                  c.nombre
                limit %s offset %s
            """
            params = (
                id_momento, id_momento, 
                id_tipo_plato, id_tipo_plato,
                query_text, query_text, 
                id_paciente, id_paciente, 
                id_paciente, # Para prefs
                id_paciente, id_paciente, id_paciente, id_paciente, 
                limite, offset
            )
            cur.execute(sql, params)
            cols = [d[0] for d in cur.description]
            resultados = [dict(zip(cols, row)) for row in cur.fetchall()]
            self._cache_recetas_seguras_set(cache_key, resultados)
            return deepcopy(resultados)

    def listar_momentos_comida(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre, hora_inicio, hora_fin FROM nutricion.momento_comida WHERE activo = true ORDER BY orden")
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def listar_tipos_plato(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.tipo_plato ORDER BY nombre")
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def cambiar_estado_receta(self, id_receta: int, activa: bool) -> bool:
        with db_cursor() as cur:
            cur.execute("UPDATE nutricion.receta SET activa = %s, updated_at = now() WHERE id = %s", (activa, id_receta))
            self._limpiar_cache_recetas_seguras()
            return cur.rowcount > 0

    def guardar_receta(self, datos: dict) -> int:
        """Crea o actualiza una receta completa (Informacion, ingredientes y pasos)."""
        with db_cursor() as cur:
            id_receta = datos.get("id")
            if not id_receta:
                violaciones = self._validar_receta_general_reumatica(cur, datos)
                if violaciones:
                    raise ValueError("__REUMA_BLOCK__" + json.dumps(violaciones, ensure_ascii=False))  

            dificultad = self._normalizar_dificultad(datos.get("dificultad"))
            tiempo_preparacion = self._entero_o_default(
                datos.get("tiempo_preparacion", datos.get("tiempo_preparacion_min")),
                0,
            )
            tiempo_coccion = self._entero_o_default(
                datos.get("tiempo_coccion", datos.get("tiempo_coccion_min")),
                0,
            )

            # 1. Upsert de la informacion basica
            if id_receta:
                sql = """
                    UPDATE nutricion.receta SET 
                        nombre = %s, descripcion = %s, descripcion_larga = %s, 
                        dificultad = %s, porciones = %s, tiempo_preparacion_min = %s, 
                        tiempo_coccion_min = %s, activa = %s, imagen_url = %s, updated_at = now()      
                    WHERE id = %s
                """
                cur.execute(sql, (
                    datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"),
                    dificultad, datos.get("porciones", 1), tiempo_preparacion,
                    tiempo_coccion, datos.get("activa", True), datos.get("imagen_url"), id_receta      
                ))
            else:
                sql = """
                    INSERT INTO nutricion.receta (
                        nombre, descripcion, descripcion_larga, dificultad, porciones, 
                        tiempo_preparacion_min, tiempo_coccion_min, activa, imagen_url
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """
                cur.execute(sql, (
                    datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"),
                    dificultad, datos.get("porciones", 1), tiempo_preparacion,
                    tiempo_coccion, datos.get("activa", True), datos.get("imagen_url")
                ))
                id_receta = cur.fetchone()[0]

            # 2. Momentos de comida
            if "momentos" in datos:
                cur.execute("DELETE FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,)) 
                momentos = list(set(datos.get("momentos") or [])) # Deduplicar
                if momentos:
                    mom_values = [(id_receta, mid) for mid in momentos if mid]
                    cur.executemany("INSERT INTO nutricion.receta_momento (id_receta, id_momento) VALUES (%s, %s) ON CONFLICT DO NOTHING", mom_values)

            # 3. Sincronizar Tipos de Plato
            cur.execute("DELETE FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))  
            tipos_plato = list(set(datos.get("tipos_plato", []))) # Deduplicar
            if tipos_plato:
                tp_values = [(id_receta, tid) for tid in tipos_plato if tid]
                cur.executemany("INSERT INTO nutricion.receta_tipo_plato (id_receta, id_tipo_plato) VALUES (%s, %s) ON CONFLICT DO NOTHING", tp_values)
                cur.execute("SELECT to_regclass('nutricion.momento_tipo_plato_factible')")
                has_mtpf = cur.fetchone()[0] is not None
                if has_mtpf:
                    cur.execute(
                        """
                        INSERT INTO nutricion.receta_momento (id_receta, id_momento)
                        SELECT DISTINCT %s, mtpf.id_momento
                        FROM nutricion.momento_tipo_plato_factible mtpf
                        WHERE mtpf.id_tipo_plato = ANY(%s)
                        ON CONFLICT DO NOTHING
                        """,
                        (id_receta, tipos_plato),
                    )
                else:
                    cur.execute("SELECT to_regclass('nutricion.regla_momento_comida')")
                    has_rmc = cur.fetchone()[0] is not None
                    cur.execute("SELECT to_regclass('nutricion.regla_momento_tipo_receta')")
                    has_rmtr = cur.fetchone()[0] is not None
                    if has_rmc and has_rmtr:
                        cur.execute(
                            """
                            INSERT INTO nutricion.receta_momento (id_receta, id_momento)
                            SELECT DISTINCT %s, rm.id_momento
                            FROM nutricion.regla_momento_comida rm
                            JOIN nutricion.regla_momento_tipo_receta rt ON rt.id_regla_momento = rm.id 
                            WHERE rt.id_tipo_plato = ANY(%s)
                              AND rm.activo = true
                              AND rt.activo = true
                            ON CONFLICT DO NOTHING
                            """,
                            (id_receta, tipos_plato),
                        )

            # 4. Sincronizar Ingredientes
            cur.execute("DELETE FROM nutricion.receta_ingrediente WHERE id_receta = %s", (id_receta,)) 
            ingredientes = datos.get("ingredientes", [])
            if ingredientes:
                ing_values = [
                    (id_receta, ing["id_ingrediente"], ing.get("cantidad"), ing.get("unidad"),         
                     ing.get("gramos", 0), ing.get("es_principal", False), ing.get("observaciones"))   
                    for ing in ingredientes if ing.get("id_ingrediente")
                ]
                cur.executemany("""
                    INSERT INTO nutricion.receta_ingrediente (
                        id_receta, id_ingrediente, cantidad_visual, unidad_visual, 
                        peso_en_gramos, es_principal, observaciones
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, ing_values)

            # 5. Sincronizar Pasos
            cur.execute("DELETE FROM nutricion.receta_paso WHERE id_receta = %s", (id_receta,))        
            pasos = datos.get("preparacion", [])
            if pasos:
                paso_values = [
                    (id_receta, i, p["descripcion"], p.get("tiempo"), p.get("nota"))
                    for i, p in enumerate(pasos, 1)
                ]
                cur.executemany("""
                    INSERT INTO nutricion.receta_paso (
                        id_receta, numero_paso, descripcion, tiempo_estimado, nota_adicional
                    ) VALUES (%s, %s, %s, %s, %s)
                """, paso_values)

            # 6. Sincronizar Etiquetas
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))    
            etiquetas_manuales = {
                int(etq.get("id"))
                for etq in datos.get("etiquetas_salud", [])
                if etq.get("id")
            }
            etiquetas_ids = sorted(etiquetas_manuales)
            if etiquetas_ids:
                etq_values = [(id_receta, eid) for eid in etiquetas_ids]
                cur.executemany("INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta) VALUES (%s, %s) ON CONFLICT DO NOTHING", etq_values)

            # 7. Sincronizar Imagen
            img_url = datos.get("imagen_url")
            if img_url:
                cur.execute("DELETE FROM nutricion.receta_imagen WHERE id_receta = %s", (id_receta,))  
                cur.execute(
                    "INSERT INTO nutricion.receta_imagen (id_receta, imagen_url) VALUES (%s, %s)",     
                    (id_receta, img_url)
                )

            self._limpiar_cache_recetas_seguras()
            return id_receta

    def eliminar_receta(self, id_receta: int) -> bool:
        """Elimina una receta y todas sus dependencias en nutricion e interaccion."""
        with db_cursor() as cur:
            # 1. Limpiar dependencias en interaccion
            cur.execute("DELETE FROM interaccion.seguimiento_plan_item WHERE id_receta_reemplazo = %s", (id_receta,))
            cur.execute("""
                DELETE FROM interaccion.seguimiento_plan_item 
                WHERE id_plan_item IN (SELECT id FROM interaccion.plan_item WHERE id_receta = %s)      
            """, (id_receta,))
            cur.execute("DELETE FROM interaccion.plan_item WHERE id_receta = %s", (id_receta,))        

            for tabla in ["interaccion.preferencia_receta", "interaccion.evaluacion_receta", "interaccion.repositorio_receta_segura_item"]:
                cur.execute("SELECT to_regclass(%s)", (tabla,))
                if cur.fetchone()[0]:
                    cur.execute(f"DELETE FROM {tabla} WHERE id_receta = %s", (id_receta,))

            cur.execute("SELECT to_regclass('heuristico.regla')")
            if cur.fetchone()[0]:
                cur.execute("""
                    DELETE FROM heuristico.condicion_regla
                    WHERE id_regla IN (
                        SELECT id FROM heuristico.regla WHERE id_receta = %s
                    )
                """, (id_receta,))
                cur.execute("DELETE FROM heuristico.regla WHERE id_receta = %s", (id_receta,))

            # 2. Limpiar dependencias en nutricion
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))    
            cur.execute("DELETE FROM nutricion.receta_ingrediente WHERE id_receta = %s", (id_receta,)) 
            cur.execute("DELETE FROM nutricion.receta_paso WHERE id_receta = %s", (id_receta,))        
            cur.execute("DELETE FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))     
            cur.execute("DELETE FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))  
            cur.execute("DELETE FROM nutricion.receta_imagen WHERE id_receta = %s", (id_receta,))      

            # 3. Eliminar la receta
            cur.execute("DELETE FROM nutricion.receta WHERE id = %s", (id_receta,))
            self._limpiar_cache_recetas_seguras()
            return cur.rowcount > 0

    def listar_tipos_plato_disponibles_para_paciente(
        self,
        id_paciente: str,
        id_momento: Optional[int] = None,
    ) -> List[dict]:
        recetas_seguras = self.obtener_recetas_seguras_para_paciente(
            id_paciente=id_paciente,
            id_momento=id_momento,
            id_tipo_plato=None,
        )
        if not recetas_seguras:
            return []

        tipos_momento_validos: Optional[set[int]] = None
        if id_momento is not None:
            with db_cursor() as cur:
                cur.execute(
                    "select id_tipo_plato from nutricion.momento_tipo_plato_factible where id_momento = %s",
                    (id_momento,),
                )
                tipos_momento_validos = {
                    int(r[0]) for r in cur.fetchall() if r and r[0] is not None
                }
            if not tipos_momento_validos:
                return []

        conteos: dict[int, int] = {}
        for receta in recetas_seguras:
            tipos = receta.get("tipos_plato_ids") or []
            if not isinstance(tipos, list):
                continue
            for tipo in tipos:
                try:
                    tid = int(tipo)
                except (TypeError, ValueError):
                    continue
                if tipos_momento_validos is not None and tid not in tipos_momento_validos:
                    continue
                conteos[tid] = conteos.get(tid, 0) + 1

        if not conteos:
            return []

        tipo_ids = sorted(conteos.keys())
        with db_cursor() as cur:
            cur.execute(
                "select id, nombre from nutricion.tipo_plato where id = any(%s)",
                (tipo_ids,),
            )
            tipos = {int(r[0]): r[1] for r in cur.fetchall() if r and r[0] is not None}

        resultado = [
            {
                "id_tipo_plato": tid,
                "tipo_plato_nombre": tipos.get(tid, str(tid)),
                "total_recetas": conteos[tid],
            }
            for tid in sorted(conteos.keys(), key=lambda x: tipos.get(x, str(x)))
        ]
        return resultado
