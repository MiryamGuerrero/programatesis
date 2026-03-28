from datetime import timedelta

from app.repositories.nutrition_repository import list_momentos_comida
from app.services.nutricion_tutor.recipe_service import get_recetas_permitidas


def generate_automatic_plan(id_paciente: str, fecha_inicio, dias: int, comidas_por_dia: int) -> dict:
    recipe_payload = get_recetas_permitidas(id_paciente=id_paciente, id_momento=None)
    recipes = recipe_payload["recetas"]
    if not recipes:
        return {"items": []}

    moments = list_momentos_comida(comidas_por_dia)
    if not moments:
        moments = [(idx + 1, f"Comida {idx + 1}") for idx in range(comidas_por_dia)]

    items: list[dict] = []
    picker = 0

    for offset in range(dias):
        target_date = fecha_inicio + timedelta(days=offset)
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
