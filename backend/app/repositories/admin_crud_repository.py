import re
from typing import Any

from psycopg import sql

from app.core.db import db_cursor


def _rows_to_dicts(cur: Any, rows: list[tuple[Any, ...]]) -> list[dict[str, Any]]:
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]


def fetch_users() -> list[dict[str, Any]]:
    query = """
        select id, id_rol, cedula, username, email, nombre_completo, telefono, direccion, activo, created_at
        from usuarios.usuario
        order by created_at desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def create_user(
    email: str,
    nombre_completo: str,
    id_rol: int,
    cedula: str | None = None,
    username: str | None = None,
) -> Any:
    columns = ["email", "nombre_completo", "id_rol"]
    values = [email.strip(), nombre_completo.strip(), id_rol]

    if cedula is not None and cedula.strip():
        columns.append("cedula")
        values.append(cedula.strip())

    if username is not None and username.strip():
        columns.append("username")
        values.append(username.strip().lower())

    placeholders = ", ".join(["%s"] * len(values))
    query = f"""
        insert into usuarios.usuario ({', '.join(columns)})
        values ({placeholders})
        returning id
    """
    with db_cursor() as cur:
        cur.execute(query, tuple(values))
        row = cur.fetchone()
    return row[0] if row else None


def update_user(
    id_usuario: str,
    cedula: str | None,
    username: str | None,
    email: str | None,
    nombre_completo: str | None,
    id_rol: int | None,
    activo: bool | None,
) -> bool:
    updates = []
    params = []

    if cedula is not None:
        updates.append("cedula = %s")
        params.append(cedula.strip())
    if username is not None:
        updates.append("username = %s")
        params.append(username.strip().lower())
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


def delete_user(id_usuario: str) -> bool:
    query = """
        delete from usuarios.usuario
        where id = %s
    """
    with db_cursor() as cur:
        cur.execute(query, (id_usuario,))
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
        select
            i.id,
            i.nombre,
            i.id_grupo_alimentario,
            g.nombre as grupo_nombre,
            i.id_subgrupo_alimentario,
            sg.nombre as subgrupo_nombre,
            i.precio_libra,
            i.factor_parte_comestible,
            i.imagen_referencia,
            i.activo
        from nutricion.ingrediente i
        left join nutricion.grupo_alimentario g
            on g.id = i.id_grupo_alimentario
        left join nutricion.subgrupo_alimentario sg
            on sg.id = i.id_subgrupo_alimentario
        order by i.id desc
    """
    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def fetch_ingredientes_page(
    search: str | None,
    id_grupo_alimentario: int | None,
    id_subgrupo_alimentario: int | None,
    include_inactive: bool,
    limit: int,
    offset: int,
) -> tuple[list[dict[str, Any]], int]:
    where_clauses: list[str] = []
    filter_params: list[Any] = []

    if not include_inactive:
        where_clauses.append("i.activo = true")

    if search:
        where_clauses.append("i.nombre ilike %s")
        filter_params.append(f"%{search}%")

    if id_grupo_alimentario is not None:
        where_clauses.append("i.id_grupo_alimentario = %s")
        filter_params.append(id_grupo_alimentario)

    if id_subgrupo_alimentario is not None:
        where_clauses.append("i.id_subgrupo_alimentario = %s")
        filter_params.append(id_subgrupo_alimentario)

    where_sql = f"where {' and '.join(where_clauses)}" if where_clauses else ""

    count_query = f"""
        select count(*)
        from nutricion.ingrediente i
        {where_sql}
    """
    data_query = f"""
        select
            i.id,
            i.nombre,
            i.id_grupo_alimentario,
            g.nombre as grupo_nombre,
            i.id_subgrupo_alimentario,
            sg.nombre as subgrupo_nombre,
            i.precio_libra,
            i.factor_parte_comestible,
            i.imagen_referencia,
            i.activo
        from nutricion.ingrediente i
        left join nutricion.grupo_alimentario g
            on g.id = i.id_grupo_alimentario
        left join nutricion.subgrupo_alimentario sg
            on sg.id = i.id_subgrupo_alimentario
        {where_sql}
        order by i.nombre asc, i.id desc
        limit %s
        offset %s
    """

    with db_cursor() as cur:
        cur.execute(count_query, tuple(filter_params))
        count_row = cur.fetchone()
        total = int(count_row[0]) if count_row else 0

        cur.execute(data_query, tuple([*filter_params, limit, offset]))
        rows = cur.fetchall()

        return _rows_to_dicts(cur, rows), total


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
    imagen_referencia: str | None = None,
) -> Any:
    query = """
        insert into nutricion.ingrediente (
            nombre,
            id_grupo_alimentario,
            id_subgrupo_alimentario,
            precio_libra,
            factor_parte_comestible,
            imagen_referencia,
            activo
        )
        values (%s, %s, %s, %s, %s, %s, true)
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
                imagen_referencia,
            ),
        )
        row = cur.fetchone()
    return row[0] if row else None


def update_ingrediente(
    id_ingrediente: int,
    nombre: str | None = None,
    id_grupo_alimentario: int | None = None,
    id_subgrupo_alimentario: int | None = None,
    precio_libra: float | None = None,
    factor_parte_comestible: float | None = None,
    imagen_referencia: str | None = None,
    actualizar_imagen_referencia: bool = False,
    activo: bool | None = None,
) -> bool:
    updates = []
    params = []

    if nombre is not None:
        updates.append("nombre = %s")
        params.append(nombre.strip())
    if id_grupo_alimentario is not None:
        updates.append("id_grupo_alimentario = %s")
        params.append(id_grupo_alimentario)
    if id_subgrupo_alimentario is not None:
        updates.append("id_subgrupo_alimentario = %s")
        params.append(id_subgrupo_alimentario)
    if precio_libra is not None:
        updates.append("precio_libra = %s")
        params.append(precio_libra)
    if factor_parte_comestible is not None:
        updates.append("factor_parte_comestible = %s")
        params.append(factor_parte_comestible)
    if actualizar_imagen_referencia:
        updates.append("imagen_referencia = %s")
        params.append(imagen_referencia)
    if activo is not None:
        updates.append("activo = %s")
        params.append(activo)

    if not updates:
        return False

    params.append(id_ingrediente)
    query = f"""
        update nutricion.ingrediente
        set {', '.join(updates)}
        where id = %s
    """
    with db_cursor() as cur:
        cur.execute(query, tuple(params))
        return cur.rowcount > 0


def delete_ingrediente(id_ingrediente: int) -> bool:
    query = """
        update nutricion.ingrediente
        set activo = false
        where id = %s
    """
    with db_cursor() as cur:
        cur.execute(query, (id_ingrediente,))
        return cur.rowcount > 0


def fetch_ingrediente_composicion_metadata() -> list[tuple[str, str]]:
    query = """
        select column_name, data_type
        from information_schema.columns
        where table_schema = 'nutricion'
          and table_name = 'ingrediente_composicion'
          and column_name <> 'id_ingrediente'
        order by ordinal_position
    """
    with db_cursor() as cur:
        cur.execute(query)
        rows = cur.fetchall()

    return [(str(row[0]), str(row[1])) for row in rows]


def fetch_ingrediente_composicion(
    id_ingrediente: int,
    columnas: list[str],
) -> dict[str, Any] | None:
    if not columnas:
        return {}

    columns_sql = sql.SQL(", ").join(sql.Identifier(columna) for columna in columnas)
    statement = sql.SQL(
        """
        select {columns}
        from nutricion.ingrediente_composicion
        where id_ingrediente = %s
        limit 1
        """
    ).format(columns=columns_sql)

    with db_cursor() as cur:
        cur.execute(statement, (id_ingrediente,))
        row = cur.fetchone()
        if row is None:
            return None

    return dict(zip(columnas, row, strict=False))


def upsert_ingrediente_composicion(
    id_ingrediente: int,
    valores: dict[str, Any],
    metadata: list[tuple[str, str]],
) -> bool:
    if not metadata:
        return False

    data_type_by_column = {column_name: data_type for column_name, data_type in metadata}
    known_columns = [column_name for column_name, _ in metadata]
    normalized_values: dict[str, Any] = {}
    for column_name in known_columns:
        if column_name in valores:
            normalized_values[column_name] = valores[column_name]
            continue

        data_type = data_type_by_column[column_name]
        normalized_values[column_name] = "" if data_type in ("character varying", "text") else 0

    insert_columns = ["id_ingrediente", *known_columns]
    insert_values = [id_ingrediente, *(normalized_values[column_name] for column_name in known_columns)]

    statement = sql.SQL(
        """
        insert into nutricion.ingrediente_composicion ({columns})
        values ({values_placeholders})
        on conflict (id_ingrediente)
        do update set {updates}
        """
    ).format(
        columns=sql.SQL(", ").join(sql.Identifier(column_name) for column_name in insert_columns),
        values_placeholders=sql.SQL(", ").join(
            sql.Placeholder() for _ in insert_columns
        ),
        updates=sql.SQL(", ").join(
            sql.SQL("{} = excluded.{}").format(
                sql.Identifier(column_name),
                sql.Identifier(column_name),
            )
            for column_name in known_columns
        ),
    )

    with db_cursor() as cur:
        cur.execute(statement, tuple(insert_values))
        return True


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


def _slugify_label_code(label_name: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", label_name.strip().lower()).strip("_")
    if not normalized:
        normalized = "etiqueta"
    return f"MAN_{normalized[:60].upper()}"


def fetch_etiquetas_nutricionales() -> list[dict[str, Any]]:
    query = """
        select id, codigo, nombre_visible
        from nutricion.etiqueta_nutricional
        order by nombre_visible asc
    """
    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def _find_etiqueta_by_nombre(nombre: str) -> dict[str, Any] | None:
    query = """
        select id, codigo, nombre_visible
        from nutricion.etiqueta_nutricional
        where lower(nombre_visible) = lower(%s)
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(query, (nombre.strip(),))
        row = cur.fetchone()
        if not row:
            return None
        return {"id": row[0], "codigo": row[1], "nombre_visible": row[2]}


