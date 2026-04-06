"""Wrapper semantico para diagnostico antropometrico OMS."""

from app.services.roles.medico.modules.diagnostico_oms.anthropometry_diagnosis_service import (  # noqa: F401
    calcular_imc,
    clasificar_imc_general,
    clasificar_zscore_imc,
    diagnostico_oms,
)

__all__ = [
    "calcular_imc",
    "clasificar_imc_general",
    "clasificar_zscore_imc",
    "diagnostico_oms",
]
