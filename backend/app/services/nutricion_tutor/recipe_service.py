from app.repositories.nutrition_repository import (
    list_candidate_recipes,
    list_recipe_ingredient_map,
    list_recipe_nutrient_totals,
)
from app.services.nutricion_tutor.ingredient_service import get_patient_ingredient_permissions


def _estimate_calories(calorias_totales: float | None, nutrientes: list[dict]) -> float | None:
    if calorias_totales is not None:
        return float(calorias_totales)

    for nutrient in nutrientes:
        nutrient_name = str(nutrient.get("nutriente") or "").lower()
        if "energia" in nutrient_name or "calor" in nutrient_name:
            return float(nutrient.get("total") or 0.0)
    return None


def get_recetas_permitidas(id_paciente: str, id_momento: int | None = None) -> dict:
    permissions = get_patient_ingredient_permissions(id_paciente)
    permitted_ingredient_ids = {item["id"] for item in permissions["permitidos"]}

    recipes = list_candidate_recipes(id_momento)
    recipe_ids = [int(item["id"]) for item in recipes]
    recipe_ingredient_map = list_recipe_ingredient_map(recipe_ids)

    allowed_recipes: list[dict] = []

    for recipe in recipes:
        recipe_id = int(recipe["id"])
        recipe_ingredients = recipe_ingredient_map.get(recipe_id, set())

        if not recipe_ingredients:
            continue

        if not recipe_ingredients.issubset(permitted_ingredient_ids):
            continue

        nutrients = list_recipe_nutrient_totals(recipe_id)
        allowed_recipes.append(
            {
                "id": recipe_id,
                "nombre": recipe["nombre"],
                "calorias_estimadas": _estimate_calories(recipe.get("calorias_totales"), nutrients),
                "nutrientes": nutrients,
            }
        )

    return {"recetas": allowed_recipes}
