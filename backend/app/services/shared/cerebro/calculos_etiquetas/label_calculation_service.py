from __future__ import annotations

from collections import defaultdict
import json
from typing import Any

from app.core.db import db_cursor


def _load_ingredient_context(id_ingrediente: int) -> dict[str, Any] | None:
    ingredient_sql = """
        select id, nombre, id_grupo_alimentario, id_subgrupo_alimentario
        from dom_nutricion_ingredientes.ingrediente
        where id = %s
          and activo = true
        limit 1
    """
    variables_sql = """
        select
            vn.codigo,
            vn.nombre_visible,
            iv.valor_numerico,
            iv.valor_texto,
            iv.valor_booleano,
            iv.estado_dato
        from dom_nutricion_ingrediente_rel.ingrediente_variable_valor iv
        inner join dom_nutricion_catalogos.variable_nutricional vn
            on vn.id = iv.id_variable_nutricional
        where iv.id_ingrediente = %s
    """

    with db_cursor() as cur:
        cur.execute(ingredient_sql, (id_ingrediente,))
        row = cur.fetchone()
        if not row:
            return None

        context = {
            "id": int(row[0]),
            "nombre": row[1],
            "id_grupo_alimentario": row[2],
            "id_subgrupo_alimentario": row[3],
            "variables": {},
        }

        cur.execute(variables_sql, (id_ingrediente,))
        for value_row in cur.fetchall():
            code = str(value_row[0] or "")
            context["variables"][code.lower()] = {
                "codigo": code,
                "nombre": value_row[1] or code,
                "valor_numerico": value_row[2],
                "valor_texto": value_row[3],
                "valor_booleano": value_row[4],
                "estado_dato": value_row[5] or "no_reportado",
            }

    return context


def _load_active_rules() -> list[dict[str, Any]]:
    sql = """
        select
            rv.id,
            rv.id_etiqueta,
            rv.version,
            rv.prioridad,
            rv.codigo_regla,
            rv.expresion_humana,
            et.nombre_visible as etiqueta_nombre,
            c.id as condicion_id,
            c.orden,
            c.grupo_logico,
            c.conector_grupo,
            c.tipo_condicion,
            c.operador,
            c.valor_numero,
            c.valor_numero_min,
            c.valor_numero_max,
            c.valor_texto,
            c.valor_lista,
            c.campo_objetivo,
            c.negado,
            c.descripcion_humana,
            vn.codigo as variable_codigo,
            vn.nombre_visible as variable_nombre
        from dom_nutricion_reglas.etiqueta_regla_version rv
        inner join dom_nutricion_catalogos.etiqueta_nutricional et
            on et.id = rv.id_etiqueta
        left join dom_nutricion_reglas.etiqueta_regla_condicion c
            on c.id_regla_version = rv.id
           and c.activa = true
        left join dom_nutricion_catalogos.variable_nutricional vn
            on vn.id = c.id_variable_nutricional
        where rv.activo = true
          and rv.estado = 'activa'
          and et.activa = true
        order by rv.prioridad asc, rv.id asc, c.orden asc
    """

    grouped: dict[int, dict[str, Any]] = {}

    with db_cursor() as cur:
        cur.execute(sql)
        for row in cur.fetchall():
            rule_id = int(row[0])
            existing = grouped.get(rule_id)
            if existing is None:
                existing = {
                    "id": rule_id,
                    "id_etiqueta": int(row[1]),
                    "version": row[2],
                    "prioridad": row[3],
                    "codigo_regla": row[4],
                    "expresion_humana": row[5],
                    "etiqueta_nombre": row[6],
                    "condiciones": [],
                }
                grouped[rule_id] = existing

            if row[7] is None:
                continue

            existing["condiciones"].append(
                {
                    "id": int(row[7]),
                    "orden": int(row[8]),
                    "grupo_logico": int(row[9] or 1),
                    "conector_grupo": str(row[10] or "AND").upper(),
                    "tipo_condicion": row[11],
                    "operador": row[12],
                    "valor_numero": row[13],
                    "valor_numero_min": row[14],
                    "valor_numero_max": row[15],
                    "valor_texto": row[16],
                    "valor_lista": row[17],
                    "campo_objetivo": row[18],
                    "negado": bool(row[19]),
                    "descripcion_humana": row[20],
                    "variable_codigo": row[21],
                    "variable_nombre": row[22],
                }
            )

    return list(grouped.values())


