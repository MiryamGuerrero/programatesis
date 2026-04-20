from datetime import date
from app.repositories.nutrition_repository import (
    list_candidate_recipes,
    list_recipe_ingredient_map,
    list_recipe_nutrient_totals,
    list_ingredient_tags,
)
from app.engine.heuristic_engine import run_heuristic_engine, is_recipe_safe


def _estimate_calories(calorias_totales: float | None, nutrientes: list[dict]) -> float | None:
    if calorias_totales is not None:
        return float(calorias_totales)

    for nutrient in nutrientes:
        nutrient_name = str(nutrient.get("nutriente") or "").lower()
        if "energia" in nutrient_name or "calor" in nutrient_name:
            return float(nutrient.get("total") or 0.0)
    return None


def get_recetas_permitidas(id_paciente: str, id_momento: int | None = None, target_date: date | None = None) -> dict:
    heuristic_result = run_heuristic_engine(id_paciente, target_date)
    
    recipes = list_candidate_recipes(id_momento)
    total_candidatas = len(recipes) # Contador inicial
    
    recipe_ids = [int(item["id"]) for item in recipes]
    recipe_ingredient_map = list_recipe_ingredient_map(recipe_ids)
    tags_map = list_ingredient_tags()

    allowed_recipes: list[dict] = []
    recetas_eliminadas = 0

    for recipe in recipes:
        recipe_id = int(recipe["id"])
        recipe_ingredients = recipe_ingredient_map.get(recipe_id, set())

        if not recipe_ingredients:
            recetas_eliminadas += 1
            continue

        if not is_recipe_safe(recipe_id, recipe_ingredients, heuristic_result):
            recetas_eliminadas += 1
            continue

        # ... resto de la lógica de recomendaciones ...
        recommendation = "PERMITIDO"
        frecuencia_semanal = None
        
        for ing_id in recipe_ingredients:
            rec = heuristic_result["recommendations"].get(ing_id)
            ing_tags = tags_map.get(ing_id, set())
            tag_recs = [heuristic_result["recommendations_tags"].get(t) for t in ing_tags if t in heuristic_result["recommendations_tags"]]
            
            if rec == "PRIORIZAR" or "PRIORIZAR" in tag_recs:
                recommendation = "PRIORIZAR"
                break 
            
            if rec == "DISMINUIR" or "DISMINUIR" in tag_recs:
                recommendation = "DISMINUIR"
                frecuencia_semanal = "1-2 veces por semana"

        nutrients_list = list_recipe_nutrient_totals(recipe_id)
        
        allowed_recipes.append(
            {
                "id": recipe_id,
                "nombre": recipe["nombre"],
                "calorias_estimadas": _estimate_calories(recipe.get("porciones"), nutrients_list),
                "nutrientes": nutrients_list,
                "recomendacion": recommendation,
                "frecuencia_sugerida": frecuencia_semanal
            }
        )

    print(f"\n[MOTOR HEURÍSTICO] Auditoría para paciente {id_paciente}:")
    print(f"  - Recetas candidatas totales: {total_candidatas}")
    print(f"  - Recetas eliminadas por seguridad/reglas: {recetas_eliminadas}")
    print(f"  - Recetas finales permitidas: {len(allowed_recipes)}")

    allowed_recipes.sort(key=lambda r: (r["recomendacion"] != "PRIORIZAR", r["recomendacion"] == "DISMINUIR", r["nombre"]))

    return {"recetas": allowed_recipes}
