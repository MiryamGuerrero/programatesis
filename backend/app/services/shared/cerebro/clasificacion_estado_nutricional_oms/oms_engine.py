from decimal import Decimal
from typing import TypedDict
from app.core.db import db_cursor

class OmsResult(TypedDict):
    z_score: float
    clasificacion: str

def calcular_imc(peso_kg: float, talla_cm: float) -> float:
    talla_m = talla_cm / 100
    return round(peso_kg / (talla_m * talla_m), 2)

def obtener_clasificacion_oms(id_sexo: int, edad_meses: int, imc: float) -> OmsResult:
    """
    Consulta las tablas de referencia de la OMS para obtener el Z-Score y clasificación.
    Utiliza la tabla referencia.oms_curva_punto que contiene L, M, S para el cálculo.
    Fórmula Z-Score: [((IMC/M)**L) - 1] / (L*S)
    """
    # Buscamos el indicador IMC para la edad (ID 1 usualmente, pero filtramos por código)
    sql = """
        SELECT l, m, s
        FROM referencia.oms_curva_punto p
        JOIN referencia.oms_curva c ON c.id = p.id_curva
        JOIN referencia.indicador_antropometrico i ON i.id = c.id_indicador
        WHERE i.codigo = 'BMI'
          AND c.id_sexo = %s
          AND p.edad_valor = %s
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (id_sexo, edad_meses))
        row = cur.fetchone()
        
        if not row:
            return {"z_score": 0.0, "clasificacion": "Fuera de rango OMS (>19 años)"}
            
        L, M, S = float(row[0]), float(row[1]), float(row[2])
        
        # Cálculo de Z-Score
        z = (((imc / M) ** L) - 1) / (L * S)
        z = round(z, 2)
        
        # Clasificación estándar OMS
        if z < -3: clas = "Desnutrición Severa"
        elif z < -2: clas = "Desnutrición"
        elif z < -1: clas = "Riesgo de Desnutrición"
        elif z <= 1: clas = "Eutrófico (Normal)"
        elif z <= 2: clas = "Sobrepeso"
        else: clas = "Obesidad"
        
        return {"z_score": z, "clasificacion": clas}
