from typing import Dict, Any, Optional, Tuple, List
from datetime import date
from math import log
from ...core.db import db_cursor

class ServicioOMS:
    """
    Servicio especializado en cálculos antropométricos siguiendo los estándares de la OMS.
    """
    
    @staticmethod
    def calcular_edad_detallada(fecha_nacimiento: Any, fecha_control: Optional[date] = None) -> Tuple[int, int]:
        """
        Calcula la edad en años y meses totales.
        Retorna (años, meses_totales)
        """
        if isinstance(fecha_nacimiento, str):
            fecha_nacimiento = date.fromisoformat(fecha_nacimiento)
        if fecha_control is None:
            fecha_control = date.today()
        if isinstance(fecha_control, str):
            fecha_control = date.fromisoformat(fecha_control)
        
        anios = fecha_control.year - fecha_nacimiento.year
        if (fecha_control.month, fecha_control.day) < (fecha_nacimiento.month, fecha_nacimiento.day):
            anios -= 1
            
        meses_totales = (fecha_control.year - fecha_nacimiento.year) * 12 + fecha_control.month - fecha_nacimiento.month
        if fecha_control.day < fecha_nacimiento.day:
            meses_totales -= 1
            
        return anios, meses_totales

    @staticmethod
    def calcular_imc(peso_kg: float, talla_cm: float) -> float:
        """Calcula el Índice de Masa Corporal."""
        if peso_kg <= 0 or talla_cm <= 0:
            return 0.0
        return round(peso_kg / ((talla_cm / 100) ** 2), 2)

    @staticmethod
    def calcular_z_score(valor: float, l: float, m: float, s: float) -> float:
        """
        Calcula el Z-score usando el método LMS de la OMS.
        """
        if valor <= 0 or m <= 0 or s <= 0:
            return 0.0
        
        if l == 0:
            z = log(valor / m) / s
        else:
            z = (((valor / m) ** l) - 1) / (l * s)
            
        return round(z, 2)

    @staticmethod
    def obtener_parametros_lms(id_sexo: int, edad_meses: int, indicador: str) -> Optional[Dict[str, Any]]:
        """
        Obtiene los parámetros L, M, S de la base de datos para un indicador, sexo y edad específicos.
        """
        sexo_codigo = 'M' if id_sexo == 1 else 'F'
        
        with db_cursor() as cur:
            sql = """
                SELECT l, m, s
                FROM referencia.oms_curva_punto
                WHERE indicador_codigo = %s AND sexo_codigo = %s AND edad_meses = %s
                LIMIT 1
            """
            cur.execute(sql, (indicador, sexo_codigo, edad_meses))
            row = cur.fetchone()
            if not row:
                return None
            return {"l": float(row[0]), "m": float(row[1]), "s": float(row[2])}

    @staticmethod
    def clasificar_zscore(indicador: str, z_score: float) -> Dict[str, Any]:
        """
        Busca la clasificación nutricional en la tabla referencia.condicion_nutricional
        basándose en el Z-score e indicador.
        """
        with db_cursor() as cur:
            # Query que maneja los rangos dinámicos de la tabla de condiciones
            sql = """
                SELECT id, nombre, codigo
                FROM referencia.condicion_nutricional
                WHERE indicador_codigo = %s
                AND (
                    (z_min IS NULL OR (incluye_min AND %s >= z_min) OR (NOT incluye_min AND %s > z_min))
                    AND
                    (z_max IS NULL OR (incluye_max AND %s <= z_max) OR (NOT incluye_max AND %s < z_max))
                )
                ORDER BY orden LIMIT 1
            """
            cur.execute(sql, (indicador, z_score, z_score, z_score, z_score))
            row = cur.fetchone()
            if row:
                return {"id": row[0], "nombre": row[1], "codigo": row[2]}
            
            return {"id": 0, "nombre": "Sin clasificación", "codigo": "UNKNOWN"}

    @classmethod
    def evaluar_paciente_integral(cls, peso_kg: float, talla_cm: float, id_sexo: int, edad_meses: int) -> Dict[str, Any]:
        """
        Realiza la evaluación completa: IMC, Z-scores para BMI y HFA, y clasificaciones.
        """
        imc = cls.calcular_imc(peso_kg, talla_cm)
        
        # 1. Evaluación BMI/Edad
        params_bmi = cls.obtener_parametros_lms(id_sexo, edad_meses, 'BMI')
        res_bmi = {"z_score": None, "id_condicion": 0, "diagnostico": "Sin datos de referencia"}
        
        if params_bmi:
            z_bmi = cls.calcular_z_score(imc, params_bmi["l"], params_bmi["m"], params_bmi["s"])
            clasif_bmi = cls.clasificar_zscore('BMI', z_bmi)
            res_bmi = {
                "z_score": z_bmi,
                "id_condicion": clasif_bmi["id"],
                "diagnostico": clasif_bmi["nombre"],
                "codigo": clasif_bmi["codigo"]
            }

        # 2. Evaluación Talla/Edad (HFA)
        params_hfa = cls.obtener_parametros_lms(id_sexo, edad_meses, 'HFA')
        res_hfa = {"z_score": None, "id_condicion": 0, "diagnostico": "Sin datos de referencia"}
        
        if params_hfa:
            z_hfa = cls.calcular_z_score(talla_cm, params_hfa["l"], params_hfa["m"], params_hfa["s"])
            clasif_hfa = cls.clasificar_zscore('HFA', z_hfa)
            res_hfa = {
                "z_score": z_hfa,
                "id_condicion": clasif_hfa["id"],
                "diagnostico": clasif_hfa["nombre"],
                "codigo": clasif_hfa["codigo"]
            }

        return {
            "imc": imc,
            "edad_meses": edad_meses,
            "bmi_edad": res_bmi,
            "talla_edad": res_hfa
        }
