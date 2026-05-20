from typing import List, Optional
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioReceta
from ...domain.servicios.restricciones_alimentarias import RESTRICCIONES_ALIMENTARIAS, SUBGRUPOS_CON_LACTOSA

class RepositorioRecetaPostgres(IRepositorioReceta):
    def _normalizar_dificultad(self, valor: Optional[str]) -> str:
        if not valor:
            return "Media"
        dificultad = str(valor).strip()
        mapa = {
            "facil": "Fácil",
            "fácil": "Fácil",
            "fã¡cil": "Fácil",
            "fãƒâ¡cil": "Fácil",
            "media": "Media",
            "dificil": "Difícil",
            "difícil": "Difícil",
            "difã­cil": "Difícil",
            "difãƒâ­cil": "Difícil",
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

            # 2. Ingredientes con su composición técnica
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

            # 3. Pasos de preparación
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
                SELECT e.id, e.nombre_visible as titulo, e.descripcion as explicacion 
                FROM nutricion.receta_etiqueta re
                JOIN nutricion.etiqueta_nutricional e ON e.id = re.id_etiqueta
                WHERE re.id_receta = %s
            """, (id_receta,))
            columnas_etq = [desc[0] for desc in cur.description]
            receta['etiquetas_salud'] = [dict(zip(columnas_etq, r)) for r in cur.fetchall()]

            # 5. Nutrición Detallada (Vitaminas y Minerales)
            # Consultamos la tabla de composición para los micronutrientes
            # Nota: Aquí se podrían sumar de forma similar a la vista si se requiere precisión total
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
            cur.execute(sql, (id_momento,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_recetas_seguras_para_paciente(
        self,
        id_paciente: str,
        id_momento: Optional[int] = None,
        id_tipo_plato: Optional[int] = None,
    ) -> List[dict]:
        """
        Obtiene recetas filtrando prohibidas y marcando las que tienen ingredientes recomendados.
        """
        with db_cursor() as cur:
            # 1. Obtener ingredientes recomendados por medico/nutri
            cur.execute("select id_ingrediente from clinico.recomendacion_ingrediente where id_paciente = %s and activa = true", (id_paciente,))
            ing_recomendados = {r[0] for r in cur.fetchall()}

            # 2. Obtener recetas prohibidas (por el motor heuristico externo o calculo aqui)
            # Para simplificar, usaremos la lógica de ingredientes prohibidos
            cur.execute("select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s and activa = true", (id_paciente,))
            ing_prohibidos = {r[0] for r in cur.fetchall()}
            
            cur.execute("select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s and activa = true", (id_paciente,))
            sub_prohibidos = {r[0] for r in cur.fetchall()}

            codigos_restricciones = set()
            cur.execute("select to_regclass('clinico.restriccion_paciente')")
            if cur.fetchone()[0]:
                cur.execute(
                    "select codigo_restriccion from clinico.restriccion_paciente where id_paciente = %s and activa = true",
                    (id_paciente,),
                )
                codigos_restricciones = {str(r[0]).upper() for r in cur.fetchall()}
            if sub_prohibidos & SUBGRUPOS_CON_LACTOSA:
                codigos_restricciones.add("INTOLERANCIA_LACTOSA")

            etiquetas_bloqueadas = set()
            etiquetas_positivas = set()
            for codigo in codigos_restricciones:
                restriccion = RESTRICCIONES_ALIMENTARIAS.get(codigo)
                if not restriccion:
                    continue
                etiquetas_bloqueadas.update(restriccion.etiquetas_bloqueadas)
                etiquetas_positivas.update(restriccion.etiquetas_positivas)

            cur.execute(
                """
                with conds as (
                    select distinct id_condicion
                    from clinico.control_condicion_activa cca
                    join clinico.control_paciente cp on cp.id = cca.id_control
                    where cp.id_paciente = %s and cca.esta_activa = true
                    union
                    select distinct id_condicion
                    from clinico.diagnostico_paciente
                    where id_paciente = %s and esta_activo = true
                )
                select upper(a.nombre) as accion, upper(coalesce(r.origen_regla, 'CLINICA')) as origen,
                       r.id_ingrediente, r.id_grupo_alimentario, r.id_subgrupo_alimentario, r.id_receta
                from heuristico.regla r
                join heuristico.catalogo_accion a on a.id = r.id_accion
                join heuristico.condicion_regla cr on cr.id_regla = r.id
                join conds c on c.id_condicion = cr.id_condicion
                """
                ,
                (id_paciente, id_paciente),
            )
            reglas_activas = [dict(zip([d[0] for d in cur.description], row)) for row in cur.fetchall()]

            # 3. Traer todas las recetas del momento (o todas si id_momento es None)
            sql = """
                select r.id, r.nombre, r.imagen_url,
                       coalesce(round(sum((coalesce(ri.peso_en_gramos, 0)::numeric / 100) * coalesce(ic.energia_kcal, 0))::numeric, 2), 0) as calorias_totales,
                       coalesce(round(sum((coalesce(ri.peso_en_gramos, 0)::numeric / 100) * coalesce(ic.proteinas_g, 0))::numeric, 2), 0) as proteinas_totales,
                       coalesce(array_agg(ri.id_ingrediente) filter (where ri.id_ingrediente is not null), '{}') as ingredientes_ids,
                       coalesce(array_agg(distinct i.nombre) filter (where i.nombre is not null), '{}') as ingredientes_nombres,
                       coalesce(array_agg(i.id_grupo_alimentario) filter (where i.id_grupo_alimentario is not null), '{}') as grupos_ids,
                       coalesce(array_agg(i.id_subgrupo_alimentario) filter (where i.id_subgrupo_alimentario is not null), '{}') as subgrupos_ids,
                       coalesce(array_agg(distinct e.codigo) filter (where e.codigo is not null), '{}') as etiquetas_codigos,
                       coalesce(array_agg(distinct rtp.id_tipo_plato) filter (where rtp.id_tipo_plato is not null), '{}') as tipos_plato_ids
                from nutricion.receta r
                left join nutricion.receta_ingrediente ri on ri.id_receta = r.id
                left join nutricion.ingrediente i on i.id = ri.id_ingrediente
                left join nutricion.ingrediente_composicion ic on ic.id_ingrediente = ri.id_ingrediente
                left join nutricion.receta_etiqueta re on re.id_receta = r.id
                left join nutricion.etiqueta_nutricional e on e.id = re.id_etiqueta
                left join nutricion.receta_tipo_plato rtp on rtp.id_receta = r.id
            """
            params = []
            filtros = ["r.activa = true"]
            if id_momento:
                filtros.append(
                    "exists (select 1 from nutricion.receta_momento rm where rm.id_receta = r.id and rm.id_momento = %s)"
                )
                params.append(id_momento)
            if id_tipo_plato:
                filtros.append(
                    "exists (select 1 from nutricion.receta_tipo_plato rtp_f where rtp_f.id_receta = r.id and rtp_f.id_tipo_plato = %s)"
                )
                params.append(id_tipo_plato)
            sql += " where " + " and ".join(filtros)
            
            sql += " group by r.id, r.nombre, r.imagen_url"
            
            cur.execute(sql, params)
            columnas = [desc[0] for desc in cur.description]
            recetas_raw = [dict(zip(columnas, row)) for row in cur.fetchall()]
            
            resultado = []
            for r in recetas_raw:
                ing_receta = set(r["ingredientes_ids"])
                grupos_receta = set(r.get("grupos_ids") or [])
                sub_receta = set(r["subgrupos_ids"])
                etiquetas_receta = set(r.get("etiquetas_codigos") or [])
                
                # Filtro de seguridad: ¿Tiene algo prohibido?
                if (ing_receta & ing_prohibidos) or (sub_receta & sub_prohibidos):
                    continue
                if etiquetas_receta & etiquetas_bloqueadas:
                    continue
                
                # Marcado de potenciacion y semáforo visual.
                r["es_potenciada"] = bool(ing_receta & ing_recomendados)
                r["etiquetas_seguridad"] = sorted(etiquetas_receta & etiquetas_positivas)
                def _match(regla: dict) -> bool:
                    return (
                        (regla.get("id_receta") and regla["id_receta"] == r["id"])
                        or (regla.get("id_ingrediente") and regla["id_ingrediente"] in ing_receta)
                        or (regla.get("id_subgrupo_alimentario") and regla["id_subgrupo_alimentario"] in sub_receta)
                        or (regla.get("id_grupo_alimentario") and regla["id_grupo_alimentario"] in grupos_receta)
                    )

                hits = [rg for rg in reglas_activas if _match(rg)]
                prior_med = any(h["accion"] == "PRIORIZAR" and h["origen"] != "NUTRICIONAL" for h in hits)
                prior_nut = any(h["accion"] == "PRIORIZAR" and h["origen"] == "NUTRICIONAL" for h in hits)
                dism_med = any(h["accion"] == "DISMINUIR" and h["origen"] != "NUTRICIONAL" for h in hits)
                dism_nut = any(h["accion"] == "DISMINUIR" and h["origen"] == "NUTRICIONAL" for h in hits)
                elim_med = any(h["accion"] == "ELIMINAR" and h["origen"] != "NUTRICIONAL" for h in hits)
                elim_nut = any(h["accion"] == "ELIMINAR" and h["origen"] == "NUTRICIONAL" for h in hits)

                if elim_med:
                    continue
                if elim_nut and not prior_med:
                    continue

                if prior_med or prior_nut or r["es_potenciada"]:
                    r["semaforo"] = "verde"
                    r["mensaje_regla"] = "RECOMENDABLE: priorizar para reumáticos"
                elif dism_med or dism_nut:
                    r["semaforo"] = "amarillo"
                    r["mensaje_regla"] = "DISMINUIR: 1 o 2 veces por semana, no en días seguidos"
                else:
                    r["semaforo"] = "neutral"
                    r["mensaje_regla"] = "Segura para el paciente"
                resultado.append(r)
            
            # Ordenar: verde, luego amarillo, luego neutral
            prioridad = {"verde": 0, "amarillo": 1, "neutral": 2}
            resultado.sort(key=lambda x: (prioridad.get(x.get("semaforo"), 9), x.get("nombre", "")))
            return resultado

    def cambiar_estado_receta(self, id_receta: int, activa: bool) -> bool:
        with db_cursor() as cur:
            cur.execute("UPDATE nutricion.receta SET activa = %s, updated_at = now() WHERE id = %s", (activa, id_receta))
            return cur.rowcount > 0

    def guardar_receta(self, datos: dict) -> int:
        """Crea o actualiza una receta completa (Información, ingredientes y pasos)."""
        with db_cursor() as cur:
            id_receta = datos.get("id")
            dificultad = self._normalizar_dificultad(datos.get("dificultad"))
            tiempo_preparacion = self._entero_o_default(
                datos.get("tiempo_preparacion", datos.get("tiempo_preparacion_min")),
                0,
            )
            tiempo_coccion = self._entero_o_default(
                datos.get("tiempo_coccion", datos.get("tiempo_coccion_min")),
                0,
            )
            
            # 1. Upsert de la información básica
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
            # El módulo Horarios y Menús los agrega por reglas sin borrar los existentes.
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
                cur.execute("""
                    INSERT INTO nutricion.receta_momento (id_receta, id_momento)
                    SELECT DISTINCT %s, rm.id_momento
                    FROM nutricion.regla_momento_comida rm
                    JOIN nutricion.regla_momento_tipo_receta rt ON rt.id_regla_momento = rm.id
                    WHERE rt.id_tipo_plato = ANY(%s)
                      AND rm.activo = true
                      AND rt.activo = true
                    ON CONFLICT DO NOTHING
                """, (id_receta, tipos_plato))

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
            etiquetas_ids = list(set([etq.get("id") for etq in datos.get("etiquetas_salud", []) if etq.get("id")]))
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
        """Elimina una receta y todas sus dependencias en nutrición e interacción."""
        with db_cursor() as cur:
            # 1. Limpiar dependencias en el módulo de interacción (Planes y Seguimiento)
            # Primero seguimiento (por FK a plan_item y a receta_reemplazo)
            cur.execute("DELETE FROM interaccion.seguimiento_plan_item WHERE id_receta_reemplazo = %s", (id_receta,))
            cur.execute("""
                DELETE FROM interaccion.seguimiento_plan_item 
                WHERE id_plan_item IN (SELECT id FROM interaccion.plan_item WHERE id_receta = %s)
            """, (id_receta,))
            
            # Luego los ítems del plan nutricional
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
