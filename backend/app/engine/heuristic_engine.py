from datetime import date
from typing import TypedDict
from app.engine.safety.filter import get_safety_restrictions
from app.engine.conflicts.resolver import resolve_clinical_nutrition_conflicts
from app.engine.temporary.adjuster import get_temporary_adjustments
from app.repositories.nutrition_repository import (
    list_active_ingredients, 
    list_ingredient_tags,
    list_recipe_ingredient_map
)

class HeuristicResult(TypedDict):
    prohibited_ingredients: set[int]
    prohibited_recipes: set[int]
    recommendations: dict[int, str]
    recommendations_tags: dict[int, str]
    rules: list[dict]

def run_heuristic_engine(id_paciente: str, target_date: date | None = None) -> HeuristicResult:
    if target_date is None:
        target_date = date.today()
        
    # 1. Obtener restricciones base (Alergias y Clínicas de ELIMINAR)
    safety = get_safety_restrictions(id_paciente)
    base_rules = resolve_clinical_nutrition_conflicts(id_paciente, target_date)
    temporal_rules = get_temporary_adjustments(id_paciente, target_date)
    
    merged_rules = base_rules + temporal_rules
    
    prohibited_ingredients = safety["ingredients"].copy()
    prohibited_subgroups = safety["subgroups"].copy()
    prohibited_tags = safety["tags"].copy()
    prohibited_recipes = set()
    recommendations = {} 
    recommendations_tags = {}

    # 2. Procesar reglas de eliminación adicionales
    for rule in merged_rules:
        action = rule.get("accion_codigo", "").upper()
        obj = rule.get("objetivo_codigo", "").upper()
        
        if action == "ELIMINAR":
            if obj == "INGREDIENTE" and rule.get("id_ingrediente"): prohibited_ingredients.add(rule["id_ingrediente"])
            elif obj == "SUBGRUPO" and rule.get("id_subgrupo_alimentario"): prohibited_subgroups.add(rule["id_subgrupo_alimentario"])
            elif obj == "ETIQUETA" and rule.get("id_etiqueta"): prohibited_tags.add(rule["id_etiqueta"])
            elif obj == "RECETA" and rule.get("id_receta"): prohibited_recipes.add(rule["id_receta"])
        
        elif action in ["PRIORIZAR", "DISMINUIR"]:
            if obj == "INGREDIENTE" and rule.get("id_ingrediente"):
                recommendations[rule["id_ingrediente"]] = action
            elif obj == "ETIQUETA" and rule.get("id_etiqueta"):
                recommendations_tags[rule["id_etiqueta"]] = action

    # 3. EXPANSIÓN CRÍTICA: De Subgrupos y Etiquetas a Ingredientes
    all_ings = list_active_ingredients()
    tags_map = list_ingredient_tags()
    
    for ing in all_ings:
        ing_id = int(ing["id"])
        # Si el subgrupo está prohibido, el ingrediente también
        if ing.get("id_subgrupo_alimentario") in prohibited_subgroups:
            prohibited_ingredients.add(ing_id)
        # Si alguna etiqueta del ingrediente está prohibida, el ingrediente también
        if tags_map.get(ing_id, set()) & prohibited_tags:
            prohibited_ingredients.add(ing_id)

    # 4. EXPANSIÓN CRÍTICA: De Ingredientes Prohibidos a RECETAS
    # Traemos el mapeo de todas las recetas y sus ingredientes
    # (En una app real, esto se cachea)
    all_recipe_maps = list_recipe_ingredient_map(None) # None trae todas
    for recipe_id, ing_ids in all_recipe_maps.items():
        # Si la receta contiene AL MENOS UN ingrediente prohibido, se elimina la receta completa
        if any(iid in prohibited_ingredients for iid in ing_ids):
            prohibited_recipes.add(recipe_id)

    return {
        "prohibited_ingredients": prohibited_ingredients,
        "prohibited_recipes": prohibited_recipes,
        "recommendations": recommendations,
        "recommendations_tags": recommendations_tags,
        "rules": merged_rules
    }

def is_ingredient_safe(ingredient_id: int, subgroup_id: int | None, tag_ids: set[int], result: HeuristicResult) -> bool:
    """
    Verifica si un ingrediente individual es seguro comparándolo con la lista negra
    generada por la expansión del motor.
    """
    if ingredient_id in result["prohibited_ingredients"]:
        return False
    return True

def is_recipe_safe(recipe_id: int, recipe_ingredient_ids: set[int], result: HeuristicResult) -> bool:
    """
    Verifica si la receta está en la lista negra generada por la expansión.
    """
    if recipe_id in result["prohibited_recipes"]:
        return False
    return True