def _load_manual_exceptions(id_ingrediente: int) -> dict[int, dict[str, Any]]:
    sql = """
        select id_etiqueta, accion, justificacion, motivo_clinico
        from dom_nutricion_reglas.etiqueta_excepcion_manual
        where id_ingrediente = %s
          and activa = true
          and fecha_inicio <= now()
          and (fecha_fin is null or fecha_fin >= now())
    """

    result: dict[int, dict[str, Any]] = {}
    with db_cursor() as cur:
        cur.execute(sql, (id_ingrediente,))
        for row in cur.fetchall():
            result[int(row[0])] = {
                "accion": row[1],
                "justificacion": row[2],
                "motivo_clinico": row[3],
            }
    return result


def _load_current_assignments(id_ingrediente: int) -> dict[int, dict[str, Any]]:
    sql = """
        select id_etiqueta, activa, origen_asignacion, manual_override
        from dom_nutricion_ingrediente_rel.ingrediente_etiqueta
        where id_ingrediente = %s
    """
    out: dict[int, dict[str, Any]] = {}
    with db_cursor() as cur:
        cur.execute(sql, (id_ingrediente,))
        for row in cur.fetchall():
            out[int(row[0])] = {
                "activa": bool(row[1]),
                "origen_asignacion": row[2],
                "manual_override": bool(row[3]),
            }
    return out


def _extract_context_value(context: dict[str, Any], condition: dict[str, Any]) -> tuple[Any, str | None]:
    ctype = str(condition.get("tipo_condicion") or "")
    variable_code = str(condition.get("variable_codigo") or "").lower()

    if ctype == "group_equals":
        return context.get("id_grupo_alimentario"), None

    if ctype == "subgroup_equals":
        return context.get("id_subgrupo_alimentario"), None

    if ctype == "text_contains_name":
        return context.get("nombre") or "", None

    if ctype in {"is_null", "is_not_null", "between", "variable_compare"}:
        if not variable_code:
            return None, "variable_sin_codigo"
        payload = context["variables"].get(variable_code)
        if payload is None:
            return None, variable_code

        state = str(payload.get("estado_dato") or "")
        if state != "valor_real":
            return None, variable_code

        if payload.get("valor_numerico") is not None:
            return payload.get("valor_numerico"), None
        if payload.get("valor_booleano") is not None:
            return payload.get("valor_booleano"), None
        if payload.get("valor_texto") is not None:
            return payload.get("valor_texto"), None
        return None, variable_code

    if ctype == "formula_excel_result_equals":
        return None, "formula_excel_no_evaluable"

    return None, "tipo_condicion_no_soportado"


def _compare_values(left: Any, operator: str, right: Any) -> bool:
    op = operator.strip().lower()

    if op in {"=", "==", "eq"}:
        return str(left).lower() == str(right).lower()
    if op in {"!=", "<>", "neq"}:
        return str(left).lower() != str(right).lower()

    # Numeric comparisons
    try:
        ln = float(left)
        rn = float(right)
    except Exception:  # noqa: BLE001
        ln = None
        rn = None

    if ln is not None and rn is not None:
        if op in {">", "gt"}:
            return ln > rn
        if op in {">=", "gte"}:
            return ln >= rn
        if op in {"<", "lt"}:
            return ln < rn
        if op in {"<=", "lte"}:
            return ln <= rn

    if op in {"contains", "contiene"}:
        return str(right).lower() in str(left).lower()

    if op in {"in", "en"}:
        if isinstance(right, list):
            return str(left).lower() in {str(x).lower() for x in right}
        return str(left).lower() in str(right).lower()

    return False