def create_etiqueta_nutricional(nombre_visible: str, codigo: str | None = None) -> dict[str, Any]:
    existing = _find_etiqueta_by_nombre(nombre_visible)
    if existing is not None:
        return existing

    base_code = (codigo or "").strip().upper() or _slugify_label_code(nombre_visible)
    next_code = base_code
    suffix = 1

    query_exists = """
        select id, codigo, nombre_visible
        from nutricion.etiqueta_nutricional
        where codigo = %s
        limit 1
    """
    query_insert = """
        insert into nutricion.etiqueta_nutricional (codigo, nombre_visible)
        values (%s, %s)
        returning id, codigo, nombre_visible
    """

    with db_cursor() as cur:
        while True:
            cur.execute(query_exists, (next_code,))
            row = cur.fetchone()
            if row is None:
                break

            # If someone reused the same code for the same label, return it.
            if str(row[2]).strip().lower() == nombre_visible.strip().lower():
                return {"id": row[0], "codigo": row[1], "nombre_visible": row[2]}

            suffix += 1
            next_code = f"{base_code}_{suffix}"

        cur.execute(query_insert, (next_code, nombre_visible.strip()))
        created = cur.fetchone()

    if not created:
        raise RuntimeError("No fue posible crear la etiqueta nutricional")

    return {"id": created[0], "codigo": created[1], "nombre_visible": created[2]}


