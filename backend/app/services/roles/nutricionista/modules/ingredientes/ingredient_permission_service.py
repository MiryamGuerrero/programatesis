from datetime import date
from app.repositories.nutrition_repository import (
    list_active_ingredients,
    list_ingredient_tags,
)
from app.engine.heuristic_engine import run_heuristic_engine, is_ingredient_safe


def get_patient_ingredient_permissions(id_paciente: str, target_date: date | None = None) -> dict:
    # Use the new Heuristic Engine
    heuristic_result = run_heuristic_engine(id_paciente, target_date)
    
    all_ingredients = list_active_ingredients()
    tags_map = list_ingredient_tags()

    permitted: list[dict] = []
    restricted: list[dict] = []

    for ingredient in all_ingredients:
        ingredient_id = int(ingredient["id"])
        group_id = ingredient.get("id_grupo_alimentario")
        tags = tags_map.get(ingredient_id, set())
        
        is_safe = is_ingredient_safe(ingredient_id, group_id, tags, heuristic_result)

        if not is_safe:
            # Find the specific reason (if possible)
            reasons = []
            if ingredient_id in heuristic_result["prohibited_ingredients"]:
                reasons.append("eliminado_ingrediente")
            if group_id and group_id in heuristic_result["prohibited_groups"]:
                reasons.append("eliminado_grupo")
            if tags & heuristic_result["prohibited_tags"]:
                reasons.append("eliminado_etiqueta")
                
            restricted.append(
                {
                    "id": ingredient_id,
                    "nombre": ingredient["nombre"],
                    "id_grupo_alimentario": group_id,
                    "motivo": ",".join(reasons) if reasons else "restringido",
                }
            )
            continue

        # Check for prioritization in the rules
        motive = "permitido"
        for rule in heuristic_result["rules"]:
            if rule["accion_codigo"] == "PRIORIZAR":
                if rule["objetivo_codigo"] == "INGREDIENTE" and rule["id_ingrediente"] == ingredient_id:
                    motive = "priorizado"
                    break
                if rule["objetivo_codigo"] == "GRUPO" and rule["id_grupo_alimentario"] == group_id:
                    motive = "priorizado"
                    break
                if rule["objetivo_codigo"] == "ETIQUETA" and rule["id_etiqueta"] in tags:
                    motive = "priorizado"
                    break

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
