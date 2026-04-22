from datetime import date
from app.core.db import db_cursor

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
    Basado en el patrón de crecimiento de la OMS (IMC para la edad).
    """
    try:
        with db_cursor() as cur:
            # Buscamos los puntos de corte (SD -3, -2, 0, 2, 3) para esa edad y sexo
            # Asumimos que id_sexo 1=Masculino, 2=Femenino coincide con la DB
            cur.execute("""
                select sd3neg, sd2neg, sd0, sd2, sd3
                from referencia.oms_curva_punto p
                join referencia.oms_curva c on c.id = p.id_curva
                where c.indicador_codigo = 'IMCE' 
                  and c.id_sexo = %s 
                  and p.meses = %s
            """, (id_sexo, edad_meses))
            
            puntos = cur.fetchone()
            if not puntos:
                return 1, "Sin referencia OMS para esta edad" # ID 1 = Normal por defecto o indeterminado

            sd3neg, sd2neg, sd0, sd2, sd3 = [float(p) for p in puntos]

            # Clasificación estándar de la OMS
            if imc < sd3neg: return 5, "Delgadez Severa"
            if imc < sd2neg: return 4, "Delgadez"
            if imc > sd3: return 3, "Obesidad"
            if imc > sd2: return 2, "Sobrepeso"
            return 1, "Eutrófico (Normal)"

    except Exception as e:
        print(f"Error en clasificacion OMS: {e}")
        return 1, "Error al clasificar"
