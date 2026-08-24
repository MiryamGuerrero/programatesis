from typing import List
from app.infraestructura.database.db import db_cursor
from ...domain.modelos.reglas import Regla, FuenteRegla, TipoAccion, TipoObjetivo
from ...domain.repositorios.interfaces import IRepositorioRegla

class RepositorioReglaPostgres(IRepositorioRegla):
    def obtener_reglas_por_condiciones(self, ids_condiciones: List[int]) -> List[Regla]:
        if not ids_condiciones:
            return []
        with db_cursor() as cur:
            ids_objetivo = self._expandir_condiciones_con_general_reumaticos(cur, ids_condiciones)
            sql = """
                select r.id, cr.id_condicion, r.origen_regla, a.nombre as accion_nombre, t.nombre as objetivo_nombre, 
                       r.id_ingrediente, r.id_grupo_alimentario, r.id_subgrupo_alimentario, r.id_etiqueta, r.id_receta,
                       r.mensaje_error
                from heuristico.regla r
                join heuristico.condicion_regla cr on cr.id_regla = r.id
                join heuristico.catalogo_accion a on a.id = r.id_accion
                join heuristico.catalogo_objetivo_regla t on t.id = r.id_tipo_objetivo
                where cr.id_condicion = any(%s)
            """
            cur.execute(sql, (ids_objetivo,))
            return [self._mapear_fila_a_regla(r) for r in cur.fetchall()]

    def _expandir_condiciones_con_general_reumaticos(self, cur, ids_condiciones: List[int]) -> List[int]:
        ids_base = set(ids_condiciones or [])
        if not ids_base:
            return []

        # Resolver IDs por indicador_codigo y nombre para robustez entre ambientes.
        cur.execute(
            """
            select id, indicador_codigo, lower(nombre) as nombre
            from heuristico.condicion
            where activa = true
            """
        )
        filas = cur.fetchall()
        if not filas:
            return list(ids_base)

        general_id = None
        ids_reuma = set()
        for cid, indicador, nombre in filas:
            indicador_up = (indicador or "").upper()
            nombre_low = (nombre or "").strip()
            if indicador_up == "GENERAL_REUMATICOS" or nombre_low == "general reumaticos":
                general_id = cid
            if (
                "LUPUS" in indicador_up
                or "ARTRITIS_IDIOPATICA_JUVENIL" in indicador_up
                or "lupus" in nombre_low
                or "artritis idiopatica juvenil" in nombre_low
                or "aij" == nombre_low
                or "aij " in f"{nombre_low} "
            ):
                ids_reuma.add(cid)

        if general_id and (ids_base & ids_reuma):
            ids_base.add(general_id)
        return list(ids_base)

    def obtener_alergias_por_paciente(self, id_paciente: str) -> List[Regla]:
        with db_cursor() as cur:
            reglas = []
            # 1. Alergias por ingrediente
            cur.execute("select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s and activa = true", (id_paciente,))
            for r in cur.fetchall():
                reglas.append(Regla(fuente=FuenteRegla.ALERGIA, accion=TipoAccion.ELIMINAR, tipo_objetivo=TipoObjetivo.INGREDIENTE, id_objetivo=r[0], prioridad=1000))
            
            # 2. Alergias por subgrupo
            cur.execute("select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s and activa = true", (id_paciente,))
            for r in cur.fetchall():
                reglas.append(Regla(fuente=FuenteRegla.ALERGIA, accion=TipoAccion.ELIMINAR, tipo_objetivo=TipoObjetivo.SUBGRUPO, id_objetivo=r[0], prioridad=1000))
            
            return reglas

    def listar_reglas_detalladas(
        self, tipos_condicion: List[int] = [1, 2, 3], limite: int = 10, offset: int = 0,
        include_total: bool = False, origen_regla: str = None,
        q: str = None, id_condicion: int = None, id_accion: int = None,
        id_tipo_objetivo: int = None, id_objetivo: int = None,
        indicador: str = None
    ) -> dict | List[dict]:
        with db_cursor() as cur:
            # 1. Base WHERE clause: construcción dinámica de filtros
            where_parts = ["c.id_tipo_condicion = ANY(%s)"]
            params = [tipos_condicion]

            if indicador:
                where_parts.append("c.indicador_codigo = %s")
                params.append(indicador)

            if origen_regla:
                where_parts.append("upper(coalesce(r.origen_regla, 'CLINICA')) = %s")
                params.append(origen_regla.upper())

            if id_condicion is not None:
                where_parts.append("cr.id_condicion = %s")
                params.append(id_condicion)

            if id_accion is not None:
                where_parts.append("r.id_accion = %s")
                params.append(id_accion)

            if id_tipo_objetivo is not None:
                where_parts.append("r.id_tipo_objetivo = %s")
                params.append(id_tipo_objetivo)
                if id_objetivo is not None:
                    if id_tipo_objetivo == 1:
                        where_parts.append("r.id_ingrediente = %s")
                    elif id_tipo_objetivo == 2:
                        where_parts.append("r.id_grupo_alimentario = %s")
                    elif id_tipo_objetivo == 3:
                        where_parts.append("r.id_etiqueta = %s")
                    elif id_tipo_objetivo == 4:
                        where_parts.append("r.id_subgrupo_alimentario = %s")
                    params.append(id_objetivo)

            if q:
                like = f"%{q.lower()}%"
                where_parts.append(
                    "(lower(i.nombre) like %s or lower(g.nombre) like %s or "
                    "lower(s.nombre) like %s or lower(e.nombre_visible) like %s or "
                    "lower(r.mensaje_error) like %s)"
                )
                params.extend([like, like, like, like, like])

            where_sql = "where " + " and ".join(where_parts)

            # 2. Total count if requested
            total = 0
            if include_total:
                cur.execute(f"""
                    select count(distinct r.id)
                    from heuristico.regla r
                    join heuristico.condicion_regla cr on cr.id_regla = r.id
                    join heuristico.condicion c on c.id = cr.id_condicion
                    join heuristico.catalogo_accion a on a.id = r.id_accion
                    join heuristico.catalogo_objetivo_regla t on t.id = r.id_tipo_objetivo
                    left join nutricion.ingrediente i on i.id = r.id_ingrediente
                    left join nutricion.grupo_alimentario g on g.id = r.id_grupo_alimentario
                    left join nutricion.subgrupo_alimentario s on s.id = r.id_subgrupo_alimentario
                    left join nutricion.etiqueta_nutricional e on e.id = r.id_etiqueta
                    {where_sql}
                """, tuple(params))
                total = cur.fetchone()[0]

            # 3. Main query
            sql = f"""
                select 
                    r.id, r.id_accion, r.id_tipo_objetivo,
                    r.id_ingrediente, r.id_grupo_alimentario, r.id_subgrupo_alimentario, r.id_etiqueta,
                    r.mensaje_error, r.es_estricta, r.origen_regla,
                    a.nombre as accion_nombre, a.nombre as accion_codigo,
                    t.nombre as objetivo_nombre, 
                    CASE 
                        WHEN t.id = 1 THEN 'INGREDIENTE'
                        WHEN t.id = 2 THEN 'GRUPO'
                        WHEN t.id = 3 THEN 'ETIQUETA'
                        WHEN t.id = 4 THEN 'SUBGRUPO'
                        ELSE UPPER(t.nombre)
                    END as objetivo_codigo,
                    i.nombre as ingrediente_nombre, g.nombre as grupo_nombre, 
                    s.nombre as subgrupo_nombre, e.nombre_visible as etiqueta_nombre,
                    array_agg(DISTINCT cr.id_condicion) as id_condiciones,
                    array_agg(DISTINCT tc.nombre) as tipos_condicion,
                    string_agg(DISTINCT c.nombre, ', ') as condiciones_nombres
                from heuristico.regla r
                join heuristico.catalogo_accion a on a.id = r.id_accion
                join heuristico.catalogo_objetivo_regla t on t.id = r.id_tipo_objetivo
                join heuristico.condicion_regla cr on cr.id_regla = r.id
                join heuristico.condicion c on c.id = cr.id_condicion
                join heuristico.catalogo_tipo_condicion tc on tc.id = c.id_tipo_condicion
                left join nutricion.ingrediente i on i.id = r.id_ingrediente
                left join nutricion.grupo_alimentario g on g.id = r.id_grupo_alimentario
                left join nutricion.subgrupo_alimentario s on s.id = r.id_subgrupo_alimentario
                left join nutricion.etiqueta_nutricional e on e.id = r.id_etiqueta
                {where_sql}
                group by r.id, a.nombre, t.nombre, t.id, i.nombre, g.nombre, s.nombre, e.nombre_visible, r.origen_regla
                order by r.id desc
                limit %s offset %s
            """
            try:
                cur.execute(sql, tuple(params) + (limite, offset))
                columnas = [desc[0] for desc in cur.description]
                rows = cur.fetchall()
                items = [dict(zip(columnas, row)) for row in rows]
                
                if include_total:
                    return {"items": items, "total": total}
                return items
            except Exception as e:
                print(f"Error en listar_reglas_detalladas: {e}")
                return {"items": [], "total": 0} if include_total else []

    def guardar_regla(self, data: dict) -> int:
        with db_cursor() as cur:
            # 1. Validaciones básicas para evitar 400 por campos faltantes
            id_accion = data.get("id_accion")
            id_tipo_obj = data.get("id_tipo_objetivo")
            
            if not id_accion or not id_tipo_obj:
                raise ValueError("id_accion e id_tipo_objetivo son requeridos para crear una regla")

            # 2. Determinar origen de forma inteligente si no viene explícito
            origen = data.get("origen_regla")
            id_condiciones = data.get("id_condiciones", [])
            
            if not origen and id_condiciones:
                # Consultar el tipo de la primera condición para inferir el origen
                cur.execute("select id_tipo_condicion from heuristico.condicion where id = %s", (id_condiciones[0],))
                row_t = cur.fetchone()
                if row_t:
                    tipo_map = {1: "CLINICA", 2: "TEMPORAL", 3: "NUTRICIONAL"}
                    origen = tipo_map.get(row_t[0], "CLINICA")
            
            if not origen:
                origen = "CLINICA"
            
            # 3. Insertar la regla base
            sql_regla = """
                insert into heuristico.regla (
                    id_accion, id_tipo_objetivo, mensaje_error, es_estricta,
                    id_ingrediente, id_grupo_alimentario, id_subgrupo_alimentario, id_etiqueta,
                    origen_regla
                ) values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                returning id
            """
            cur.execute(sql_regla, (
                id_accion, id_tipo_obj, data.get("mensaje_error"), data.get("es_estricta", False),
                data.get("id_ingrediente"), data.get("id_grupo_alimentario"), data.get("id_subgrupo_alimentario"), data.get("id_etiqueta"),
                origen
            ))
            id_regla = cur.fetchone()[0]

            # 4. Vincular con todas las condiciones enviadas
            for id_cond in id_condiciones:
                cur.execute("insert into heuristico.condicion_regla (id_regla, id_condicion) values (%s, %s)", (id_regla, id_cond))
            
            return id_regla

    def eliminar_regla(self, id_regla: int) -> bool:
        with db_cursor() as cur:
            # Limpiar tabla puente primero
            cur.execute("delete from heuristico.condicion_regla where id_regla = %s", (id_regla,))
            cur.execute("delete from heuristico.regla where id = %s", (id_regla,))
            return cur.rowcount > 0

    def actualizar_regla(self, id_regla: int, data: dict) -> bool:
        with db_cursor() as cur:
            # 1. Actualizar datos base
            sql = """
                update heuristico.regla set
                    id_accion = %s, id_tipo_objetivo = %s, mensaje_error = %s, es_estricta = %s,
                    id_ingrediente = %s, id_grupo_alimentario = %s, id_subgrupo_alimentario = %s, id_etiqueta = %s,
                    origen_regla = COALESCE(%s, origen_regla)
                where id = %s
            """
            cur.execute(sql, (
                data["id_accion"], data["id_tipo_objetivo"], data.get("mensaje_error"), data.get("es_estricta", False),
                data.get("id_ingrediente"), data.get("id_grupo_alimentario"), data.get("id_subgrupo_alimentario"), data.get("id_etiqueta"),
                data.get("origen_regla"),
                id_regla
            ))

            # 2. Refrescar condiciones vinculadas
            if "id_condiciones" in data:
                cur.execute("delete from heuristico.condicion_regla where id_regla = %s", (id_regla,))
                for id_cond in data["id_condiciones"]:
                    cur.execute("insert into heuristico.condicion_regla (id_regla, id_condicion) values (%s, %s)", (id_regla, id_cond))
            
            return True

    def obtener_estadisticas_medicas(self) -> dict:
        with db_cursor() as cur:
            sql = """
                select
                    count(distinct r.id) as total,
                    count(distinct case when r.es_estricta = true then r.id end) as estrictas,
                    count(distinct case when upper(coalesce(r.origen_regla, 'CLINICA')) = 'CLINICA' then r.id end) as clinicas,
                    count(distinct case when upper(r.origen_regla) = 'TEMPORAL' then r.id end) as temporales
                from heuristico.regla r
                join heuristico.condicion_regla cr on cr.id_regla = r.id
                join heuristico.condicion c on c.id = cr.id_condicion
                where c.id_tipo_condicion in (1, 2)
            """
            cur.execute(sql)
            res = cur.fetchone()
            return {
                "total": res[0] or 0,
                "estrictas": res[1] or 0,
                "clinicas": res[2] or 0,
                "temporales": res[3] or 0
            }

    def obtener_estadisticas_nutricionales(self) -> dict:
        with db_cursor() as cur:
            sql = """
                select
                    count(distinct r.id) as total,
                    count(distinct case when r.es_estricta = true then r.id end) as estrictas,
                    count(distinct case when upper(coalesce(c.indicador_codigo, '')) = 'BMI' then r.id end) as peso,
                    count(distinct case when upper(coalesce(c.indicador_codigo, '')) = 'HFA' then r.id end) as estatura
                from heuristico.regla r
                join heuristico.condicion_regla cr on cr.id_regla = r.id
                join heuristico.condicion c on c.id = cr.id_condicion
                where c.id_tipo_condicion = 3
            """
            cur.execute(sql)
            res = cur.fetchone()
            return {
                "total": res[0] or 0,
                "estrictas": res[1] or 0,
                "peso": res[2] or 0,
                "estatura": res[3] or 0
            }

    def _mapear_fila_a_regla(self, fila: tuple) -> Regla:
        # Fila: id, id_condicion, origen, accion_nombre, objetivo_nombre, id_ing, id_grp, id_sub, id_etq, id_rec, msg
        id_objetivo = fila[5] or fila[6] or fila[7] or fila[8] or fila[9]
        
        # Mapeo de nombres a Enums de Python
        accion_map = {
            "ELIMINAR": TipoAccion.ELIMINAR,
            "PRIORIZAR": TipoAccion.PRIORIZAR,
            "DISMINUIR": TipoAccion.DISMINUIR
        }
        
        objetivo_map = {
            "INGREDIENTE": TipoObjetivo.INGREDIENTE,
            "SUBGRUPO ALIMENTARIO": TipoObjetivo.SUBGRUPO,
            "SUBGRUPO": TipoObjetivo.SUBGRUPO,
            "GRUPO ALIMENTARIO": TipoObjetivo.GRUPO,
            "GRUPO": TipoObjetivo.GRUPO,
            "ETIQUETA NUTRICIONAL": TipoObjetivo.ETIQUETA,
            "ETIQUETA": TipoObjetivo.ETIQUETA,
            "RECETA": TipoObjetivo.RECETA
        }
        
        accion_nombre = fila[3].upper() if fila[3] else "ELIMINAR"
        objetivo_nombre = fila[4].upper() if fila[4] else "INGREDIENTE"

        return Regla(
            id_regla=fila[0],
            fuente=fila[2],
            accion=accion_map.get(accion_nombre, TipoAccion.ELIMINAR),
            tipo_objetivo=objetivo_map.get(objetivo_nombre, TipoObjetivo.INGREDIENTE),
            id_objetivo=id_objetivo,
            mensaje=fila[10]
        )