def update_etiqueta_nutricional(
    id_etiqueta: int,
    nombre_visible: str | None = None,
    codigo: str | None = None,
) -> bool:
    updates = []
    params = []

    if nombre_visible is not None:
        updates.append("nombre_visible = %s")
        params.append(nombre_visible.strip())
    if codigo is not None:
        updates.append("codigo = %s")
        params.append(codigo.strip().upper())

    if not updates:
        return False

    params.append(id_etiqueta)
    query = f"""
        update nutricion.etiqueta_nutricional
        set {', '.join(updates)}
        where id = %s
    """
    with db_cursor() as cur:
        cur.execute(query, tuple(params))
        return cur.rowcount > 0


def delete_etiqueta_nutricional(id_etiqueta: int) -> bool:
    with db_cursor() as cur:
        cur.execute(
            """
            delete from nutricion.ingrediente_etiqueta
            where id_etiqueta = %s
            """,
            (id_etiqueta,),
        )
        cur.execute(
            """
            delete from nutricion.etiqueta_nutricional
            where id = %s
            """,
            (id_etiqueta,),
        )
        return cur.rowcount > 0


def ingrediente_exists(id_ingrediente: int) -> bool:
    query = """
        select 1
        from nutricion.ingrediente
        where id = %s
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(query, (id_ingrediente,))
        return cur.fetchone() is not None


def etiqueta_exists(id_etiqueta: int) -> bool:
    query = """
        select 1
        from nutricion.etiqueta_nutricional
        where id = %s
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(query, (id_etiqueta,))
        return cur.fetchone() is not None


def fetch_ingrediente_etiquetas(id_ingrediente: int) -> list[dict[str, Any]]:
    query = """
        select
            en.id as id_etiqueta,
            en.codigo,
            en.nombre_visible
        from nutricion.ingrediente_etiqueta ie
        inner join nutricion.etiqueta_nutricional en
            on en.id = ie.id_etiqueta
        where ie.id_ingrediente = %s
        order by en.nombre_visible asc
    """
    with db_cursor() as cur:
        cur.execute(query, (id_ingrediente,))
        return _rows_to_dicts(cur, cur.fetchall())


def assign_etiqueta_to_ingrediente(id_ingrediente: int, id_etiqueta: int) -> bool:
    query = """
        insert into nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
        values (%s, %s)
        on conflict (id_ingrediente, id_etiqueta) do nothing
    """
    with db_cursor() as cur:
        cur.execute(query, (id_ingrediente, id_etiqueta))
        return True


def remove_etiqueta_from_ingrediente(id_ingrediente: int, id_etiqueta: int) -> bool:
    query = """
        delete from nutricion.ingrediente_etiqueta
        where id_ingrediente = %s
          and id_etiqueta = %s
    """
    with db_cursor() as cur:
        cur.execute(query, (id_ingrediente, id_etiqueta))
        return cur.rowcount > 0
