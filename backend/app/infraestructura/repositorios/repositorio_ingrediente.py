from typing import List, Dict, Set
from ...core.db import db_cursor
from ...domain.repositorios.interfaces import IRepositorioIngrediente

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
    def listar_todos_activos(self) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("select id, nombre, id_subgrupo_alimentario from nutricion.ingrediente where activo = true")
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def listar_ingredientes_admin(self, consulta: str = None, limite: int = 100, desplazamiento: int = 0, incluir_inactivos: bool = False, id_grupo: int = None, id_subgrupo: int = None) -> List[dict]:
        term = f"%{consulta}%" if consulta else "%"
        
        where_clauses = ["(%s or i.activo = true)", "(i.nombre ilike %s)"]
        params = [incluir_inactivos, term]
        
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

            # 2. Upsert composicion
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

    def obtener_mapa_ingredientes_receta(self) -> Dict[int, Set[int]]:
        with db_cursor() as cur:
            cur.execute("select id_receta, id_ingrediente from nutricion.receta_ingrediente")
            mapa: Dict[int, Set[int]] = {}
            for row in cur.fetchall():
                id_rec, id_ing = row
                if id_rec not in mapa: mapa[id_rec] = set()
                mapa[id_rec].add(id_ing)
            return mapa

    def buscar_ingredientes_filtrados(self, id_paciente: str | None, consulta: str = None, limite: int = 50) -> List[dict]:
        """
        Busca ingredientes aplicando filtros de alergias del paciente.
        Si id_paciente es None, devuelve todos los ingredientes activos.
        """
        with db_cursor() as cur:
            ing_prohibidos = set()
            sub_prohibidos = set()

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

                # 2. Detectar intolerancia a la lactosa:
                # Si el paciente tiene prohibido CUALQUIER subgrupo con lactosa,
                # consideramos que es intolerante y bloqueamos TODOS los subgrupos con lactosa
                if sub_prohibidos & SUBGRUPOS_CON_LACTOSA:
                    sub_prohibidos |= SUBGRUPOS_CON_LACTOSA

            # 3. Consulta principal con exclusion por subgrupo e ingrediente y busqueda por sinonimos
            term = f"%{consulta}%" if consulta else "%"
            
            # Ajuste de limite: si no hay consulta, devolver mas para cargar catálogo
            final_limit = limite if consulta else 200

            sql = """
                select i.id, i.nombre, sg.nombre as subgrupo, i.id_subgrupo_alimentario
                from nutricion.ingrediente i
                left join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
                where i.activo = true
                  and (
                    i.nombre ilike %s 
                    or exists (
                        select 1 from unnest(i.sinonimos) s where s ilike %s
                    )
                  )
            """
            
            params = [term, term]
            
            if ing_prohibidos:
                sql += " and i.id != all(%s)"
                params.append(list(ing_prohibidos))
            
            if sub_prohibidos:
                sql += " and (i.id_subgrupo_alimentario is null or i.id_subgrupo_alimentario != all(%s))"
                params.append(list(sub_prohibidos))
                
            sql += " order by i.nombre limit %s"
            params.append(final_limit)

            cur.execute(sql, params)
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]
