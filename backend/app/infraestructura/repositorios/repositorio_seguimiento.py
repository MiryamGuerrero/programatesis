from typing import List
from datetime import date
from ...core.db import db_cursor
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
                    m.nombre as momento_nombre,
                    r.nombre as receta_nombre,
                    r.id as id_receta,
                    s.id_estado_consumo,
                    s.fecha_consumo
                from interaccion.plan_nutricional p
                join interaccion.plan_item pi on pi.id_plan = p.id
                join nutricion.momento_comida m on m.id = pi.id_momento
                join nutricion.receta r on r.id = pi.id_receta
                left join interaccion.seguimiento_plan_item s on s.id_plan_item = pi.id
                where p.id_paciente = %s and pi.fecha_programada = %s
                order by m.orden
            """
            cur.execute(sql, (id_paciente, fecha))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

    def obtener_adherencia(self, id_paciente: str, dias_atras: int) -> dict:
        with db_cursor() as cur:
            sql = """
                select 
                    count(pi.id) as total,
                    count(s.id) filter (where s.id_estado_consumo = 1) as consumidos
                from interaccion.plan_nutricional p
                join interaccion.plan_item pi on pi.id_plan = p.id
                left join interaccion.seguimiento_plan_item s on s.id_plan_item = pi.id
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
                "racha_dias": 0 # Implementación de racha pendiente si se requiere
            }

    def obtener_lista_compras(self, id_paciente: str, fecha_inicio: date, fecha_fin: date) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                with recetas_plan as (
                    select distinct pi.id_receta
                    from interaccion.plan_nutricional p
                    join interaccion.plan_item pi on pi.id_plan = p.id
                    where p.id_paciente = %s 
                      and pi.fecha_programada >= %s 
                      and pi.fecha_programada <= %s
                ),
                ingredientes_detalle as (
                    select 
                        i.id as id_ingrediente,
                        i.nombre as titulo,
                        sg.nombre as categoria,
                        sum(ri.peso_en_gramos) as total_gramos,
                        ri.unidad_visual as unidad
                    from recetas_plan rp
                    join nutricion.receta_ingrediente ri on ri.id_receta = rp.id_receta
                    join nutricion.ingrediente i on i.id = ri.id_ingrediente
                    join nutricion.subgrupo_alimentario sg on sg.id = i.id_subgrupo_alimentario
                    group by i.id, i.nombre, sg.nombre, ri.unidad_visual
                )
                select 
                    id_ingrediente as id,
                    titulo,
                    categoria,
                    total_gramos,
                    unidad,
                    case 
                        when unidad = 'gramos' or unidad = 'g' then (total_gramos::text || ' g')
                        else (round(total_gramos::numeric, 1)::text || ' ' || unidad)
                    end as cantidad,
                    false as comprado
                from ingredientes_detalle
                order by categoria, titulo
            """
            cur.execute(sql, (id_paciente, fecha_inicio, fecha_fin))
            columnas = [desc[0] for desc in cur.description]
            return [dict(zip(columnas, row)) for row in cur.fetchall()]

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
                        count(s.id) filter (where s.id_estado_consumo = 1) as consumidos
                    from usuarios.paciente p
                    join pacientes_medico pm on pm.id_paciente = p.id
                    left join interaccion.plan_item pi on pi.id_plan in (
                        select id from interaccion.plan_nutricional where id_paciente = p.id and vigente = true
                    )
                    left join interaccion.seguimiento_plan_item s on s.id_plan_item = pi.id
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
