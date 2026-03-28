from app.core.db import db_cursor


def get_plan_item_statuses(id_plan: int) -> list[dict[str, str | int | None]]:
    sql = """
        select
            pi.id,
            cec.codigo
        from interaccion.plan_item pi
        left join interaccion.seguimiento_plan_item spi on spi.id_plan_item = pi.id
        left join interaccion.catalogo_estado_consumo cec on cec.id = spi.id_estado_consumo
        where pi.id_plan = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_plan,))
        rows = cur.fetchall()

    return [{"id_plan_item": row[0], "estado": row[1]} for row in rows]


def get_patient_id_by_plan(id_plan: int) -> str | None:
    sql = """
        select id_paciente
        from interaccion.plan_nutricional
        where id = %s
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_plan,))
        row = cur.fetchone()

    if not row:
        return None
    return row[0]


def get_average_pain_for_patient(id_paciente: str) -> float | None:
    sql = """
        select avg(nivel_dolor_eva)::float
        from clinico.control_paciente
        where id_paciente = %s
          and nivel_dolor_eva is not null
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente,))
        row = cur.fetchone()

    if not row or row[0] is None:
        return None
    return float(row[0])


def get_recipe_evaluation_avg(id_paciente: str) -> list[tuple[int, float]]:
    sql = """
        select id_receta, avg(estrellas)::float
        from interaccion.evaluacion_receta
        where id_paciente = %s
        group by id_receta
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente,))
        rows = cur.fetchall()

    return [(row[0], float(row[1])) for row in rows]


def get_recipe_consumption_ratio(id_paciente: str) -> list[tuple[int, float]]:
    sql = """
        with planned as (
            select pi.id_receta, count(*) as total
            from interaccion.plan_item pi
            inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
            where pn.id_paciente = %s
            group by pi.id_receta
        ), consumed as (
            select pi.id_receta, count(*) as total
            from interaccion.plan_item pi
            inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
            inner join interaccion.seguimiento_plan_item spi on spi.id_plan_item = pi.id
            inner join interaccion.catalogo_estado_consumo cec on cec.id = spi.id_estado_consumo
            where pn.id_paciente = %s
              and cec.codigo ilike 'CONSUMIDO%%'
            group by pi.id_receta
        )
        select p.id_receta,
               case when p.total = 0 then 0 else coalesce(c.total, 0)::float / p.total end as ratio
        from planned p
        left join consumed c on c.id_receta = p.id_receta
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente, id_paciente))
        rows = cur.fetchall()

    return [(row[0], float(row[1])) for row in rows]


def upsert_preferencia_receta(id_paciente: str, id_receta: int, puntaje: float) -> None:
    sql = """
        insert into interaccion.preferencia_receta (id_paciente, id_receta, puntaje_ajuste)
        values (%s, %s, %s)
        on conflict (id_paciente, id_receta)
        do update set
            puntaje_ajuste = excluded.puntaje_ajuste,
            ultima_actualizacion = now()
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente, id_receta, puntaje))


def upsert_preferencia_ingrediente(id_paciente: str, id_ingrediente: int, puntaje: float) -> None:
    sql = """
        insert into interaccion.preferencia_ingrediente (id_paciente, id_ingrediente, puntaje_ajuste)
        values (%s, %s, %s)
        on conflict (id_paciente, id_ingrediente)
        do update set
            puntaje_ajuste = excluded.puntaje_ajuste,
            ultima_actualizacion = now()
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente, id_ingrediente, puntaje))
