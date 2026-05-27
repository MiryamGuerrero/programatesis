from typing import List, Dict, Set
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioIngrediente
from ...domain.servicios.restricciones_alimentarias import (
    RESTRICCIONES_ALIMENTARIAS,
    resolver_codigo_restriccion,
)

# Subgrupos que contienen lactosa (para deteccion automatica de intolerancia)
SUBGRUPOS_CON_LACTOSA: Set[int] = {
    98,   # Leches animales (con lactosa)
    100,  # Natas y cremas de leche (con lactosa)
    101,  # Yogures animales (con lactosa)
    104,  # Leches fermentadas animales (con lactosa)
    105,  # Quesos frescos (con lactosa)
    108,  # Quesos procesados y en lonchas (con lactosa)
    111,  # Mantequillas (lacteo, con lactosa)
    114,  # Salsas con lacteos (con lactosa)
    117,  # Chocolates con leche (con lactosa)
    119,  # Dulces con lacteos (con lactosa)
}

class RepositorioIngredientePostgres(IRepositorioIngrediente):
    def _expandir_restricciones_paciente(self, cur, id_paciente: str) -> tuple[set[int], set[int]]:
        cur.execute("select to_regclass('clinico.restriccion_paciente')")
        if not cur.fetchone()[0]:
            return set(), set()

        cur.execute(
            """
            select codigo_restriccion
            from clinico.restriccion_paciente
            where id_paciente = %s and activa = true
            """,
            (id_paciente,),
        )
        codigos = {str(r[0]).strip().upper() for r in cur.fetchall() if r and r[0]}
        subgrupos: set[int] = set()
        ingredientes: set[int] = set()

        for codigo in codigos:
            restriccion = RESTRICCIONES_ALIMENTARIAS.get(resolver_codigo_restriccion(codigo))
            if not restriccion:
                continue
            subgrupos.update(restriccion.subgrupos_ids)
            ingredientes.update(restriccion.ingredientes_ids)

            for patron in restriccion.patrones_subgrupo:
                cur.execute(
                    "select id from nutricion.subgrupo_alimentario where lower(nombre) like %s",
                    (f"%{patron.lower()}%",),
                )
                subgrupos.update(r[0] for r in cur.fetchall())

            for patron in restriccion.patrones_ingrediente:
                cur.execute(
                    "select id from nutricion.ingrediente where lower(nombre) like %s",
                    (f"%{patron.lower()}%",),
                )
                ingredientes.update(r[0] for r in cur.fetchall())

            if restriccion.etiquetas_bloqueadas:
                cur.execute(
                    """
                    select distinct ie.id_ingrediente
                    from nutricion.ingrediente_etiqueta ie
                    join nutricion.etiqueta_nutricional e on e.id = ie.id_etiqueta
                    where e.codigo = any(%s)
                    """,
                    (list(restriccion.etiquetas_bloqueadas),),
                )
                ingredientes.update(r[0] for r in cur.fetchall())

        return subgrupos, ingredientes

    def listar_todos_activos(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("select id, nombre, id_grupo_alimentario, id_subgrupo_alimentario from nutricion.ingrediente where activo = true")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def listar_ingredientes_admin(self, consulta: str = None, limite: int = 100, desplazamiento: int = 0, incluir_inactivos: bool = False, id_grupo: int = None, id_subgrupo: int = None) -> List[dict]:
        where_clauses = ["(%s or i.activo = true)"]
        params = [incluir_inactivos]

        if consulta:
            # Dividir la consulta en palabras significativas
            stop_words = {'de', 'con', 'en', 'el', 'la', 'los', 'las', 'un', 'una', 'para', 'sin', 'y', 'del'}
            words = [w.lower().strip() for w in consulta.split(' ') if w.lower().strip() not in stop_words and len(w.strip()) > 2]
            if not words and consulta.strip(): words = [consulta.lower().strip()]
            
            if words:
                # Construir una condicion que busque cada palabra como palabra completa o al inicio/fin
                word_conditions = []
                for w in words:
                    # Busqueda por palabra completa usando el ancla de limite de palabra de Postgres (\y)
                    # Esto maneja correctamente signos de puntuacion como comas o parentesis
                    word_conditions.append("(i.nombre ~* %s or exists (select 1 from unnest(i.sinonimos) s where s ~* %s))")
                    pattern = f"\\y{w}\\y"
                    params.extend([pattern, pattern])
                
                where_clauses.append("(" + " and ".join(word_conditions) + ")")

        if id_grupo:
            where_clauses.append("i.id_grupo_alimentario = %s")
            params.append(id_grupo)
        
        if id_subgrupo:
            where_clauses.append("i.id_subgrupo_alimentario = %s")
            params.append(id_subgrupo)
            
        where_sql = " AND ".join(where_clauses)
        
        sql = f"""
            with etiquetas_agg as (
                select ie.id_ingrediente, array_agg(en.nombre_visible) as etiquetas
                from nutricion.ingrediente_etiqueta ie
                join nutricion.etiqueta_nutricional en on en.id = ie.id_etiqueta
                group by ie.id_ingrediente
            )
            select 
                i.*, 
                g.nombre as categoria, 
                sg.nombre as subgrupo,
                coalesce(ea.etiquetas, '{{}}') as etiquetas,
                coalesce(c.energia_kcal, 0) as energia_kcal,
                coalesce(c.proteinas_g, 0) as proteinas_g,
                coalesce(c.grasa_total_g, 0) as grasa_total_g,
                coalesce(c.hidratos_carbono_g, 0) as hidratos_carbono_g
            from nutricion.ingrediente i
            left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
            left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
            left join etiquetas_agg ea on ea.id_ingrediente = i.id
            left join nutricion.ingrediente_composicion c on c.id_ingrediente = i.id
            where {where_sql}
            order by i.nombre limit %s offset %s
        """
        params.extend([limite, desplazamiento])
        with db_cursor() as cur:
            cur.execute(sql, params)
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def resolver_id_grupo(self, id_grupo: int | None, nombre: str | None) -> int | None:
        if id_grupo: return id_grupo
        if not nombre: return None
        with db_cursor() as cur:
            cur.execute("insert into nutricion.grupo_alimentario (nombre) values (%s) on conflict (nombre) do update set nombre = excluded.nombre returning id", (nombre.strip(),))
            return cur.fetchone()[0]

    def resolver_id_subgrupo(self, id_grupo: int | None, id_subgrupo: int | None, nombre: str | None) -> int | None:
        if id_subgrupo: return id_subgrupo
        if not id_grupo or not nombre: return None
        with db_cursor() as cur:
            cur.execute("insert into nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre) values (%s, %s) on conflict (id_grupo_alimentario, nombre) do update set nombre = excluded.nombre returning id", (id_grupo, nombre.strip()))
            return cur.fetchone()[0]

    def crear_ingrediente(self, datos: dict) -> int:
        # 1. Definir campos permitidos para cada tabla
        campos_ingrediente = {
            'nombre', 'id_grupo_alimentario', 'id_subgrupo_alimentario', 
            'factor_parte_comestible', 'activo', 'sinonimos', 'imagen_referencia'
        }
        
        composicion_campos = {
            'energia_kcal', 'agua_g', 'alcohol_g', 'proteinas_g', 'hidratos_carbono_g', 
            'almidon_g', 'azucares_sencillos_g', 'azucares_libres_g', 'fibra_vegetal_g', 
            'grasa_total_g', 'ags_g', 'agm_g', 'agp_g', 'colesterol_mg', 'vitamina_a_eq_retinol_ug', 
            'retinol_ug', 'carotenoides_eq_beta_caroteno_ug', 'vit_d_ug', 'vit_e_eq_alpha_tocoferol_mg', 
            'vit_k_ug', 'vitamina_b1_mg', 'vitamina_b2_mg', 'eq_niacina_mg', 'vit_b6_mg', 
            'eq_folato_dietetico_ug', 'vit_b12_ug', 'pantotenico_mg', 'biotina_ug', 'vit_c_mg', 
            'calcio_mg', 'fosforo_mg', 'hierro_mg', 'iodo_ug', 'cinc_mg', 'magnesio_mg', 
            'sodio_mg', 'potasio_mg', 'manganeso_mg', 'cobre_mg', 'selenio_ug', 'omega3_g', 
            'tipo_omega3', 'grasas_trans_g', 'polifenoles_mg', 'probioticos_billones_ufc'
        }

        # 2. Mapeo de nombres de campos (DTO -> DB)
        mapeo = {
            'parte_comestible_factor': 'factor_parte_comestible'
        }
        
        datos_procesados = {}
        for k, v in datos.items():
            key = mapeo.get(k, k)
            datos_procesados[key] = v

        datos_i = {k: v for k, v in datos_procesados.items() if k in campos_ingrediente}
        datos_c = {k: v for k, v in datos_procesados.items() if k in composicion_campos}

        # 4. Asegurar valores por defecto para composición (evitar NotNullViolation)
        for campo in composicion_campos:
            if campo not in datos_c or datos_c[campo] is None:
                # tipo_omega3 es texto, los demás son numéricos
                datos_c[campo] = "" if campo == 'tipo_omega3' else 0

        with db_cursor() as cur:
            # Insertar ingrediente
            if not datos_i.get('nombre'):
                raise ValueError("El nombre del ingrediente es obligatorio")
                
            cols_i = ", ".join(datos_i.keys())
            val_i = ", ".join(["%s"] * len(datos_i))
            cur.execute(f"insert into nutricion.ingrediente ({cols_i}) values ({val_i}) returning id", list(datos_i.values()))
            id_ingrediente = cur.fetchone()[0]

            # Insertar etiquetas
            etiquetas = datos.get('etiquetas', [])
            if etiquetas:
                etq_values = [(id_ingrediente, eid) for eid in etiquetas]
                cur.executemany("insert into nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta) values (%s, %s)", etq_values)

            # Insertar composicion
            if datos_c:
                datos_c['id_ingrediente'] = id_ingrediente
                cols_c = ", ".join(datos_c.keys())
                val_c = ", ".join(["%s"] * len(datos_c))
                cur.execute(f"insert into nutricion.ingrediente_composicion ({cols_c}) values ({val_c})", list(datos_c.values()))
            
            return id_ingrediente

    def actualizar_ingrediente(self, id_ingrediente: int, datos: dict) -> bool:
        campos_ingrediente = {
            'nombre', 'id_grupo_alimentario', 'id_subgrupo_alimentario', 
            'factor_parte_comestible', 'activo', 'sinonimos', 'imagen_referencia'
        }
        
        composicion_campos = {
            'energia_kcal', 'agua_g', 'alcohol_g', 'proteinas_g', 'hidratos_carbono_g', 
            'almidon_g', 'azucares_sencillos_g', 'azucares_libres_g', 'fibra_vegetal_g', 
            'grasa_total_g', 'ags_g', 'agm_g', 'agp_g', 'colesterol_mg', 'vitamina_a_eq_retinol_ug', 
            'retinol_ug', 'carotenoides_eq_beta_caroteno_ug', 'vit_d_ug', 'vit_e_eq_alpha_tocoferol_mg', 
            'vit_k_ug', 'vitamina_b1_mg', 'vitamina_b2_mg', 'eq_niacina_mg', 'vit_b6_mg', 
            'eq_folato_dietetico_ug', 'vit_b12_ug', 'pantotenico_mg', 'biotina_ug', 'vit_c_mg', 
            'calcio_mg', 'fosforo_mg', 'hierro_mg', 'iodo_ug', 'cinc_mg', 'magnesio_mg', 
            'sodio_mg', 'potasio_mg', 'manganeso_mg', 'cobre_mg', 'selenio_ug', 'omega3_g', 
            'tipo_omega3', 'grasas_trans_g', 'polifenoles_mg', 'probioticos_billones_ufc'
        }

        mapeo = {
            'parte_comestible_factor': 'factor_parte_comestible'
        }
        
        datos_procesados = {}
        for k, v in datos.items():
            key = mapeo.get(k, k)
            datos_procesados[key] = v

        datos_i = {k: v for k, v in datos_procesados.items() if k in campos_ingrediente}
        datos_c = {k: v for k, v in datos_procesados.items() if k in composicion_campos}

        # 3. Asegurar valores por defecto para composición en actualización (UPSERT)
        # Esto es necesario si enviamos campos parciales y la fila no existe o tiene NOT NULL
        for campo in composicion_campos:
            if campo not in datos_c or datos_c[campo] is None:
                datos_c[campo] = "" if campo == 'tipo_omega3' else 0

        with db_cursor() as cur:
            # 1. Actualizar ingrediente
            if datos_i:
                set_clause = ", ".join([f"{k} = %s" for k in datos_i.keys()])
                cur.execute(f"update nutricion.ingrediente set {set_clause} where id = %s", list(datos_i.values()) + [id_ingrediente])

            # 2. Sincronizar etiquetas
            if 'etiquetas' in datos:
                cur.execute("delete from nutricion.ingrediente_etiqueta where id_ingrediente = %s", (id_ingrediente,))
                etiquetas = datos.get('etiquetas', [])
                if etiquetas:
                    etq_values = [(id_ingrediente, eid) for eid in etiquetas]
                    cur.executemany("insert into nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta) values (%s, %s)", etq_values)

            # 3. Upsert composicion
            if datos_c:
                datos_c['id_ingrediente'] = id_ingrediente
                cols = ", ".join(datos_c.keys())
                val = ", ".join(["%s"] * len(datos_c))
                update_clause = ", ".join([f"{k} = excluded.{k}" for k in datos_c.keys() if k != 'id_ingrediente'])
                sql_upsert = f"""
                    insert into nutricion.ingrediente_composicion ({cols}) 
                    values ({val}) 
                    on conflict (id_ingrediente) do update set {update_clause}
                """
                cur.execute(sql_upsert, list(datos_c.values()))
            
            return True

    def eliminar_ingrediente(self, id_ingrediente: int) -> bool:
        with db_cursor() as cur:
            # Primero eliminamos dependencias si es necesario (etiquetas, composicion)
            # En la DB podria haber ON DELETE CASCADE, pero lo hacemos explicito por seguridad si no estamos seguros
            cur.execute("delete from nutricion.ingrediente_etiqueta where id_ingrediente = %s", (id_ingrediente,))
            cur.execute("delete from nutricion.ingrediente_composicion where id_ingrediente = %s", (id_ingrediente,))
            cur.execute("delete from nutricion.ingrediente where id = %s", (id_ingrediente,))
            return cur.rowcount > 0

    def obtener_ingrediente(self, id_ingrediente: int) -> dict | None:
        sql = """
            with etiquetas_agg as (
                select 
                    ie.id_ingrediente, 
                    json_agg(json_build_object(
                        'id', en.id, 
                        'nombre_visible', en.nombre_visible
                    )) as etiquetas
                from nutricion.ingrediente_etiqueta ie
                join nutricion.etiqueta_nutricional en on en.id = ie.id_etiqueta
                where ie.id_ingrediente = %s
                group by ie.id_ingrediente
            )
            select 
                i.*, 
                g.nombre as grupo_nombre, 
                sg.nombre as subgrupo_nombre,
                c.*,
                coalesce(ea.etiquetas, '[]'::json) as etiquetas
            from nutricion.ingrediente i
            left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
            left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
            left join nutricion.ingrediente_composicion c on c.id_ingrediente = i.id
            left join etiquetas_agg ea on ea.id_ingrediente = i.id
            where i.id = %s
        """
        with db_cursor() as cur:
            cur.execute(sql, (id_ingrediente, id_ingrediente))
            row = cur.fetchone()
            if not row: return None
            columnas = [desc[0] for desc in cur.description]
            return dict(zip(columnas, row))

    def obtener_mapa_etiquetas_ingrediente(self) -> Dict[int, Set[int]]:
        with db_cursor() as cur:
            cur.execute("select id_ingrediente, id_etiqueta from nutricion.ingrediente_etiqueta")
            mapa: Dict[int, Set[int]] = {}
            for row in cur.fetchall():
                id_ing, id_eti = row
                if id_ing not in mapa: mapa[id_ing] = set()
                mapa[id_ing].add(id_eti)
            return mapa

    def obtener_mapa_etiquetas_receta(self) -> Dict[int, Set[int]]:
        with db_cursor() as cur:
            cur.execute("select id_receta, id_etiqueta from nutricion.receta_etiqueta")
            mapa: Dict[int, Set[int]] = {}
            for row in cur.fetchall():
                id_rec, id_eti = row
                if id_rec not in mapa: mapa[id_rec] = set()
                mapa[id_rec].add(id_eti)
            return mapa

    def obtener_mapa_ingredientes_receta(self) -> Dict[int, Set[int]]:
        with db_cursor() as cur:
            cur.execute("select id_receta, id_ingrediente from nutricion.receta_ingrediente")
            mapa: Dict[int, Set[int]] = {}
            for row in cur.fetchall():
                id_rec, id_ing = row
                if id_rec not in mapa: mapa[id_rec] = set()
                mapa[id_rec].add(id_ing)
            return mapa

    def obtener_preferencias_receta(self, id_paciente: str) -> Dict[int, bool]:
        """
        Retorna un mapa de {id_receta: le_gusta} para un paciente.
        Se basa en puntaje_ajuste: > 0 es que le gusta, < 0 es que no le gusta.
        """
        with db_cursor() as cur:
            cur.execute("""
                select id_receta, puntaje_ajuste 
                from interaccion.preferencia_receta 
                where id_paciente = %s
            """, (id_paciente,))
            return {row[0]: (float(row[1]) > 0) for row in cur.fetchall()}

    def buscar_ingredientes_filtrados(self, id_paciente: str | None, consulta: str = None, limite: int = 50) -> List[dict]:
        """
        Busca ingredientes aplicando filtros de alergias del paciente.
        Si id_paciente es None, devuelve todos los ingredientes activos.
        """
        with db_cursor() as cur:
            ing_prohibidos = set()
            sub_prohibidos = set()
            ing_recomendados = set()

            if id_paciente and id_paciente != "null" and id_paciente != "none":
                # 1. Obtener IDs de ingredientes y subgrupos prohibidos
                cur.execute(
                    "select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s and activa = true",
                    (id_paciente,)
                )
                ing_prohibidos = {r[0] for r in cur.fetchall()}

                cur.execute(
                    "select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s and activa = true",
                    (id_paciente,)
                )
                sub_prohibidos = {r[0] for r in cur.fetchall()}
                sub_restricciones, ing_restricciones = self._expandir_restricciones_paciente(cur, id_paciente)
                sub_prohibidos |= sub_restricciones
                ing_prohibidos |= ing_restricciones

                # 2. Obtener recomendaciones actuales
                cur.execute(
                    "select id_ingrediente from clinico.recomendacion_ingrediente where id_paciente = %s and activa = true",
                    (id_paciente,)
                )
                ing_recomendados = {r[0] for r in cur.fetchall()}

            # 4. Consulta principal con exclusion por subgrupo e ingrediente y busqueda por sinonimos
            where_clause = "i.activo = true"
            params = []
            
            if consulta:
                stop_words = {'de', 'con', 'en', 'el', 'la', 'los', 'las', 'un', 'una', 'para', 'sin', 'y', 'del'}
                words = [w.lower().strip() for w in consulta.split(' ') if w.lower().strip() not in stop_words and len(w.strip()) > 2]
                if not words and consulta.strip(): words = [consulta.lower().strip()]
                
                if words:
                    word_conditions = []
                    for w in words:
                        word_conditions.append("(i.nombre ~* %s or exists (select 1 from unnest(i.sinonimos) s where s ~* %s))")
                        pattern = f"\\y{w}\\y"
                        params.extend([pattern, pattern])
                    where_clause += " and (" + " and ".join(word_conditions) + ")"
            
            if ing_prohibidos:
                where_clause += " and i.id != all(%s)"
                params.append(list(ing_prohibidos))
            
            if sub_prohibidos:
                where_clause += " and (i.id_subgrupo_alimentario is null or i.id_subgrupo_alimentario != all(%s))"
                params.append(list(sub_prohibidos))

            # Respetar el límite solicitado. Para validaciones internas (recomendador)
            # se invocan límites altos y no debe recortarse a 200.
            final_limit = limite if limite and limite > 0 else 200

            sql = f"""
                select i.id, i.nombre, sg.nombre as subgrupo, i.id_subgrupo_alimentario
                from nutricion.ingrediente i
                left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
                where {where_clause}
                order by i.nombre limit %s
            """
            params.append(final_limit)

            cur.execute(sql, params)
            columnas = [desc[0] for desc in cur.description]
            resultados = []
            for row in cur.fetchall():
                d = dict(zip(columnas, row))
                d["es_recomendado"] = d["id"] in ing_recomendados
                resultados.append(d)
            return resultados

    def registrar_recomendacion(self, id_paciente: str, id_ingrediente: int, id_profesional: str, id_rol: int, motivo: str = None, prioridad: int = 1) -> bool:
        with db_cursor() as cur:
            # 1. Resolver el id interno del profesional si viene el auth_id
            id_profesional_interno = id_profesional
            cur.execute("select id from usuarios.usuario where auth_user_id::text = %s or id::text = %s limit 1", (id_profesional, id_profesional))
            row = cur.fetchone()
            if row: id_profesional_interno = row[0]

            sql = """
                insert into clinico.recomendacion_ingrediente 
                (id_paciente, id_ingrediente, id_profesional, id_rol_recomienda, motivo, prioridad, activa)
                values (%s, %s, %s, %s, %s, %s, true)
                on conflict (id_paciente, id_ingrediente, id_profesional) 
                do update set activa = true, motivo = excluded.motivo, prioridad = excluded.prioridad
            """
            cur.execute(sql, (id_paciente, id_ingrediente, id_profesional_interno, id_rol, motivo, prioridad))
            return True

    def eliminar_recomendacion(self, id_paciente: str, id_ingrediente: int) -> bool:
        with db_cursor() as cur:
            cur.execute("update clinico.recomendacion_ingrediente set activa = false where id_paciente = %s and id_ingrediente = %s", (id_paciente, id_ingrediente))
            return cur.rowcount > 0

    def listar_recomendaciones_paciente(self, id_paciente: str) -> List[dict]:
        sql = """
            select ri.*, i.nombre as ingrediente_nombre, u.nombre_completo as profesional_nombre
            from clinico.recomendacion_ingrediente ri
            join nutricion.ingrediente i on i.id = ri.id_ingrediente
            left join usuarios.usuario u on u.id = ri.id_profesional
            where ri.id_paciente = %s and ri.activa = true
        """
        with db_cursor() as cur:
            cur.execute(sql, (id_paciente,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]
