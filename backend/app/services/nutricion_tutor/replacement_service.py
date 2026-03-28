from app.repositories.nutrition_repository import list_replacements_for_ingredient


def find_equivalent_replacements(id_ingrediente_original: int, cantidad_gramos: float | None = None) -> dict:
    replacements = list_replacements_for_ingredient(id_ingrediente_original)

    payload = []
    for replacement in replacements:
        ratio = float(replacement["ratio_conversion"])
        grams = None if cantidad_gramos is None else round(cantidad_gramos * ratio, 2)
        payload.append(
            {
                "id_ingrediente_reemplazo": replacement["id_ingrediente_reemplazo"],
                "nombre": replacement["nombre"],
                "ratio_conversion": ratio,
                "gramos_recomendados": grams,
                "mensaje_aviso": replacement.get("mensaje_aviso"),
            }
        )

    return {"reemplazos": payload}
