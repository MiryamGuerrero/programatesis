from typing import List, Optional, Dict, Any
import json
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioReceta

class RepositorioRecetaPostgres(IRepositorioReceta):
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

    def listar_recetas(self, consulta: str = "", limite: int = 1000) -> List[dict]:
        where_clause = "TRUE"
        params = [None]
        if consulta:
            where_clause += " and r.nombre ilike %s"
            params.append(f"%{consulta}%")
        sql = self._sql_receta_detalle_base(where_clause) + " ORDER BY r.nombre LIMIT %s"
        params.append(limite)
        with db_cursor() as cur:
            cur.execute(sql, params)
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_detalle_completo(self, id_receta: int, id_paciente: str | None = None) -> Optional[dict]:
        """Obtiene una receta con todos sus ingredientes, pasos y etiquetas."""
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

    def obtener_recetas_seguras_para_paciente(self, id_paciente: str, id_momento: Optional[int] = None, id_tipo_plato: Optional[int] = None, consulta: Optional[str] = None, limite: int = 100, offset: int = 0) -> List[dict]:
        # Preparar patrón de búsqueda para ILIKE
        search_pattern = f"%{consulta.strip()}%" if consulta and consulta.strip() else None
        
        with db_cursor() as cur:
            # SQL optimizado usando la vista pre-calculada
            sql = """
                with recetas_base as (
                  select * from nutricion.vista_recetas_detalle
                  where coalesce(activa,false)=true
                    and (%s::int is null or %s::int = any(momentos_ids))
                    and (%s::int is null or %s::int = any(tipos_plato_ids))
                    and (%s::text is null or nombre ilike %s::text)
                ),
                stats as (
                  select id_receta, round(avg(estrellas)::numeric, 1) as puntuacion_promedio, count(*) as total_evaluaciones
                  from interaccion.evaluacion_receta group by id_receta
                ),
                conds as (
                  select id_condicion from clinico.diagnostico_paciente where id_paciente = %s::uuid and esta_activo = true
                  union
                  select cca.id_condicion from clinico.control_condicion_activa cca join clinico.control_paciente cp on cp.id = cca.id_control
                  where cp.id_paciente = %s::uuid and cca.esta_activa = true
                ),
                reglas_raw as (
                  select upper(ca.nombre) as accion, r.id_ingrediente, r.id_subgrupo_alimentario, r.id_grupo_alimentario, r.id_receta
                  from heuristico.regla r join heuristico.catalogo_accion ca on ca.id = r.id_accion join heuristico.condicion_regla cr on cr.id_regla = r.id
                  where cr.id_condicion in (select id_condicion from conds) or cr.id_condicion = 164
                ),
                recoms as (
                   select id_ingrediente from clinico.recomendacion_ingrediente where id_paciente = %s::uuid and activa = true
                ),
                bloqueadas as (
                  select distinct rec.id from recetas_base rec
                  where exists (select 1 from clinico.alergia_paciente_ingrediente api where api.id_paciente = %s::uuid and api.activa = true and api.id_ingrediente = any(rec.ingredientes_ids))
                  or exists (select 1 from clinico.alergia_paciente_subgrupo aps where aps.id_paciente = %s::uuid and aps.activa = true and aps.id_subgrupo_alimentario = any(rec.subgrupos_ids))
                  or exists (select 1 from reglas_raw ra where ra.accion = 'ELIMINAR' and ( (ra.id_receta = rec.id) or (ra.id_ingrediente = any(rec.ingredientes_ids)) or (ra.id_subgrupo_alimentario = any(rec.subgrupos_ids)) ))
                ),
                clasificadas as (
                  select rec.*, coalesce(s.puntuacion_promedio, 0) as puntuacion_promedio, coalesce(s.total_evaluaciones, 0) as total_evaluaciones,
                         (exists (select 1 from reglas_raw ra where ra.accion = 'PRIORIZAR' and (ra.id_receta = rec.id or ra.id_ingrediente = any(rec.ingredientes_ids) or ra.id_subgrupo_alimentario = any(rec.subgrupos_ids))) 
                          or exists (select 1 from recoms rem where rem.id_ingrediente = any(rec.ingredientes_ids))) as es_potenciada,
                         exists (select 1 from reglas_raw ra where ra.accion = 'DISMINUIR' and (ra.id_receta = rec.id or ra.id_ingrediente = any(rec.ingredientes_ids) or ra.id_subgrupo_alimentario = any(rec.subgrupos_ids))) as es_disminuida
                  from recetas_base rec
                  left join stats s on s.id_receta = rec.id
                  where rec.id not in (select id from bloqueadas)
                )
                select c.*,
                       case when c.es_potenciada then 'verde' when c.es_disminuida then 'amarillo' else 'neutral' end as semaforo,
                       case when c.es_potenciada then 'Recomendada' when c.es_disminuida then 'Menos recomendada' else 'Normal' end as clasificacion_recomendacion,
                       case when c.es_potenciada then 'PRIORIZAR: recomendada para este paciente' when c.es_disminuida then 'DISMINUIR: usar con menor frecuencia' else 'Segura para el paciente' end as mensaje_regla
                from clasificadas c order by case when c.es_potenciada then 0 when c.es_disminuida then 1 else 2 end, c.nombre
                limit %s offset %s
            """
            params = (
                id_momento, id_momento, 
                id_tipo_plato, id_tipo_plato,
                search_pattern, search_pattern, 
                id_paciente, id_paciente, id_paciente, id_paciente, id_paciente, 
                limite, offset
            )
            cur.execute(sql, params)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

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
            return cur.rowcount > 0

    def guardar_receta(self, datos: dict) -> int:
        with db_cursor() as cur:
            id_receta = datos.get("id")
            dificultad = self._normalizar_dificultad(datos.get("dificultad"))
            t_prep = self._entero_o_default(datos.get("tiempo_preparacion_min"), 0)
            t_coc = self._entero_o_default(datos.get("tiempo_coccion_min"), 0)
            if id_receta:
                cur.execute("""
                    UPDATE nutricion.receta SET nombre = %s, descripcion = %s, descripcion_larga = %s, 
                    dificultad = %s, porciones = %s, tiempo_preparacion_min = %s, tiempo_coccion_min = %s, 
                    activa = %s, imagen_url = %s, updated_at = now() WHERE id = %s
                """, (datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"), dificultad, 
                      datos.get("porciones", 1), t_prep, t_coc, datos.get("activa", True), datos.get("imagen_url"), id_receta))
            else:
                cur.execute("""
                    INSERT INTO nutricion.receta (nombre, descripcion, descripcion_larga, dificultad, porciones, 
                    tiempo_preparacion_min, tiempo_coccion_min, activa, imagen_url)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
                """, (datos["nombre"], datos.get("descripcion"), datos.get("descripcion_larga"), dificultad, 
                      datos.get("porciones", 1), t_prep, t_coc, datos.get("activa", True), datos.get("imagen_url")))
                id_receta = cur.fetchone()[0]
            return id_receta

    def eliminar_receta(self, id_receta: int) -> bool:
        with db_cursor() as cur:
            cur.execute("DELETE FROM nutricion.receta WHERE id = %s", (id_receta,))
            return cur.rowcount > 0

    def listar_tipos_plato_disponibles_para_paciente(self, id_paciente: str, id_momento: Optional[int] = None) -> List[dict]:
        return []
