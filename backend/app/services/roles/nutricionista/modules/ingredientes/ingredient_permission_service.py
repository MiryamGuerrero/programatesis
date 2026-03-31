from app.repositories.clinical_repository import get_patient_active_condition_ids
from app.repositories.nutrition_repository import (
    get_patient_allergies,
    list_active_ingredients,
    list_ingredient_tags,
)
from app.services.shared.rule_engine_service import RuleTargets, build_rule_targets


def _is_prioritized(
    ingredient_id: int,
    group_id: int | None,
    tags: set[int],
    targets: RuleTargets,
) -> bool:
    if ingredient_id in targets.priorizar_ingredientes:
        return True
    if group_id is not None and group_id in targets.priorizar_grupos:
        return True
    if tags.intersection(targets.priorizar_etiquetas):
        return True
    return False


def get_patient_ingredient_permissions(id_paciente: str) -> dict:
    active_conditions = get_patient_active_condition_ids(id_paciente)
    rule_targets, _ = build_rule_targets(active_conditions)
    allergy_ingredients, allergy_groups = get_patient_allergies(id_paciente)

    all_ingredients = list_active_ingredients()
    tags_map = list_ingredient_tags()

    permitted: list[dict] = []
    restricted: list[dict] = []

    for ingredient in all_ingredients:
        ingredient_id = int(ingredient["id"])
        group_id = ingredient.get("id_grupo_alimentario")
        tags = tags_map.get(ingredient_id, set())
        reasons: list[str] = []

        if ingredient_id in allergy_ingredients:
            reasons.append("alergia_ingrediente")
        if group_id is not None and int(group_id) in allergy_groups:
            reasons.append("alergia_grupo")
        if ingredient_id in rule_targets.eliminar_ingredientes:
            reasons.append("regla_eliminar_ingrediente")
        if group_id is not None and int(group_id) in rule_targets.eliminar_grupos:
            reasons.append("regla_eliminar_grupo")
        if tags.intersection(rule_targets.eliminar_etiquetas):
            reasons.append("regla_eliminar_etiqueta")

        if reasons:
            restricted.append(
                {
                    "id": ingredient_id,
                    "nombre": ingredient["nombre"],
                    "id_grupo_alimentario": group_id,
                    "motivo": ",".join(reasons),
                }
            )
            continue

        motive = "priorizado" if _is_prioritized(ingredient_id, group_id, tags, rule_targets) else "permitido"
        permitted.append(
            {
                "id": ingredient_id,
                "nombre": ingredient["nombre"],
                "id_grupo_alimentario": group_id,
                "motivo": motive,
            }
        )

    permitted.sort(key=lambda item: (item["motivo"] != "priorizado", item["nombre"]))
    restricted.sort(key=lambda item: item["nombre"])

    return {
        "permitidos": permitted,
        "restringidos": restricted,
    }
