from typing import Any

from psycopg import sql

from app.core.db import db_cursor


def _rows_to_dicts(cur: Any, rows: list[tuple[Any, ...]]) -> list[dict[str, Any]]:
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]


def fetch_users() -> list[dict[str, Any]]:
    query = """
        select id, id_rol, email, nombre_completo, telefono, direccion, activo, created_at
        from usuarios.usuario
        order by created_at desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def create_user(email: str, nombre_completo: str, id_rol: int) -> Any:
    query = """
        insert into usuarios.usuario (email, nombre_completo, id_rol)
        values (%s, %s, %s)
        returning id
    """
    with db_cursor() as cur:
        cur.execute(query, (email.strip(), nombre_completo.strip(), id_rol))
        row = cur.fetchone()
    return row[0] if row else None


def update_user(
    id_usuario: str,
    email: str | None,
    nombre_completo: str | None,
    id_rol: int | None,
    activo: bool | None,
) -> bool:
    updates = []
    params = []

    if email is not None:
        updates.append("email = %s")
        params.append(email.strip())
    if nombre_completo is not None:
        updates.append("nombre_completo = %s")
        params.append(nombre_completo.strip())
    if id_rol is not None:
        updates.append("id_rol = %s")
        params.append(id_rol)
    if activo is not None:
        updates.append("activo = %s")
        params.append(activo)

    if not updates:
        return False

    params.append(id_usuario)
    query = f"""
        update usuarios.usuario
        set {', '.join(updates)}
        where id = %s
    """
    with db_cursor() as cur:
        cur.execute(query, params)
        return cur.rowcount > 0


def fetch_catalog(schema_name: str, table_name: str) -> list[dict[str, Any]]:
    statement = sql.SQL("select * from {}.{} order by 1").format(
        sql.Identifier(schema_name),
        sql.Identifier(table_name),
    )
    with db_cursor() as cur:
        cur.execute(statement)
        return _rows_to_dicts(cur, cur.fetchall())


def fetch_ingredientes() -> list[dict[str, Any]]:
    query = """
        select id, nombre, id_grupo_alimentario, activo
        from nutricion.ingrediente
        order by id desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def resolve_default_group_subgroup(
    id_grupo_alimentario: int | None,
    id_subgrupo_alimentario: int | None,
) -> tuple[int, int] | None:
    query = """
        with fallback_group as (
            select id
            from nutricion.grupo_alimentario
            order by id
            limit 1
        ), selected_group as (
            select coalesce(%s, (select id from fallback_group)) as id_grupo
        )
        select
            sg.id_grupo,
            coalesce(
                %s,
                (
                    select sa.id
                    from nutricion.subgrupo_alimentario sa
                    where sa.id_grupo_alimentario = sg.id_grupo
                    order by sa.id
                    limit 1
                )
            ) as id_subgrupo
        from selected_group sg
    """
    with db_cursor() as cur:
        cur.execute(query, (id_grupo_alimentario, id_subgrupo_alimentario))
        row = cur.fetchone()
    if not row:
        return None
    return (row[0], row[1])


def create_ingrediente(
    nombre: str,
    id_grupo_alimentario: int,
    id_subgrupo_alimentario: int,
    precio_libra: float,
    factor_parte_comestible: float,
) -> Any:
    query = """
        insert into nutricion.ingrediente (
            nombre,
            id_grupo_alimentario,
            id_subgrupo_alimentario,
            precio_libra,
            factor_parte_comestible,
            activo
        )
        values (%s, %s, %s, %s, %s, true)
        returning id
    """
    with db_cursor() as cur:
        cur.execute(
            query,
            (
                nombre.strip(),
                id_grupo_alimentario,
                id_subgrupo_alimentario,
                precio_libra,
                factor_parte_comestible,
            ),
        )
        row = cur.fetchone()
    return row[0] if row else None


def fetch_recetas() -> list[dict[str, Any]]:
    query = """
        select
            r.id,
            r.nombre,
            energia.valor_total as calorias_totales
        from nutricion.receta r
        left join lateral (
            select rnc.valor_total
            from nutricion.receta_nutriente_calculado rnc
            inner join nutricion.nutriente n on n.id = rnc.id_nutriente
            where rnc.id_receta = r.id
              and (
                    lower(n.codigo) like '%%energia%%'
                    or lower(n.nombre) like '%%energ%%'
                    or lower(n.unidad_medida) = 'kcal'
              )
            order by
                case when lower(n.codigo) in ('energia_kcal', 'energia') then 0 else 1 end,
                rnc.valor_total desc
            limit 1
        ) energia on true
        where r.activa = true
        order by id desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def create_control(
    id_paciente: str,
    peso_kg: float,
    talla_cm: float,
    edad_meses: int,
    nivel_dolor_eva: int | None,
    nivel_inflamacion: int | None,
    imc_calculado: float | None,
) -> Any:
    query = """
        insert into clinico.control_paciente (
            id_paciente,
            peso_kg,
            talla_cm,
            edad_meses,
            nivel_dolor_eva,
            nivel_inflamacion,
            imc_calculado
        )
        values (%s, %s, %s, %s, %s, %s, %s)
        returning id
    """
    with db_cursor() as cur:
        cur.execute(
            query,
            (
                id_paciente,
                peso_kg,
                talla_cm,
                edad_meses,
                nivel_dolor_eva,
                nivel_inflamacion,
                imc_calculado,
            ),
        )
        row = cur.fetchone()
    return row[0] if row else None


def fetch_plan_items(id_paciente: str) -> list[dict[str, Any]]:
    query = """
        select pi.id, pi.id_plan, pi.id_receta, pi.id_momento, pi.fecha_programada
        from interaccion.plan_item pi
        inner join interaccion.plan_nutricional pn on pn.id = pi.id_plan
        where pn.id_paciente = %s
        order by pi.fecha_programada asc, pi.id asc
    """
    with db_cursor() as cur:
        cur.execute(query, (id_paciente,))
        return _rows_to_dicts(cur, cur.fetchall())


def find_estado_consumo_id(estado_codigo: str) -> int | None:
    query = """
        select id
        from interaccion.catalogo_estado_consumo
        where codigo = %s
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(query, (estado_codigo.strip(),))
        row = cur.fetchone()
    if not row:
        return None
    return int(row[0])


def register_consumo(
    id_plan_item: int,
    id_estado_consumo: int,
    id_receta_reemplazo: int | None,
    observacion: str | None,
) -> Any:
    query = """
        insert into interaccion.seguimiento_plan_item (
            id_plan_item,
            id_estado_consumo,
            id_receta_reemplazo,
            observacion,
            fecha_consumo
        )
        values (%s, %s, %s, %s, now())
        returning id
    """
    with db_cursor() as cur:
        cur.execute(
            query,
            (
                id_plan_item,
                id_estado_consumo,
                id_receta_reemplazo,
                observacion,
            ),
        )
        row = cur.fetchone()
    return row[0] if row else None


def rate_receta(
    id_paciente: str,
    id_receta: int,
    estrellas: int,
    comentario: str | None,
) -> Any:
    query = """
        insert into interaccion.evaluacion_receta (
            id_paciente,
            id_receta,
            estrellas,
            comentario,
            origen_evaluacion
        )
        values (%s, %s, %s, %s, 'APP_TUTOR')
        returning id
    """
    with db_cursor() as cur:
        cur.execute(
            query,
            (
                id_paciente,
                id_receta,
                estrellas,
                comentario,
            ),
        )
        row = cur.fetchone()
    return row[0] if row else None
