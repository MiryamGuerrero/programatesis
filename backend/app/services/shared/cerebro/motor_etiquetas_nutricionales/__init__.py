"""Motor de etiquetas nutricionales.

Este paquete expone el motor de reglas y utilidades de analisis/humanizacion
con una ruta semantica mas clara dentro de cerebro.
"""

from .excel_formula_analysis_service import analyze_excel_formulas, formula_to_branch_rules, slugify
from .label_calculation_service import (
    preview_ad_hoc_rule,
    process_one_pending_recalculation_job,
    recalculate_ingredient_labels,
)
from .rule_humanizer import build_human_rule

__all__ = [
    "analyze_excel_formulas",
    "build_human_rule",
    "formula_to_branch_rules",
    "preview_ad_hoc_rule",
    "process_one_pending_recalculation_job",
    "recalculate_ingredient_labels",
    "slugify",
]
