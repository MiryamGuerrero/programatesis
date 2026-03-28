from dataclasses import dataclass, field

from app.repositories.rules_repository import list_rules_for_conditions


@dataclass
class RuleTargets:
    eliminar_ingredientes: set[int] = field(default_factory=set)
    eliminar_grupos: set[int] = field(default_factory=set)
    eliminar_etiquetas: set[int] = field(default_factory=set)
    priorizar_ingredientes: set[int] = field(default_factory=set)
    priorizar_grupos: set[int] = field(default_factory=set)
    priorizar_etiquetas: set[int] = field(default_factory=set)


OBJ_INGREDIENTE = {"INGREDIENTE", "ING"}
OBJ_GRUPO = {"GRUPO", "GRUPO_ALIMENTARIO"}
OBJ_ETIQUETA = {"ETIQUETA", "TAG"}


def _objetivo_y_id(rule: dict) -> tuple[str, int | None]:
    objective = str(rule.get("objetivo_codigo") or "").upper()
    if objective in OBJ_INGREDIENTE:
        return "ingrediente", rule.get("id_ingrediente")
    if objective in OBJ_GRUPO:
        return "grupo", rule.get("id_grupo_alimentario")
    if objective in OBJ_ETIQUETA:
        return "etiqueta", rule.get("id_etiqueta")
    return "", None


def build_rule_targets(condition_ids: list[int]) -> tuple[RuleTargets, list[dict]]:
    targets = RuleTargets()
    rules = list_rules_for_conditions(condition_ids)

    for rule in rules:
        action = str(rule.get("accion_codigo") or "").upper()
        objective, target_id = _objetivo_y_id(rule)
        if not objective or target_id is None:
            continue

        if action == "ELIMINAR":
            if objective == "ingrediente":
                targets.eliminar_ingredientes.add(int(target_id))
            elif objective == "grupo":
                targets.eliminar_grupos.add(int(target_id))
            else:
                targets.eliminar_etiquetas.add(int(target_id))

        if action == "PRIORIZAR":
            if objective == "ingrediente":
                targets.priorizar_ingredientes.add(int(target_id))
            elif objective == "grupo":
                targets.priorizar_grupos.add(int(target_id))
            else:
                targets.priorizar_etiquetas.add(int(target_id))

    return targets, rules


def evaluate_rules(
    condition_ids: list[int],
    ingrediente_ids: list[int],
    grupo_ids: list[int],
    etiqueta_ids: list[int],
) -> dict:
    targets, rules = build_rule_targets(condition_ids)

    ingredient_set = set(ingrediente_ids)
    group_set = set(grupo_ids)
    tag_set = set(etiqueta_ids)

    applied: list[dict] = []
    for rule in rules:
        action = str(rule.get("accion_codigo") or "").upper()
        objective, target_id = _objetivo_y_id(rule)
        if not objective or target_id is None:
            continue

        matched = False
        if objective == "ingrediente" and int(target_id) in ingredient_set:
            matched = True
        if objective == "grupo" and int(target_id) in group_set:
            matched = True
        if objective == "etiqueta" and int(target_id) in tag_set:
            matched = True

        if matched:
            applied.append(
                {
                    "id_regla": int(rule["id"]),
                    "accion": action,
                    "objetivo": objective,
                    "objetivo_id": int(target_id),
                    "mensaje_error": rule.get("mensaje_error"),
                }
            )

    return {
        "reglas_aplicadas": applied,
        "ingredientes_eliminados": sorted(list(targets.eliminar_ingredientes.intersection(ingredient_set))),
        "grupos_eliminados": sorted(list(targets.eliminar_grupos.intersection(group_set))),
        "etiquetas_eliminadas": sorted(list(targets.eliminar_etiquetas.intersection(tag_set))),
    }
