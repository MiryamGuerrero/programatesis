from collections import defaultdict

from app.core.db import db_cursor


IngredienteRow = dict[str, int | str | None]
RecetaRow = dict[str, int | str | float | None]


def list_active_ingredients() -> list[IngredienteRow]:
    sql = """
        select id, nombre, id_grupo_alimentario
        from nutricion.ingrediente
        where activo = true
        order by nombre
    """
    with db_cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()

    return [
        {"id": row[0], "nombre": row[1], "id_grupo_alimentario": row[2]}
        for row in rows
    ]


def list_ingredient_tags() -> dict[int, set[int]]:
    sql = """
        select id_ingrediente, id_etiqueta
        from nutricion.ingrediente_etiqueta
    """
    with db_cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()

    result: dict[int, set[int]] = defaultdict(set)
    for ingredient_id, tag_id in rows:
        result[ingredient_id].add(tag_id)
    return result


def get_patient_allergies(id_paciente: str) -> tuple[set[int], set[int]]:
    ingredient_sql = """
        select id_ingrediente
        from clinico.alergia_paciente_ingrediente
        where id_paciente = %s
          and activa = true
    """
    group_sql = """
        select id_grupo_alimentario
        from clinico.alergia_paciente_grupo
        where id_paciente = %s
          and activa = true
    """

    with db_cursor() as cur:
        cur.execute(ingredient_sql, (id_paciente,))
        ingredient_rows = cur.fetchall()
        cur.execute(group_sql, (id_paciente,))
        group_rows = cur.fetchall()

    ingredient_ids = {row[0] for row in ingredient_rows}
    group_ids = {row[0] for row in group_rows}
    return ingredient_ids, group_ids


def list_candidate_recipes(id_momento: int | None = None) -> list[RecetaRow]:
    if id_momento is None:
        sql = """
            select id, nombre, calorias_totales
            from nutricion.receta
            where activa = true
            order by id
        """
        params: tuple = ()
    else:
        sql = """
            select r.id, r.nombre, r.calorias_totales
            from nutricion.receta r
            inner join nutricion.receta_momento rm on rm.id_receta = r.id
            where r.activa = true
              and rm.id_momento = %s
            order by r.id
        """
        params = (id_momento,)

    with db_cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()

    return [
        {"id": row[0], "nombre": row[1], "calorias_totales": row[2]}
        for row in rows
    ]


def list_recipe_ingredient_map(recipe_ids: list[int]) -> dict[int, set[int]]:
    if not recipe_ids:
        return {}

    sql = """
        select id_receta, id_ingrediente
        from nutricion.receta_ingrediente
        where id_receta = any(%s)
    """
    with db_cursor() as cur:
        cur.execute(sql, (recipe_ids,))
        rows = cur.fetchall()

    result: dict[int, set[int]] = defaultdict(set)
    for recipe_id, ingredient_id in rows:
        result[recipe_id].add(ingredient_id)
    return result


def list_recipe_nutrient_totals(recipe_id: int) -> list[dict[str, str | float]]:
    sql = """
        select n.nombre, n.unidad_medida,
               sum((ri.peso_en_gramos / 100.0) * inn.valor_por_100g) as total
        from nutricion.receta_ingrediente ri
        inner join nutricion.ingrediente_nutriente inn on inn.id_ingrediente = ri.id_ingrediente
        inner join nutricion.nutriente n on n.id = inn.id_nutriente
        where ri.id_receta = %s
        group by n.nombre, n.unidad_medida
        order by n.nombre
    """
    with db_cursor() as cur:
        cur.execute(sql, (recipe_id,))
        rows = cur.fetchall()

    return [
        {"nutriente": row[0], "unidad": row[1], "total": float(row[2]) if row[2] is not None else 0.0}
        for row in rows
    ]


def list_replacements_for_ingredient(id_ingrediente_original: int) -> list[dict[str, int | float | str | None]]:
    sql = """
        select
            s.id_ingrediente_reemplazo,
            i.nombre,
            s.ratio_conversion,
            s.mensaje_aviso
        from nutricion.sustituto_ingrediente s
        inner join nutricion.ingrediente i on i.id = s.id_ingrediente_reemplazo
        where s.id_ingrediente_original = %s
        order by i.nombre
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_ingrediente_original,))
        rows = cur.fetchall()

    return [
        {
            "id_ingrediente_reemplazo": row[0],
            "nombre": row[1],
            "ratio_conversion": float(row[2]) if row[2] is not None else 1.0,
            "mensaje_aviso": row[3],
        }
        for row in rows
    ]


def list_momentos_comida(limit: int) -> list[tuple[int, str]]:
    sql = """
        select id, nombre
        from nutricion.momento_comida
        order by coalesce(orden, 999), id
        limit %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (limit,))
        rows = cur.fetchall()

    return [(row[0], row[1]) for row in rows]


def list_recipe_ingredients(recipe_ids: list[int]) -> dict[int, list[int]]:
    if not recipe_ids:
        return {}

    sql = """
        select id_receta, id_ingrediente
        from nutricion.receta_ingrediente
        where id_receta = any(%s)
    """
    with db_cursor() as cur:
        cur.execute(sql, (recipe_ids,))
        rows = cur.fetchall()

    result: dict[int, list[int]] = defaultdict(list)
    for recipe_id, ingredient_id in rows:
        result[recipe_id].append(ingredient_id)
    return result
