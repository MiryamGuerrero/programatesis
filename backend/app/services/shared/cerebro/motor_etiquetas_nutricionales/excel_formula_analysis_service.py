"""Wrapper semantico para analisis de formulas Excel del motor de etiquetas."""

from app.services.shared.cerebro.calculos_etiquetas.excel_formula_analysis_service import (  # noqa: F401
    analyze_excel_formulas,
    formula_to_branch_rules,
    slugify,
)

__all__ = ["analyze_excel_formulas", "formula_to_branch_rules", "slugify"]
