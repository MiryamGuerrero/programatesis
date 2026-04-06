"""Clasificacion de estado nutricional segun OMS (IMC y z-score)."""

from .anthropometry_diagnosis_service import (  # noqa: F401
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
