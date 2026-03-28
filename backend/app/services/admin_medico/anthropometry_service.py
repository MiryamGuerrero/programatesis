from math import log

from app.repositories.clinical_repository import get_oms_reference


def calcular_imc(peso_kg: float, talla_cm: float) -> float:
    talla_m = talla_cm / 100.0
    return round(peso_kg / (talla_m * talla_m), 4)


def clasificar_imc_general(imc: float) -> str:
    if imc < 18.5:
        return "Bajo peso"
    if imc < 25:
        return "Normal"
    if imc < 30:
        return "Sobrepeso"
    return "Obesidad"


def _zscore_lms(valor: float, l: float | None, m: float | None, s: float | None) -> float:
    if l is None or m is None or s is None or m <= 0 or s <= 0:
        raise ValueError("Referencia OMS incompleta")

    l_value = float(l)
    m_value = float(m)
    s_value = float(s)

    if abs(l_value) < 1e-9:
        z = log(valor / m_value) / s_value
    else:
        z = (((valor / m_value) ** l_value) - 1.0) / (l_value * s_value)
    return round(z, 4)


def clasificar_zscore_imc(z_score: float) -> str:
    if z_score < -3:
        return "Desnutricion severa"
    if z_score < -2:
        return "Desnutricion"
    if z_score <= 1:
        return "Adecuado"
    if z_score <= 2:
        return "Riesgo de sobrepeso"
    if z_score <= 3:
        return "Sobrepeso"
    return "Obesidad"


def diagnostico_oms(indicador_codigo: str, id_sexo: int, edad_meses: int, valor: float) -> dict:
    reference = get_oms_reference(indicador_codigo, id_sexo, edad_meses)
    if not reference:
        raise ValueError("No existe referencia OMS para el indicador/sexo/edad solicitados")

    l, m, s = reference
    z_score = _zscore_lms(valor=valor, l=l, m=m, s=s)

    return {
        "z_score": z_score,
        "diagnostico": clasificar_zscore_imc(z_score),
        "l": float(l) if l is not None else None,
        "m": float(m) if m is not None else None,
        "s": float(s) if s is not None else None,
    }
