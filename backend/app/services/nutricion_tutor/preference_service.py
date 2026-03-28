from collections import defaultdict

from app.repositories.interaccion_repository import (
    get_recipe_consumption_ratio,
    get_recipe_evaluation_avg,
    upsert_preferencia_ingrediente,
    upsert_preferencia_receta,
)
from app.repositories.nutrition_repository import list_recipe_ingredients


def _normalize_stars(avg_stars: float) -> float:
    return max(0.0, min(avg_stars / 5.0, 1.0))


def learn_preferences(id_paciente: str, persist: bool = False) -> dict:
    evaluation_scores = {recipe_id: _normalize_stars(avg) for recipe_id, avg in get_recipe_evaluation_avg(id_paciente)}
    consumption_scores = {recipe_id: ratio for recipe_id, ratio in get_recipe_consumption_ratio(id_paciente)}

    recipe_ids = sorted(set(evaluation_scores) | set(consumption_scores))
    recipe_scores: list[tuple[int, float]] = []

    for recipe_id in recipe_ids:
        score = (evaluation_scores.get(recipe_id, 0.0) * 0.7) + (consumption_scores.get(recipe_id, 0.0) * 0.3)
        recipe_scores.append((recipe_id, round(score, 4)))

    recipe_scores.sort(key=lambda item: item[1], reverse=True)

    ingredient_scores: dict[int, list[float]] = defaultdict(list)
    recipe_ingredient_map = list_recipe_ingredients([recipe_id for recipe_id, _ in recipe_scores])

    for recipe_id, score in recipe_scores:
        for ingredient_id in recipe_ingredient_map.get(recipe_id, []):
            ingredient_scores[ingredient_id].append(score)

    ingredient_ranked: list[tuple[int, float]] = []
    for ingredient_id, values in ingredient_scores.items():
        if not values:
            continue
        ingredient_ranked.append((ingredient_id, round(sum(values) / len(values), 4)))

    ingredient_ranked.sort(key=lambda item: item[1], reverse=True)

    if persist:
        for recipe_id, score in recipe_scores:
            upsert_preferencia_receta(id_paciente=id_paciente, id_receta=recipe_id, puntaje=score)
        for ingredient_id, score in ingredient_ranked:
            upsert_preferencia_ingrediente(id_paciente=id_paciente, id_ingrediente=ingredient_id, puntaje=score)

    return {
        "recetas": [{"id_receta": recipe_id, "score": score} for recipe_id, score in recipe_scores],
        "ingredientes": [{"id_ingrediente": ingredient_id, "score": score} for ingredient_id, score in ingredient_ranked],
    }
