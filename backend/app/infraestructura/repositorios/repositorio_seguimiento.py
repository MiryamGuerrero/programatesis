from typing import List, Optional
from datetime import date
from app.infraestructura.database.db import db_cursor
from ...domain.modelos.seguimiento import RegistroConsumo
from ...domain.repositorios.interfaces import IRepositorioSeguimiento

class RepositorioSeguimientoPostgres(IRepositorioSeguimiento):
    def registrar_consumo(self, registro: RegistroConsumo) -> bool:
        with db_cursor() as cur:
            sql = """
                insert into interaccion.seguimiento_plan_item (
                    id_plan_item, id_estado_consumo, id_receta_reemplazo, 
                    fecha_consumo, observacion
                ) values (%s, %s, %s, %s, %s)
                on conflict (id_plan_item) do update set
                    id_estado_consumo = excluded.id_estado_consumo,
                    id_receta_reemplazo = excluded.id_receta_reemplazo,
                    fecha_consumo = excluded.fecha_consumo,
                    observacion = excluded.observacion
            """
            cur.execute(sql, (
                registro.id_plan_item, registro.id_estado_consumo,
                registro.id_receta_reemplazo, registro.fecha_consumo,
                registro.observacion
            ))
            return True

    def obtener_plan_del_dia(self, id_paciente: str, fecha: date) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select 
                    pi.id as id_plan_item,
                    pi.consumida,
                    m.id as id_momento,
                    m.nombre as momento_nombre,
                    m.hora_inicio as momento_hora_inicio,
                    m.hora_fin as momento_hora_fin,
                    coalesce(r.nombre, 'Receta no encontrada') as receta_nombre,
                    r.id as id_receta,
                    (select imagen_url from nutricion.receta_imagen where id_receta = r.id limit 1) as receta_url_imagen,
                    r.descripcion as receta_descripcion,
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
                    p.id_origen_plan,
                    (SELECT array_agg(id_tipo_plato) FROM nutricion.receta_tipo_plato WHERE id_receta = r.id) as tipos_plato_ids,
                    s.id_estado_consumo,
                    s.fecha_consumo
                from interaccion.plan_nutricional p
                join interaccion.plan_item pi on pi.id_plan = p.id
                join nutricion.momento_comida m on m.id = pi.id_momento
                left join nutricion.receta r on r.id = pi.id_receta
                left join interaccion.seguimiento_plan_item s on s.id_plan_item = pi.id
                where p.id_paciente = %s 
                  and pi.fecha_programada = %s
                  and %s >= p.fecha_inicio 
                  and %s <= p.fecha_fin
                order by m.orden, pi.id
            """
            cur.execute(sql, (id_paciente, fecha, fecha, fecha))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def crear_plan_nutricional(self, datos: dict) -> int:
        with db_cursor() as cur:
            sql = """
                insert into interaccion.plan_nutricional (
                    id_paciente, id_tipo_plan, id_origen_plan, id_estado_plan,
                    comidas_por_dia, fecha_inicio, fecha_fin, vigente, creado_por
                ) values (%s, %s, %s, %s, %s, %s, %s, true, %s)
                returning id
            """
            cur.execute(sql, (
                datos["id_paciente"], datos.get("id_tipo_plan", 1),
                datos.get("id_origen_plan", 2), datos.get("id_estado_plan", 1),
                datos.get("comidas_por_dia", 3), datos["fecha_inicio"],
                datos["fecha_fin"], datos.get("creado_por")
            ))
            return cur.fetchone()[0]

    def agregar_items_plan(self, items: List[dict]) -> bool:
        with db_cursor() as cur:
            sql = """
                insert into interaccion.plan_item (
                    id_plan, fecha_programada, id_momento, id_receta, consumida
                ) values (%s, %s, %s, %s, false)
            """
            params = [(i["id_plan"], i["fecha_programada"], i["id_momento"], i["id_receta"]) for i in items]
            cur.executemany(sql, params)
            return True

    def intercambiar_receta_item(self, id_plan_item: int, id_nueva_receta: int) -> bool:
        with db_cursor() as cur:
            sql = "update interaccion.plan_item set id_receta = %s where id = %s"
            cur.execute(sql, (id_nueva_receta, id_plan_item))
            return cur.rowcount > 0

    def obtener_item_plan_con_detalle(self, id_plan_item: int) -> Optional[dict]:
        with db_cursor() as cur:
            sql = """
                select pi.id, pi.id_plan, pi.id_momento, pi.id_receta, pi.fecha_programada,
                       p.id_paciente, p.id_origen_plan
                from interaccion.plan_item pi
                join interaccion.plan_nutricional p on p.id = pi.id_plan
                where pi.id = %s
            """
            cur.execute(sql, (id_plan_item,))
            row = cur.fetchone()
            if not row: return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, row))

    def marcar_item_consumido(self, id_plan_item: int, consumida: bool) -> bool:
        with db_cursor() as cur:
            sql = "update interaccion.plan_item set consumida = %s where id = %s"
            cur.execute(sql, (consumida, id_plan_item))
            return cur.rowcount > 0

    def obtener_dias_con_plan(self, id_paciente: str, mes: int, anio: int) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select distinct pi.fecha_programada, p.id as id_plan
                from interaccion.plan_nutricional p
                join interaccion.plan_item pi on pi.id_plan = p.id
                where p.id_paciente = %s 
                  and extract(month from pi.fecha_programada) = %s
                  and extract(year from pi.fecha_programada) = %s
                order by pi.fecha_programada
            """
            cur.execute(sql, (id_paciente, mes, anio))
            return [{"fecha": row[0], "id_plan": row[1]} for row in cur.fetchall()]

    def obtener_adherencia(self, id_paciente: str, dias_atras: int) -> dict:
        with db_cursor() as cur:
            sql = """
                select 
                    count(pi.id) as total,
                    count(pi.id) filter (where pi.consumida = true) as consumidos
                from interaccion.plan_nutricional p
                join interaccion.plan_item pi on pi.id_plan = p.id
                where p.id_paciente = %s 
                  and pi.fecha_programada >= current_date - %s
                  and pi.fecha_programada <= current_date
            """
            cur.execute(sql, (id_paciente, dias_atras))
            row = cur.fetchone()
            total = row[0] or 0
            consumidos = row[1] or 0
            porcentaje = (consumidos / total * 100) if total > 0 else 0
            
            return {
                "total_planificado": total,
                "total_consumido": consumidos,
                "porcentaje_cumplimiento": round(porcentaje, 2),
                "racha_dias": 0 
            }

    def obtener_lista_compras(self, id_paciente: str, fecha_inicio: date, fecha_fin: date) -> dict:
        with db_cursor() as cur:
            sql = """
                with ingredientes_plan as (
                    select 
                        i.id as id_ingrediente,
                        i.nombre as titulo,
                        coalesce(g.nombre, 'Otros') as categoria,
                        ri.peso_en_gramos as gramos
                    from interaccion.plan_nutricional p
                    join interaccion.plan_item pi on pi.id_plan = p.id
                    join nutricion.receta_ingrediente ri on ri.id_receta = pi.id_receta
                    join nutricion.ingrediente i on i.id = ri.id_ingrediente
                    left join nutricion.grupo_alimentario g on g.id = i.id_grupo_alimentario
                    where p.id_paciente = %s 
                      and pi.fecha_programada >= %s 
                      and pi.fecha_programada <= %s
                      and coalesce(pi.consumida, false) = false
                ),
                agrupados as (
                    select 
                        categoria,
                        titulo,
                        sum(gramos) as total_gramos
                    from ingredientes_plan
                    group by categoria, titulo
                )
                select 
                    categoria,
                    titulo,
                    total_gramos,
                    case 
                        when total_gramos >= 1000 then round((total_gramos / 1000)::numeric, 2)
                        else round(total_gramos::numeric, 0)
                    end as cantidad_numerica,
                    case 
                        when total_gramos >= 1000 then 'kg'
                        else 'g'
                    end as unidad_texto
                from agrupados
                order by categoria, titulo
            """
            cur.execute(sql, (id_paciente, fecha_inicio, fecha_fin))
            rows = cur.fetchall()
            
            resultado = {}
            for row in rows:
                categoria = row[0]
                ingrediente = {
                    "nombre": row[1],
                    "total_gramos": float(row[2]) if row[2] is not None else 0,
                    "cantidad": float(row[3]) if row[3] is not None else 0,
                    "unidad": row[4]
                }
                
                if categoria not in resultado:
                    resultado[categoria] = []
                resultado[categoria].append(ingrediente)
                
            return resultado

    def obtener_reporte_adherencia_medico(self, id_medico: str) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                with pacientes_medico as (
                    select distinct id_paciente from clinico.control_paciente where id_medico = %s
                ),
                adherencia_global as (
                    select 
                        p.id as id_paciente,
                        p.nombre_completo,
                        count(pi.id) as total_plan,
                        count(pi.id) filter (where pi.consumida = true) as consumidos
                    from usuarios.paciente p
                    join pacientes_medico pm on pm.id_paciente = p.id
                    left join interaccion.plan_item pi on pi.id_plan in (
                        select id from interaccion.plan_nutricional where id_paciente = p.id
                    )
                    where p.activo = true
                    group by p.id, p.nombre_completo
                )
                select 
                    id_paciente, 
                    nombre_completo,
                    total_plan,
                    consumidos,
                    round(case when total_plan > 0 then (consumidos::numeric / total_plan * 100) else 0 end, 2) as porcentaje
                from adherencia_global
                order by porcentaje asc
            """
            cur.execute(sql, (id_medico,))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]
