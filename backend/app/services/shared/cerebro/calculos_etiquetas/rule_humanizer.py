from __future__ import annotations

from typing import Any


def _to_text(value: Any) -> str:
    if value is None:
        return "(sin valor)"
    if isinstance(value, float):
        return f"{value:.4f}".rstrip("0").rstrip(".")
    return str(value)



def _render_condition(condition: dict[str, Any]) -> str:
    ctype = str(condition.get("tipo_condicion") or "variable_compare")
    var_name = str(condition.get("variable_nombre") or condition.get("variable_codigo") or "variable")
    operator = str(condition.get("operador") or "=")

    if ctype == "formula_excel_result_equals":
        col = str(condition.get("campo_objetivo") or "columna")
        expected = _to_text(condition.get("valor_texto"))
        return f"resultado de {col} = {expected}"

    if ctype == "text_contains_name":
        expected = _to_text(condition.get("valor_texto"))
        return f"nombre contiene '{expected}'"

    if ctype == "group_equals":
        expected = _to_text(condition.get("valor_texto"))
        return f"grupo alimentario = '{expected}'"

    if ctype == "subgroup_equals":
        expected = _to_text(condition.get("valor_texto"))
        return f"subgrupo alimentario = '{expected}'"

    if ctype == "is_null":
        return f"{var_name} es nulo"

    if ctype == "is_not_null":
        return f"{var_name} no es nulo"

    if ctype == "between":
        vmin = _to_text(condition.get("valor_numero_min"))
        vmax = _to_text(condition.get("valor_numero_max"))
        return f"{var_name} entre {vmin} y {vmax}"

    if ctype == "variable_compare":
        if condition.get("valor_numero") is not None:
            value = _to_text(condition.get("valor_numero"))
        else:
            value = _to_text(condition.get("valor_texto"))
        return f"{var_name} {operator} {value}"

    return str(condition.get("descripcion_humana") or f"condicion {ctype}")



def build_human_rule(
    rule_name: str,
    conditions: list[dict[str, Any]],
    result_label_name: str | None = None,
) -> str:
    title = rule_name.strip() or "Regla nutricional"
    lines: list[str] = [f"Regla: {title}"]

    if result_label_name:
        lines.append(f"Etiqueta objetivo: {result_label_name}")

    if not conditions:
        lines.append("Sin condiciones definidas.")
        return "\n".join(lines)

    lines.append("Condiciones:")
    for idx, condition in enumerate(conditions, start=1):
        connector = str(condition.get("conector_grupo") or "AND")
        text = _render_condition(condition)
        negado = bool(condition.get("negado"))
        if negado:
            text = f"NO ({text})"

        if idx == 1:
            lines.append(f"{idx}. {text}")
        else:
            lines.append(f"{idx}. [{connector}] {text}")

    return "\n".join(lines)