def _evaluate_condition(context: dict[str, Any], condition: dict[str, Any]) -> tuple[bool | None, str | None]:
    ctype = str(condition.get("tipo_condicion") or "")
    value, missing_or_reason = _extract_context_value(context, condition)

    if missing_or_reason in {"formula_excel_no_evaluable", "tipo_condicion_no_soportado"}:
        return None, missing_or_reason

    if missing_or_reason is not None:
        return None, missing_or_reason

    if ctype == "is_null":
        result = value is None
    elif ctype == "is_not_null":
        result = value is not None
    elif ctype == "between":
        vmin = condition.get("valor_numero_min")
        vmax = condition.get("valor_numero_max")
        try:
            fvalue = float(value)
            result = (vmin is None or fvalue >= float(vmin)) and (vmax is None or fvalue <= float(vmax))
        except Exception:  # noqa: BLE001
            result = False
    elif ctype == "text_contains_name":
        text = str(value or "")
        expected = str(condition.get("valor_texto") or "")
        result = expected.lower() in text.lower()
    elif ctype in {"group_equals", "subgroup_equals"}:
        result = _compare_values(value, "=", condition.get("valor_texto"))
    elif ctype == "variable_compare":
        op = str(condition.get("operador") or "=")
        if condition.get("valor_numero") is not None:
            right = condition.get("valor_numero")
        elif condition.get("valor_texto") is not None:
            right = condition.get("valor_texto")
        else:
            right = condition.get("valor_lista")
        result = _compare_values(value, op, right)
    else:
        # Unsupported condition types are treated as not evaluable.
        return None, "tipo_condicion_no_soportado"

    if bool(condition.get("negado")):
        result = not result

    return bool(result), None


def _evaluate_rule(context: dict[str, Any], conditions: list[dict[str, Any]]) -> dict[str, Any]:
    if not conditions:
        return {
            "status": "insuficiente_dato",
            "matched": False,
            "missing_fields": ["regla_sin_condiciones"],
        }

    groups: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for cond in sorted(conditions, key=lambda item: item["orden"]):
        groups[int(cond.get("grupo_logico") or 1)].append(cond)

    group_results: list[bool] = []
    missing_fields: set[str] = set()

    for _, group_conditions in sorted(groups.items(), key=lambda item: item[0]):
        accumulator: bool | None = None
        for condition in group_conditions:
            cond_result, reason = _evaluate_condition(context, condition)
            connector = str(condition.get("conector_grupo") or "AND").upper()

            if cond_result is None:
                missing_fields.add(reason or "sin_dato")
                cond_bool = False
            else:
                cond_bool = cond_result

            if accumulator is None:
                accumulator = cond_bool
            elif connector == "OR":
                accumulator = accumulator or cond_bool
            else:
                accumulator = accumulator and cond_bool

        group_results.append(bool(accumulator))

    matched = any(group_results)
    if matched:
        return {"status": "matched", "matched": True, "missing_fields": sorted(missing_fields)}

    if missing_fields:
        return {
            "status": "insuficiente_dato",
            "matched": False,
            "missing_fields": sorted(missing_fields),
        }

    return {"status": "not_matched", "matched": False, "missing_fields": []}


def _upsert_assignment(
    id_ingrediente: int,
    id_etiqueta: int,
    id_regla_version: int,
    version_regla: int,
    valor_justificacion: dict[str, Any],
    estado_calculo: str,
    origen_asignacion: str,
    manual_override: bool,
    motivo_manual: str | None,
    id_usuario_modificacion: str | None,
) -> None:
    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_upsert_ingrediente_etiqueta(
                %s, %s, %s, %s, %s, %s::jsonb, %s, false, %s, %s, %s, now()
            )
            """,
            (
                id_ingrediente,
                id_etiqueta,
                origen_asignacion,
                id_regla_version,
                version_regla,
                json.dumps(valor_justificacion, ensure_ascii=False),
                estado_calculo,
                manual_override,
                motivo_manual,
                id_usuario_modificacion,
            ),
        )


def _inactivate_assignment(
    id_ingrediente: int,
    id_etiqueta: int,
    motivo: str,
    id_usuario_modificacion: str | None,
) -> None:
    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_inactivar_ingrediente_etiqueta(%s, %s, %s, %s)
            """,
            (id_ingrediente, id_etiqueta, motivo, id_usuario_modificacion),
        )


