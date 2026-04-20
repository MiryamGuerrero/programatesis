from app.repositories.rules_repository import list_rules_for_conditions_by_type
from app.repositories.clinical_repository import get_patient_active_condition_ids

def resolve_clinical_nutrition_conflicts(id_paciente: str) -> list[dict]:
    """
    Compares medical (CLINICA) with nutritional (NUTRICIONAL) guidelines.
    Prioritizes CLINICA rules when conflicts arise for the same objective.
    """
    condition_ids = get_patient_active_condition_ids(id_paciente)
    
    clinical_rules = list_rules_for_conditions_by_type(condition_ids, "CLINICA")
    nutritional_rules = list_rules_for_conditions_by_type(condition_ids, "NUTRICIONAL")
    
    # Map clinical rules by objective for quick lookup
    # Key: (objetivo_codigo, id_objetivo)
    clinical_map = {}
    for rule in clinical_rules:
        target_id = rule["id_ingrediente"] or rule["id_grupo_alimentario"] or rule["id_etiqueta"]
        if target_id:
            key = (rule["objetivo_codigo"], target_id)
            clinical_map[key] = rule

    # Filter nutritional rules: Only keep if no clinical rule for the same target
    final_rules = list(clinical_rules)
    for rule in nutritional_rules:
        target_id = rule["id_ingrediente"] or rule["id_grupo_alimentario"] or rule["id_etiqueta"]
        if target_id:
            key = (rule["objetivo_codigo"], target_id)
            if key not in clinical_map:
                final_rules.append(rule)
            else:
                # Conflict: Clinical always rules. We skip the nutritional one.
                pass
    
    return final_rules
