from datetime import date
from app.repositories.rules_repository import list_rules_for_conditions_by_type
from app.repositories.clinical_repository import get_patient_active_condition_ids

def resolve_clinical_nutrition_conflicts(id_paciente: str, target_date: date | None = None) -> list[dict]:
    """
    Compares medical (CLINICA, TEMPORAL) with nutritional (NUTRICIONAL) guidelines.
    Prioritizes medical rules when conflicts arise for the same objective.
    """
    condition_ids = get_patient_active_condition_ids(id_paciente, target_date)
    
    clinical_rules = list_rules_for_conditions_by_type(condition_ids, "CLINICA")
    temporal_rules = list_rules_for_conditions_by_type(condition_ids, "TEMPORAL")
    nutritional_rules = list_rules_for_conditions_by_type(condition_ids, "NUTRICIONAL")
    
    # Combinar reglas médicas (Clínicas y Temporales)
    medical_rules = clinical_rules + temporal_rules
    
    # Map medical rules by objective for quick lookup
    medical_map = {}
    for rule in medical_rules:
        target_id = rule["id_ingrediente"] or rule["id_grupo_alimentario"] or rule["id_etiqueta"]
        if target_id:
            key = (rule["objetivo_codigo"], target_id)
            medical_map[key] = rule

    # Filter nutritional rules: Only keep if no medical rule for the same target
    final_rules = list(medical_rules)
    for rule in nutritional_rules:
        target_id = rule["id_ingrediente"] or rule["id_grupo_alimentario"] or rule["id_etiqueta"]
        if target_id:
            key = (rule["objetivo_codigo"], target_id)
            if key not in medical_map:
                final_rules.append(rule)
    
    return final_rules