def _register_recalc_history(
    id_job: int | None,
    id_ingrediente: int,
    estado: str,
    detalle: str,
    payload: dict[str, Any] | None = None,
) -> None:
    if id_job is None:
        return

    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_registrar_recalculo_historial(
                %s, %s, null, %s, %s, %s::jsonb
            )
            """,
            (
                id_job,
                id_ingrediente,
                estado,
                detalle,
                json.dumps(payload or {}, ensure_ascii=False),
            ),
        )


def recalculate_ingredient_labels(
    id_ingrediente: int,
    user_id: str | None = None,
    recalc_job_id: int | None = None,
) -> dict[str, Any]:
    context = _load_ingredient_context(id_ingrediente)
    if context is None:
        detail = {"id_ingrediente": id_ingrediente, "status": "not_found"}
        _register_recalc_history(recalc_job_id, id_ingrediente, "error", "Ingrediente no encontrado", detail)
        return detail

    active_rules = _load_active_rules()
    exceptions = _load_manual_exceptions(id_ingrediente)
    current_assignments = _load_current_assignments(id_ingrediente)

    assigned_labels: list[int] = []
    forced_labels: list[int] = []
    removed_labels: list[int] = []
    insufficient_rules: list[int] = []

    for rule in active_rules:
        label_id = int(rule["id_etiqueta"])
        exception = exceptions.get(label_id)

        if exception:
            action = str(exception.get("accion") or "")
            if action in {"quitar", "invalidar"}:
                _inactivate_assignment(
                    id_ingrediente=id_ingrediente,
                    id_etiqueta=label_id,
                    motivo=exception.get("justificacion") or "excepcion_manual",
                    id_usuario_modificacion=user_id,
                )
                removed_labels.append(label_id)
                continue

            if action == "forzar":
                _upsert_assignment(
                    id_ingrediente=id_ingrediente,
                    id_etiqueta=label_id,
                    id_regla_version=rule["id"],
                    version_regla=rule.get("version") or 1,
                    valor_justificacion={
                        "modo": "excepcion_manual",
                        "justificacion": exception.get("justificacion"),
                        "motivo_clinico": exception.get("motivo_clinico"),
                    },
                    estado_calculo="excepcion_manual",
                    origen_asignacion="manual",
                    manual_override=True,
                    motivo_manual=exception.get("justificacion"),
                    id_usuario_modificacion=user_id,
                )
                forced_labels.append(label_id)
                continue

        eval_result = _evaluate_rule(context, rule["condiciones"])
        if eval_result["matched"]:
            _upsert_assignment(
                id_ingrediente=id_ingrediente,
                id_etiqueta=label_id,
                id_regla_version=rule["id"],
                version_regla=rule.get("version") or 1,
                valor_justificacion={
                    "modo": "regla_automatica",
                    "codigo_regla": rule.get("codigo_regla"),
                    "missing_fields": eval_result.get("missing_fields") or [],
                },
                estado_calculo="calculado",
                origen_asignacion="automatica",
                manual_override=False,
                motivo_manual=None,
                id_usuario_modificacion=user_id,
            )
            assigned_labels.append(label_id)
            continue

        if eval_result["status"] == "insuficiente_dato":
            insufficient_rules.append(int(rule["id"]))
            continue

        current = current_assignments.get(label_id)
        if current and current.get("activa") and current.get("origen_asignacion") == "automatica":
            _inactivate_assignment(
                id_ingrediente=id_ingrediente,
                id_etiqueta=label_id,
                motivo="No cumple regla automatica vigente",
                id_usuario_modificacion=user_id,
            )
            removed_labels.append(label_id)

    summary = {
        "id_ingrediente": id_ingrediente,
        "reglas_evaluadas": len(active_rules),
        "etiquetas_asignadas": assigned_labels,
        "etiquetas_forzadas": forced_labels,
        "etiquetas_removidas": removed_labels,
        "reglas_insuficiente_dato": insufficient_rules,
    }

    _register_recalc_history(
        recalc_job_id,
        id_ingrediente,
        "calculado",
        "Recalculo de etiquetas completado",
        summary,
    )

    if recalc_job_id is not None:
        with db_cursor() as cur:
            cur.execute(
                """
                select dom_nutricion_reglas.rpc_cerrar_recalculo_job(%s, 'completado', %s::jsonb)
                """,
                (recalc_job_id, json.dumps(summary, ensure_ascii=False)),
            )

    return summary


def process_one_pending_recalculation_job(worker_name: str = "fastapi") -> dict[str, Any]:
    with db_cursor() as cur:
        cur.execute(
            """
            select id, alcance, id_ingrediente, id_etiqueta, id_regla_version, parametros
            from dom_nutricion_reglas.rpc_tomar_recalculo_job(%s)
            """,
            (worker_name,),
        )
        job = cur.fetchone()

    if not job:
        return {"status": "sin_pendientes"}

    job_id = int(job[0])
    alcance = str(job[1])
    id_ingrediente = job[2]
    id_etiqueta = job[3]

    if alcance == "ingrediente" and id_ingrediente is not None:
        result = recalculate_ingredient_labels(int(id_ingrediente), recalc_job_id=job_id)
        return {"status": "ok", "job_id": job_id, "resultado": result}

    with db_cursor() as cur:
        if alcance == "etiqueta" and id_etiqueta is not None:
            cur.execute(
                """
                select id
                from dom_nutricion_ingredientes.ingrediente
                where activo = true
                order by id
                """
            )
            ingredient_ids = [int(r[0]) for r in cur.fetchall()]
        else:
            cur.execute(
                """
                select id
                from dom_nutricion_ingredientes.ingrediente
                where activo = true
                order by id
                """
            )
            ingredient_ids = [int(r[0]) for r in cur.fetchall()]

    processed = 0
    for ing_id in ingredient_ids:
        recalculate_ingredient_labels(ing_id)
        processed += 1

    resumen = {
        "alcance": alcance,
        "procesados": processed,
        "id_etiqueta": id_etiqueta,
    }

    with db_cursor() as cur:
        cur.execute(
            """
            select dom_nutricion_reglas.rpc_cerrar_recalculo_job(%s, 'completado', %s::jsonb)
            """,
            (job_id, json.dumps(resumen, ensure_ascii=False)),
        )

    return {"status": "ok", "job_id": job_id, "resultado": resumen}


def _load_active_ingredients_basic(limit: int | None = None) -> list[dict[str, Any]]:
    sql = """
        select id, nombre, id_grupo_alimentario, id_subgrupo_alimentario
        from dom_nutricion_ingredientes.ingrediente
        where activo = true
        order by nombre
    """

    if limit is not None:
        sql += " limit %s"
        params: tuple[Any, ...] = (limit,)
    else:
        params = ()

    out: list[dict[str, Any]] = []
    with db_cursor() as cur:
        cur.execute(sql, params)
        for row in cur.fetchall():
            out.append(
                {
                    "id": int(row[0]),
                    "nombre": row[1],
                    "id_grupo_alimentario": row[2],
                    "id_subgrupo_alimentario": row[3],
                }
            )
    return out


def _load_variable_payload_for_ingredients(ingredient_ids: list[int]) -> dict[int, dict[str, dict[str, Any]]]:
    if not ingredient_ids:
        return {}

    sql = """
        select
            iv.id_ingrediente,
            vn.codigo,
            iv.valor_numerico,
            iv.valor_texto,
            iv.valor_booleano,
            iv.estado_dato
        from dom_nutricion_ingrediente_rel.ingrediente_variable_valor iv
        inner join dom_nutricion_catalogos.variable_nutricional vn
            on vn.id = iv.id_variable_nutricional
        where iv.id_ingrediente = any(%s)
    """

    payload: dict[int, dict[str, dict[str, Any]]] = defaultdict(dict)
    with db_cursor() as cur:
        cur.execute(sql, (ingredient_ids,))
        for row in cur.fetchall():
            ing_id = int(row[0])
            code = str(row[1] or "").lower()
            payload[ing_id][code] = {
                "codigo": row[1],
                "valor_numerico": row[2],
                "valor_texto": row[3],
                "valor_booleano": row[4],
                "estado_dato": row[5],
            }

    return payload


def preview_ad_hoc_rule(
    conditions: list[dict[str, Any]],
    detail_limit: int = 25,
) -> dict[str, Any]:
    ingredients = _load_active_ingredients_basic()
    ingredient_ids = [item["id"] for item in ingredients]
    values_map = _load_variable_payload_for_ingredients(ingredient_ids)

    matched: list[dict[str, Any]] = []
    not_matched: list[dict[str, Any]] = []
    insufficient: list[dict[str, Any]] = []

    for ingredient in ingredients:
        context = {
            **ingredient,
            "variables": values_map.get(ingredient["id"], {}),
        }
        result = _evaluate_rule(context, conditions)

        record = {
            "id": ingredient["id"],
            "nombre": ingredient["nombre"],
            "missing_fields": result.get("missing_fields", []),
        }

        if result["matched"]:
            matched.append(record)
        elif result["status"] == "insuficiente_dato":
            insufficient.append(record)
        else:
            not_matched.append(record)

    return {
        "total_ingredientes": len(ingredients),
        "cumplen": len(matched),
        "no_cumplen": len(not_matched),
        "insuficiente_dato": len(insufficient),
        "muestra_cumplen": matched[:detail_limit],
        "muestra_no_cumplen": not_matched[:detail_limit],
        "muestra_insuficiente_dato": insufficient[:detail_limit],
    }
