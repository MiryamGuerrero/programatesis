from datetime import date
from app.core.db import db_cursor
from app.services.shared.cerebro.clasificacion_estado_nutricional_oms.oms_engine import obtener_clasificacion_oms

def calcular_edad_detallada(fecha_nacimiento: date):
    """Calcula años y meses exactos."""
    hoy = date.today()
    anios = hoy.year - fecha_nacimiento.year - ((hoy.month, hoy.day) < (fecha_nacimiento.month, fecha_nacimiento.day))
    meses = (hoy.year - fecha_nacimiento.year) * 12 + hoy.month - fecha_nacimiento.month
    if hoy.day < fecha_nacimiento.day:
        meses -= 1
    return anios, meses

def clasificar_oms_imc(id_sexo: int, edad_meses: int, imc: float):
    """
    Busca en las tablas de referencia el diagnóstico nutricional.
    Utiliza el engine unificado.
    """
    # Mapping from text to ID in heuristico.condicion
    mapping = {
        "Desnutrición Severa": 11,
        "Desnutrición": 12,
        "Riesgo de Desnutrición": 13,
        "Eutrófico (Normal)": 14,
        "Sobrepeso": 4,
        "Obesidad": 5
    }
    
    try:
        res = obtener_clasificacion_oms(id_sexo, edad_meses, imc)
        if res["clasificacion"] == "Fuera de rango OMS (>19 años)":
            return 14, res["clasificacion"] # Default to Eutrophic ID or a special one if exists
            
        cond_id = mapping.get(res["clasificacion"], 14)
        return cond_id, f"Z-Score: {res['z_score']} ({res['clasificacion']})"

    except Exception as e:
        print(f"Error en clasificacion OMS: {e}")
        return 14, "Error al clasificar"
