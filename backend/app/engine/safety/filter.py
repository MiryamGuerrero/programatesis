from app.core.db import db_cursor
from app.repositories.rules_repository import list_rules_for_conditions_by_type
from app.repositories.clinical_repository import get_patient_active_condition_ids

def get_safety_restrictions(id_paciente: str) -> dict:
    """
    Returns sets of prohibited items based on allergies and strict clinical rules.
    """
    prohibited_ingredients = set()
    prohibited_subgroups = set()
    prohibited_tags = set()

    with db_cursor() as cur:
        # 1. Direct Allergies (Ingredients)
        cur.execute(
            "select id_ingrediente from clinico.alergia_paciente_ingrediente where id_paciente = %s and activa = true",
            (id_paciente,)
        )
        prohibited_ingredients.update([row[0] for row in cur.fetchall()])

        # 2. Subgroup Allergies
        cur.execute(
            "select id_subgrupo_alimentario from clinico.alergia_paciente_subgrupo where id_paciente = %s and activa = true",
            (id_paciente,)
        )
        prohibited_subgroups.update([row[0] for row in cur.fetchall()])

    # 3. Strict Clinical ELIMINAR Rules
    condition_ids = get_patient_active_condition_ids(id_paciente)
    clinical_rules = list_rules_for_conditions_by_type(condition_ids, "CLINICA")
    
    for rule in clinical_rules:
        if rule["accion_codigo"] == "ELIMINAR":
            if rule["objetivo_codigo"] == "INGREDIENTE" and rule["id_ingrediente"]:
                prohibited_ingredients.add(rule["id_ingrediente"])
            elif rule["objetivo_codigo"] == "SUBGRUPO" and rule.get("id_subgrupo_alimentario"):
                prohibited_subgroups.add(rule["id_subgrupo_alimentario"])
            elif rule["objetivo_codigo"] == "GRUPO" and rule["id_grupo_alimentario"]:
                # If it's a group, we might need more logic, but for now we track the ID
                pass 
            elif rule["objetivo_codigo"] == "ETIQUETA" and rule["id_etiqueta"]:
                prohibited_tags.add(rule["id_etiqueta"])

    return {
        "ingredients": prohibited_ingredients,
        "subgroups": prohibited_subgroups,
        "tags": prohibited_tags
    }
