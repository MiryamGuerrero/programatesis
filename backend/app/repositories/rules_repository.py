from app.core.db import db_cursor


RuleRow = dict[str, int | str | None]


def list_rules_for_conditions(condition_ids: list[int]) -> list[RuleRow]:
    if not condition_ids:
        return []

    sql = """
        select
            r.id,
            a.codigo as accion_codigo,
            o.codigo as objetivo_codigo,
            r.id_ingrediente,
            r.id_grupo_alimentario,
            r.id_etiqueta,
            r.mensaje_error
        from dom_reglas_motor.condicion_regla cr
        inner join dom_reglas_motor.regla r on r.id = cr.id_regla
        inner join dom_reglas_catalogos.catalogo_accion a on a.id = r.id_accion
        inner join dom_reglas_catalogos.catalogo_objetivo_regla o on o.id = r.id_tipo_objetivo
        where cr.id_condicion = any(%s)
    """

    with db_cursor() as cur:
        cur.execute(sql, (condition_ids,))
        rows = cur.fetchall()

    result: list[RuleRow] = []
    for row in rows:
        result.append(
            {
                "id": row[0],
                "accion_codigo": row[1],
                "objetivo_codigo": row[2],
                "id_ingrediente": row[3],
                "id_grupo_alimentario": row[4],
                "id_etiqueta": row[5],
                "mensaje_error": row[6],
            }
        )
    return result
