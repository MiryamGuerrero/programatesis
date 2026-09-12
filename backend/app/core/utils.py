from datetime import date
from typing import Optional
from app.infraestructura.servicios.servicio_oms import ServicioOMS

def calculate_age_months(fecha_nacimiento: date, fecha_referencia: Optional[date] = None) -> int:
    """Calcula la edad en meses entre la fecha de nacimiento y una fecha de referencia."""
    if fecha_referencia is None:
        fecha_referencia = date.today()
    return ServicioOMS.calcular_edad_meses(fecha_nacimiento, fecha_referencia)
