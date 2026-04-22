from datetime import timedelta

from app.repositories.nutrition_repository import list_momentos_comida
from app.services.roles.nutricionista.modules.recetas.allowed_recipe_service import (
    get_recetas_permitidas,
)


def generate_automatic_plan(id_paciente: str, fecha_inicio, dias: int, comidas_por_dia: int) -> dict:
    moments = list_momentos_comida(comidas_por_dia)
    if not moments:
        moments = [(idx + 1, f"Comida {idx + 1}") for idx in range(comidas_por_dia)]

    items: list[dict] = []
    picker = 0
    
    # Cache recipes per date or just re-fetch (heuristic engine is fast enough)
    # But since we might have many days, let's at least differentiate between 
    # "temporary period" and "normal period" to avoid too many DB calls.
    
    recipe_cache = {}

    for offset in range(dias):
        target_date = fecha_inicio + timedelta(days=offset)
        
        # We re-fetch recipes for each day to account for temporary restrictions
        # (The engine handles the date logic)
        recipe_payload = get_recetas_permitidas(id_paciente=id_paciente, id_momento=None, target_date=target_date)
        recipes = recipe_payload["recetas"]
        
        if not recipes:
            continue

        for moment_id, moment_name in moments:
            recipe = recipes[picker % len(recipes)]
            picker += 1
            items.append(
                {
                    "fecha": target_date,
                    "id_momento": moment_id,
                    "momento": moment_name,
                    "id_receta": recipe["id"],
                    "receta": recipe["nombre"],
                }
            )

    return {"items": items}
