from typing import List, Optional
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
            "facil": "FÃ¡cil",
            "fÃ¡cil": "FÃ¡cil",
            "fÃ£Â¡cil": "FÃ¡cil",
            "fÃ£Æ’Ã¢Â¡cil": "FÃ¡cil",
            "media": "Media",
            "dificil": "DifÃ­cil",
            "difÃ­cil": "DifÃ­cil",
            "difÃ£Â­cil": "DifÃ­cil",
            "difÃ£Æ’Ã¢Â­cil": "DifÃ­cil",
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
                COALESCE(
                    ROUND(
                        SUM((COALESCE(ri.peso_en_gramos, 0)::numeric / 100) * COALESCE(ic.energia_kcal, 0))::numeric
                        / GREATEST(COALESCE(r.porciones, 1), 1),
                        2
                    ),
                    0
                ) AS calorias_por_porcion,
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
                ) AS categoria
            FROM nutricion.receta r
            LEFT JOIN nutricion.receta_ingrediente ri ON ri.id_receta = r.id
            LEFT JOIN nutricion.ingrediente_composicion ic ON ic.id_ingrediente = ri.id_ingrediente
            WHERE {where_clause}
            GROUP BY r.id
        """

    def _inferir_etiquetas_por_ingredientes(self, cur, id_receta: int) -> set[int]:
        """
        Etiquetado inteligente conservador orientado a LES/AIJ:
        - Propaga etiqueta si aparece en ingrediente principal.
        - O si la suma de gramos de ingredientes con esa etiqueta representa >= 20% del peso total.
        - Solo considera etiquetas que existen en reglas clÃ­nicas especÃ­ficas LES/AIJ.
        """
        etiquetas_objetivo = self._obtener_etiquetas_objetivo_les_aij(cur)
        if not etiquetas_objetivo:
            return set()

        cur.execute(
            """
            select
                ri.id_ingrediente,
                coalesce(ri.peso_en_gramos, 0)::numeric as gramos,
                coalesce(ri.es_principal, false) as es_principal
            from nutricion.receta_ingrediente ri
            where ri.id_receta = %s
            """,
            (id_receta,),
        )
        rows = cur.fetchall()
        if not rows:
            return set()

        ids_ingredientes = [int(r[0]) for r in rows if r[0] is not None]
        if not ids_ingredientes:
            return set()

        gramos_por_ing: dict[int, float] = {}
        principales: set[int] = set()
        total_gramos = 0.0
        for iid, gramos, es_principal in rows:
            iid = int(iid)
            g = float(gramos or 0)
            gramos_por_ing[iid] = gramos_por_ing.get(iid, 0.0) + g
            total_gramos += g
            if es_principal:
                principales.add(iid)

        cur.execute(
            """
            select ie.id_ingrediente, ie.id_etiqueta
            from nutricion.ingrediente_etiqueta ie
            where ie.id_ingrediente = any(%s)
              and ie.id_etiqueta = any(%s)
            """,
            (ids_ingredientes, list(etiquetas_objetivo)),
        )
        rels = cur.fetchall()
        if not rels:
            return set()

        por_etiqueta_gramos: dict[int, float] = {}
        por_etiqueta_principal: set[int] = set()
        for iid, etq in rels:
            iid = int(iid)
            etq = int(etq)
            por_etiqueta_gramos[etq] = por_etiqueta_gramos.get(etq, 0.0) + gramos_por_ing.get(iid, 0.0)
            if iid in principales:
                por_etiqueta_principal.add(etq)

        inferidas: set[int] = set()
        for etq, gramos_etq in por_etiqueta_gramos.items():
            ratio = (gramos_etq / total_gramos) if total_gramos > 0 else 0.0
            if etq in por_etiqueta_principal or ratio >= 0.20:
                inferidas.add(etq)
        return inferidas

    def listar_recetas(self, consulta: str = "", limite: int = 1000) -> List[dict]:
        """Lista recetas calculando la nutricion desde sus ingredientes."""
        where_clause = "TRUE"
        params = []

        if consulta:
            stop_words = {'de', 'con', 'en', 'el', 'la', 'los', 'las', 'un', 'una', 'para', 'sin', 'y', 'del'}
            words = [w.lower().strip() for w in consulta.split(' ') if w.lower().strip() not in stop_words and len(w.strip()) > 2]
            if not words and consulta.strip(): words = [consulta.lower().strip()]
            
            if words:
                word_conditions = []
                for w in words:
                    # Busqueda por palabra completa usando regex con ancla de limite (\y)
                    word_conditions.append("r.nombre ~* %s")
                    pattern = f"\\y{w}\\y"
                    params.append(pattern)
                where_clause += " and (" + " and ".join(word_conditions) + ")"

        sql = self._sql_receta_detalle_base(where_clause) + """
            ORDER BY r.activa DESC, nombre ASC
            LIMIT %s
        """
        params.append(limite)

        with db_cursor() as cur:
            cur.execute(sql, params)
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_detalle_completo(self, id_receta: int) -> Optional[dict]:
        """Obtiene una receta con todos sus ingredientes, pasos y etiquetas."""
        with db_cursor() as cur:
            # 1. Datos basicos y nutricionales calculados desde ingredientes
            cur.execute(self._sql_receta_detalle_base("r.id = %s"), (id_receta,))
            row = cur.fetchone()
            if not row:
                return None
            
            columnas = [desc[0] for desc in cur.description]
            receta = dict(zip(columnas, row))

            # 1.1 Momentos de Comida
            cur.execute("SELECT id_momento FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
            receta['momentos'] = [r[0] for r in cur.fetchall()]

            # 1.2 Tipos de Plato
            cur.execute("SELECT id_tipo_plato FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            receta['tipos_plato'] = [r[0] for r in cur.fetchall()]

            # 2. Ingredientes con su composiciÃ³n tÃ©cnica
            cur.execute("""
                SELECT 
                    ri.id_ingrediente, 
                    i.nombre, 
                    ri.cantidad_visual as cantidad, 
                    ri.unidad_visual as unidad, 
                    ri.peso_en_gramos as gramos, 
                    ri.observaciones,
                    ri.es_principal
                FROM nutricion.receta_ingrediente ri
                JOIN nutricion.ingrediente i ON i.id = ri.id_ingrediente
                WHERE ri.id_receta = %s
                ORDER BY ri.id ASC
            """, (id_receta,))
            columnas_ing = [desc[0] for desc in cur.description]
            receta['ingredientes'] = [dict(zip(columnas_ing, r)) for r in cur.fetchall()]

            # 3. Pasos de preparaciÃ³n
            cur.execute("""
                SELECT numero_paso as paso, descripcion, tiempo_estimado as tiempo, nota_adicional as nota
                FROM nutricion.receta_paso
                WHERE id_receta = %s
                ORDER BY numero_paso ASC
            """, (id_receta,))
            columnas_paso = [desc[0] for desc in cur.description]
            receta['preparacion'] = [dict(zip(columnas_paso, r)) for r in cur.fetchall()]

            # 4. Etiquetas de salud
            cur.execute("""
                SELECT e.id, e.nombre_visible as titulo, e.descripcion as explicacion, e.codigo
                FROM nutricion.receta_etiqueta re
                JOIN nutricion.etiqueta_nutricional e ON e.id = re.id_etiqueta
                WHERE re.id_receta = %s
            """, (id_receta,))
            columnas_etq = [desc[0] for desc in cur.description]
            receta['etiquetas_salud'] = [dict(zip(columnas_etq, r)) for r in cur.fetchall()]

            # 5. NutriciÃ³n Detallada (Vitaminas y Minerales)
            # Consultamos la tabla de composiciÃ³n para los micronutrientes
            # Nota: AquÃ­ se podrÃ­an sumar de forma similar a la vista si se requiere precisiÃ³n total
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
                        {"nombre": "Vitamina A", "valor": round(float(micro[0] or 0), 2), "unidad": "Âµg"},
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
            cur.execute(sql, (id_momento,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_recetas_seguras_para_paciente(
        self,
        id_paciente: str,
        id_momento: Optional[int] = None,
        id_tipo_plato: Optional[int] = None,
    ) -> List[dict]:
        with db_cursor() as cur:
            cur.execute(
                """
                with recetas as (
                  select
                    r.id,
                    r.nombre,
                    r.imagen_url,
                    coalesce(round(sum((coalesce(ri.peso_en_gramos,0)::numeric/100)*coalesce(ic.energia_kcal,0))::numeric,2),0) as calorias_totales,
                    coalesce(round(sum((coalesce(ri.peso_en_gramos,0)::numeric/100)*coalesce(ic.proteinas_g,0))::numeric,2),0) as proteinas_totales,
                    coalesce(array_agg(distinct ri.id_ingrediente) filter (where ri.id_ingrediente is not null), '{}') as ingredientes_ids,
                    coalesce(array_agg(distinct i.id_grupo_alimentario) filter (where i.id_grupo_alimentario is not null), '{}') as grupos_ids,
                    coalesce(array_agg(distinct i.id_subgrupo_alimentario) filter (where i.id_subgrupo_alimentario is not null), '{}') as subgrupos_ids,
                    coalesce(array_agg(distinct en.codigo) filter (where en.codigo is not null), '{}') as etiquetas_codigos,
                    coalesce(array_agg(distinct i.nombre) filter (where i.nombre is not null), '{}') as ingredientes_nombres,
                    coalesce(array_agg(distinct rtp.id_tipo_plato) filter (where rtp.id_tipo_plato is not null), '{}') as tipos_plato_ids
                  from nutricion.receta r
                  left join nutricion.receta_ingrediente ri on ri.id_receta = r.id
                  left join nutricion.ingrediente i on i.id = ri.id_ingrediente
                  left join nutricion.ingrediente_composicion ic on ic.id_ingrediente = ri.id_ingrediente
                  left join nutricion.receta_etiqueta re on re.id_receta = r.id
                  left join nutricion.etiqueta_nutricional en on en.id = re.id_etiqueta
                  left join nutricion.receta_tipo_plato rtp on rtp.id_receta = r.id
                  where coalesce(r.activa,false)=true
                    and (%s::int is null or exists (
                      select 1 from nutricion.receta_momento rm
                      where rm.id_receta = r.id and rm.id_momento = %s::int
                    ))
                    and (%s::int is null or exists (
                      select 1 from nutricion.receta_tipo_plato rtpf
                      where rtpf.id_receta = r.id and rtpf.id_tipo_plato = %s::int
                    ))
                    and (
                      %s::int is null
                      or %s::int is null
                      or exists (
                        select 1
                        from nutricion.momento_tipo_plato_factible mtpf
                        where mtpf.id_momento = %s::int
                          and mtpf.id_tipo_plato = %s::int
                      )
                    )
                  group by r.id, r.nombre, r.imagen_url
                ),
                conds as (
                  select id as id_condicion from heuristico.condicion 
                  where activa = true and (indicador_codigo = 'GENERAL_REUMATICOS' or nombre = 'general reumaticos')
                  union
                  select distinct id_condicion
                  from clinico.diagnostico_paciente
                  where id_paciente = %s::uuid and coalesce(esta_activo,false)=true
                  union
                  select distinct cca.id_condicion
                  from clinico.control_condicion_activa cca
                  join clinico.control_paciente cp on cp.id = cca.id_control
                  where cp.id_paciente = %s::uuid and coalesce(cca.esta_activa,false)=true
                ),
                reglas_aplicables as (
                  select
                    upper(ca.nombre) as accion,
                    r.id_ingrediente, r.id_subgrupo_alimentario, r.id_grupo_alimentario, r.id_etiqueta, r.id_receta
                  from heuristico.regla r
                  join heuristico.catalogo_accion ca on ca.id = r.id_accion
                  join heuristico.condicion_regla cr on cr.id_regla = r.id
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
                bloqueadas as (
                  select distinct rec.id
                  from recetas rec
                  where exists (
                    select 1
                    from clinico.alergia_paciente_ingrediente api
                    where api.id_paciente = %s::uuid
                      and coalesce(api.activa,false)=true
                      and api.id_ingrediente = any(rec.ingredientes_ids)
                  )
                  or exists (
                    select 1
                    from clinico.alergia_paciente_subgrupo aps
                    where aps.id_paciente = %s::uuid
                      and coalesce(aps.activa,false)=true
                      and aps.id_subgrupo_alimentario = any(rec.subgrupos_ids)
                  )
                  or exists (
                    select 1
                    from restricciones_bloqueantes rb
                    where rb.codigo is not null
                      and rb.codigo = any(rec.etiquetas_codigos)
                  )
                  or exists (
                    select 1
                    from reglas_aplicables ra
                    where ra.accion = 'ELIMINAR'
                      and (
                        (ra.id_receta is not null and ra.id_receta = rec.id)
                        or (ra.id_ingrediente is not null and ra.id_ingrediente = any(rec.ingredientes_ids))
                        or (ra.id_subgrupo_alimentario is not null and ra.id_subgrupo_alimentario = any(rec.subgrupos_ids))
                        or (ra.id_grupo_alimentario is not null and ra.id_grupo_alimentario = any(rec.grupos_ids))
                        or (ra.id_etiqueta is not null and exists (
                          select 1 from nutricion.etiqueta_nutricional e2
                          where e2.id = ra.id_etiqueta and e2.codigo = any(rec.etiquetas_codigos)
                        ))
                      )
                  )
                ),
                clasificadas as (
                  select
                    rec.*,
                    exists (
                      select 1 from clinico.recomendacion_ingrediente ri
                      where ri.id_paciente = %s::uuid
                        and coalesce(ri.activa,false)=true
                        and ri.id_ingrediente = any(rec.ingredientes_ids)
                    ) as es_potenciada,
                    exists (
                      select 1
                      from reglas_aplicables ra
                      where ra.accion = 'PRIORIZAR'
                        and (
                          (ra.id_receta is not null and ra.id_receta = rec.id)
                          or (ra.id_ingrediente is not null and ra.id_ingrediente = any(rec.ingredientes_ids))
                          or (ra.id_subgrupo_alimentario is not null and ra.id_subgrupo_alimentario = any(rec.subgrupos_ids))
                          or (ra.id_grupo_alimentario is not null and ra.id_grupo_alimentario = any(rec.grupos_ids))
                          or (ra.id_etiqueta is not null and exists (
                            select 1 from nutricion.etiqueta_nutricional e2
                            where e2.id = ra.id_etiqueta and e2.codigo = any(rec.etiquetas_codigos)
                          ))
                        )
                    ) as tiene_priorizar,
                    exists (
                      select 1
                      from reglas_aplicables ra
                      where ra.accion = 'DISMINUIR'
                        and (
                          (ra.id_receta is not null and ra.id_receta = rec.id)
                          or (ra.id_ingrediente is not null and ra.id_ingrediente = any(rec.ingredientes_ids))
                          or (ra.id_subgrupo_alimentario is not null and ra.id_subgrupo_alimentario = any(rec.subgrupos_ids))
                          or (ra.id_grupo_alimentario is not null and ra.id_grupo_alimentario = any(rec.grupos_ids))
                          or (ra.id_etiqueta is not null and exists (
                            select 1 from nutricion.etiqueta_nutricional e2
                            where e2.id = ra.id_etiqueta and e2.codigo = any(rec.etiquetas_codigos)
                          ))
                        )
                    ) as tiene_disminuir
                  from recetas rec
                  where rec.id not in (select id from bloqueadas)
                )
                select
                  c.id, c.nombre, c.imagen_url, c.calorias_totales, c.proteinas_totales,
                  c.ingredientes_ids, c.ingredientes_nombres, c.grupos_ids, c.subgrupos_ids, c.etiquetas_codigos, c.tipos_plato_ids,
                  case
                    when c.tiene_priorizar or c.es_potenciada then 'verde'
                    when c.tiene_disminuir then 'amarillo'
                    else 'neutral'
                  end as semaforo,
                  case
                    when c.tiene_priorizar or c.es_potenciada then 'PRIORIZAR: recomendada para este paciente'
                    when c.tiene_disminuir then 'DISMINUIR: usar con menor frecuencia'
                    else 'Segura para el paciente'
                  end as mensaje_regla,
                  case
                    when c.tiene_priorizar or c.es_potenciada then 'Recomendada'
                    when c.tiene_disminuir then 'Menos recomendada'
                    else 'Normal'
                  end as clasificacion_recomendacion,
                  c.es_potenciada
                from clasificadas c
                order by
                  case
                    when c.tiene_priorizar or c.es_potenciada then 0
                    when c.tiene_disminuir then 2
                    else 1
                  end,
                  c.nombre
                """,
                (
                    id_momento, id_momento,
                    id_tipo_plato, id_tipo_plato,
                    id_momento, id_tipo_plato, id_momento, id_tipo_plato,
                    id_paciente, id_paciente,
                    id_paciente,
                    id_paciente, id_paciente,
                    id_paciente,
                ),
            )
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def listar_tipos_plato_disponibles_para_paciente(
        self,
        id_paciente: str,
        id_momento: Optional[int] = None,
    ) -> List[dict]:
        # Consulta unica: evita N+1 llamadas al motor de recetas por cada tipo de plato.
        with db_cursor() as cur:
            cur.execute(
                """
                with recetas_base as (
                  select
                    r.id,
                    coalesce(array_agg(distinct ri.id_ingrediente) filter (where ri.id_ingrediente is not null), '{}') as ingredientes_ids,
                    coalesce(array_agg(distinct i.id_grupo_alimentario) filter (where i.id_grupo_alimentario is not null), '{}') as grupos_ids,
                    coalesce(array_agg(distinct i.id_subgrupo_alimentario) filter (where i.id_subgrupo_alimentario is not null), '{}') as subgrupos_ids,
                    coalesce(array_agg(distinct en.codigo) filter (where en.codigo is not null), '{}') as etiquetas_codigos
                  from nutricion.receta r
                  left join nutricion.receta_ingrediente ri on ri.id_receta = r.id
                  left join nutricion.ingrediente i on i.id = ri.id_ingrediente
                  left join nutricion.receta_etiqueta re on re.id_receta = r.id
                  left join nutricion.etiqueta_nutricional en on en.id = re.id_etiqueta
                  where coalesce(r.activa, false) = true
                    and (%s::int is null or exists (
                      select 1
                      from nutricion.receta_momento rm
                      where rm.id_receta = r.id
                        and rm.id_momento = %s::int
                    ))
                  group by r.id
                ),
                conds as (
                  select id as id_condicion from heuristico.condicion 
                  where activa = true and (indicador_codigo = 'GENERAL_REUMATICOS' or nombre = 'general reumaticos')
                  union
                  select distinct id_condicion
                  from clinico.diagnostico_paciente
                  where id_paciente = %s::uuid and coalesce(esta_activo,false)=true
                  union
                  select distinct cca.id_condicion
                  from clinico.control_condicion_activa cca
                  join clinico.control_paciente cp on cp.id = cca.id_control
                  where cp.id_paciente = %s::uuid and coalesce(cca.esta_activa,false)=true
                ),
                reglas_aplicables as (
                  select
                    upper(ca.nombre) as accion,
                    r.id_ingrediente, r.id_subgrupo_alimentario, r.id_grupo_alimentario, r.id_etiqueta, r.id_receta
                  from heuristico.regla r
                  join heuristico.catalogo_accion ca on ca.id = r.id_accion
                  join heuristico.condicion_regla cr on cr.id_regla = r.id
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
                recetas_seguras as (
                  select rb.id
                  from recetas_base rb
                  where not exists (
                    select 1
                    from clinico.alergia_paciente_ingrediente api
                    where api.id_paciente = %s::uuid
                      and coalesce(api.activa,false)=true
                      and api.id_ingrediente = any(rb.ingredientes_ids)
                  )
                  and not exists (
                    select 1
                    from clinico.alergia_paciente_subgrupo aps
                    where aps.id_paciente = %s::uuid
                      and coalesce(aps.activa,false)=true
                      and aps.id_subgrupo_alimentario = any(rb.subgrupos_ids)
                  )
                  and not exists (
                    select 1
                    from restricciones_bloqueantes rbl
                    where rbl.codigo is not null
                      and rbl.codigo = any(rb.etiquetas_codigos)
                  )
                  and not exists (
                    select 1
                    from reglas_aplicables ra
                    where ra.accion = 'ELIMINAR'
                      and (
                        (ra.id_receta is not null and ra.id_receta = rb.id)
                        or (ra.id_ingrediente is not null and ra.id_ingrediente = any(rb.ingredientes_ids))
                        or (ra.id_subgrupo_alimentario is not null and ra.id_subgrupo_alimentario = any(rb.subgrupos_ids))
                        or (ra.id_grupo_alimentario is not null and ra.id_grupo_alimentario = any(rb.grupos_ids))
                        or (ra.id_etiqueta is not null and exists (
                          select 1 from nutricion.etiqueta_nutricional e2
                          where e2.id = ra.id_etiqueta and e2.codigo = any(rb.etiquetas_codigos)
                        ))
                      )
                  )
                )
                select
                  tp.id as id_tipo_plato,
                  tp.nombre as tipo_plato_nombre,
                  count(distinct rs.id)::int as total_recetas
                from recetas_seguras rs
                join nutricion.receta_tipo_plato rtp on rtp.id_receta = rs.id
                join nutricion.tipo_plato tp on tp.id = rtp.id_tipo_plato
                left join nutricion.momento_tipo_plato_factible mtpf
                  on mtpf.id_tipo_plato = tp.id
                 and mtpf.id_momento = %s::int
                where (%s::int is null or mtpf.id is not null)
                group by tp.id, tp.nombre
                order by tp.nombre
                """,
                (
                    id_momento, id_momento,
                    id_paciente, id_paciente,
                    id_paciente,
                    id_paciente, id_paciente,
                    id_momento, id_momento,
                ),
            )
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def cambiar_estado_receta(self, id_receta: int, activa: bool) -> bool:
        with db_cursor() as cur:
            cur.execute("UPDATE nutricion.receta SET activa = %s, updated_at = now() WHERE id = %s", (activa, id_receta))
            return cur.rowcount > 0

    def guardar_receta(self, datos: dict) -> int:
        """Crea o actualiza una receta completa (InformaciÃ³n, ingredientes y pasos)."""
        with db_cursor() as cur:
            id_receta = datos.get("id")
            # Permitir actualizacion manual progresiva de recetas existentes.
            # El bloqueo estricto se mantiene para nuevas recetas.
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
            
            # 1. Upsert de la informaciÃ³n bÃ¡sica
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

            # 2. Momentos de comida: solo se sincronizan si el payload los trae.
            # El mÃ³dulo Horarios y MenÃºs los agrega por reglas sin borrar los existentes.
            if "momentos" in datos:
                cur.execute("DELETE FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
                momentos = list(set(datos.get("momentos") or [])) # Deduplicar
                if momentos:
                    mom_values = [(id_receta, mid) for mid in momentos if mid]
                    cur.executemany("INSERT INTO nutricion.receta_momento (id_receta, id_momento) VALUES (%s, %s) ON CONFLICT DO NOTHING", mom_values)

            # 3. Sincronizar Tipos de Plato (receta_tipo_plato)
            cur.execute("DELETE FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            tipos_plato = list(set(datos.get("tipos_plato", []))) # Deduplicar
            if tipos_plato:
                tp_values = [(id_receta, tid) for tid in tipos_plato if tid]
                cur.executemany("INSERT INTO nutricion.receta_tipo_plato (id_receta, id_tipo_plato) VALUES (%s, %s) ON CONFLICT DO NOTHING", tp_values)
                # Compatibilidad de esquema:
                # En la base actual se usa momento_tipo_plato_factible.
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

            # 6. Sincronizar Etiquetas (Manuales y Validadas desde el Frontend)
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))
            # Deduplicar IDs de etiquetas
            etiquetas_manuales = {
                int(etq.get("id"))
                for etq in datos.get("etiquetas_salud", [])
                if etq.get("id")
            }
            etiquetas_ids = sorted(etiquetas_manuales)
            if etiquetas_ids:
                etq_values = [(id_receta, eid) for eid in etiquetas_ids]
                cur.executemany("INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta) VALUES (%s, %s) ON CONFLICT DO NOTHING", etq_values)

            # 7. Sincronizar nutricion.receta_imagen (Regresado al esquema nutricion)
            img_url = datos.get("imagen_url")
            if img_url:
                # Limpiar previas en nutricion.receta_imagen
                cur.execute("DELETE FROM nutricion.receta_imagen WHERE id_receta = %s", (id_receta,))
                cur.execute(
                    "INSERT INTO nutricion.receta_imagen (id_receta, imagen_url) VALUES (%s, %s)",
                    (id_receta, img_url)
                )

            return id_receta

    def listar_momentos_comida(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.momento_comida WHERE activo = true ORDER BY orden")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def listar_tipos_plato(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("SELECT id, nombre FROM nutricion.tipo_plato ORDER BY nombre")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def eliminar_receta(self, id_receta: int) -> bool:
        """Elimina una receta y todas sus dependencias en nutriciÃ³n e interacciÃ³n."""
        with db_cursor() as cur:
            # 1. Limpiar dependencias en el mÃ³dulo de interacciÃ³n (Planes y Seguimiento)
            # Primero seguimiento (por FK a plan_item y a receta_reemplazo)
            cur.execute("DELETE FROM interaccion.seguimiento_plan_item WHERE id_receta_reemplazo = %s", (id_receta,))
            cur.execute("""
                DELETE FROM interaccion.seguimiento_plan_item 
                WHERE id_plan_item IN (SELECT id FROM interaccion.plan_item WHERE id_receta = %s)
            """, (id_receta,))
            
            # Luego los Ã­tems del plan nutricional
            cur.execute("DELETE FROM interaccion.plan_item WHERE id_receta = %s", (id_receta,))
            
            # Limpiar preferencias y evaluaciones si las tablas existen
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

            # 2. Limpiar dependencias en el esquema nutricion
            cur.execute("DELETE FROM nutricion.receta_etiqueta WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_ingrediente WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_paso WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_momento WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_tipo_plato WHERE id_receta = %s", (id_receta,))
            cur.execute("DELETE FROM nutricion.receta_imagen WHERE id_receta = %s", (id_receta,))
            
            # 3. Finalmente eliminar la receta
            cur.execute("DELETE FROM nutricion.receta WHERE id = %s", (id_receta,))
            return cur.rowcount > 0



