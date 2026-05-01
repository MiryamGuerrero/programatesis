from typing import Dict, Any, Optional, Tuple, List
from datetime import date
from math import log
from ...core.db import db_cursor

class ServicioOMS:
    """
    Servicio especializado en cálculos antropométricos siguiendo los estándares de la OMS.
    Cubre desde el nacimiento hasta los 19 años (0 - 228 meses).
    """
    
    @staticmethod
    def calcular_edad_detallada(fecha_nacimiento: Any, fecha_control: Optional[date] = None) -> Tuple[int, int]:
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
        if peso_kg <= 0 or talla_cm <= 0:
            return 0.0
        return round(peso_kg / ((talla_cm / 100) ** 2), 2)

    @staticmethod
    def calcular_z_score(valor: float, l: float, m: float, s: float) -> float:
        if valor <= 0 or m <= 0 or s <= 0:
            return 0.0
        if l == 0:
            z = log(valor / m) / s
        else:
            z = (((valor / m) ** l) - 1) / (l * s)
        return round(z, 2)

    @staticmethod
    def obtener_parametros_lms(id_sexo: int, edad_meses: int, indicador: str) -> Optional[Dict[str, Any]]:
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
            return {"l": float(row[0]), "m": float(row[1]), "s": float(row[2])} if row else None

    @staticmethod
    def clasificar_zscore(indicador: str, z_score: float) -> Dict[str, Any]:
        """
        BUSCA DIRECTAMENTE EN LA TABLA MAESTRA DE CONDICIONES
        """
        with db_cursor() as cur:
            sql = """
                SELECT id, nombre
                FROM heuristico.condicion
                WHERE indicador_codigo = %s AND id_tipo_condicion = 3
                AND (
                    (z_min IS NULL OR (incluye_min AND %s >= z_min) OR (NOT incluye_min AND %s > z_min))
                    AND
                    (z_max IS NULL OR (incluye_max AND %s <= z_max) OR (NOT incluye_max AND %s < z_max))
                )
                ORDER BY orden_oms LIMIT 1
            """
            cur.execute(sql, (indicador, z_score, z_score, z_score, z_score))
            row = cur.fetchone()
            return {"id": row[0], "nombre": row[1]} if row else {"id": None, "nombre": "Sin clasificación"}

    @classmethod
    def evaluar_paciente_integral(cls, peso_kg: float, talla_cm: float, id_sexo: int, edad_meses: int) -> Dict[str, Any]:
        imc = cls.calcular_imc(peso_kg, talla_cm)
        
        # Evaluación BMI
        params_bmi = cls.obtener_parametros_lms(id_sexo, edad_meses, 'BMI')
        res_bmi = {"z_score": None, "id_condicion": None, "diagnostico": "Sin referencia", "ideal": 0.0}
        if params_bmi:
            z_bmi = cls.calcular_z_score(imc, params_bmi["l"], params_bmi["m"], params_bmi["s"])
            clasif = cls.clasificar_zscore('BMI', z_bmi)
            res_bmi = {
                "z_score": z_bmi, 
                "id_condicion": clasif["id"], 
                "diagnostico": clasif["nombre"],
                "ideal": round(params_bmi["m"], 2) # El valor M es el IMC ideal
            }

        # Evaluación Talla
        params_hfa = cls.obtener_parametros_lms(id_sexo, edad_meses, 'HFA')
        res_hfa = {"z_score": None, "id_condicion": None, "diagnostico": "Sin referencia", "ideal": 0.0}
        if params_hfa:
            z_hfa = cls.calcular_z_score(talla_cm, params_hfa["l"], params_hfa["m"], params_hfa["s"])
            clasif = cls.clasificar_zscore('HFA', z_hfa)
            res_hfa = {
                "z_score": z_hfa, 
                "id_condicion": clasif["id"], 
                "diagnostico": clasif["nombre"],
                "ideal": round(params_hfa["m"], 2) # El valor M es la talla ideal
            }
            
        # Evaluación Peso para la edad (WFA) - Importante para menores de 5 años
        res_wfa = {"z_score": None, "id_condicion": None, "diagnostico": "Sin referencia", "ideal": 0.0}
        if edad_meses <= 60:
            params_wfa = cls.obtener_parametros_lms(id_sexo, edad_meses, 'WFA')
            if params_wfa:
                z_wfa = cls.calcular_z_score(peso_kg, params_wfa["l"], params_wfa["m"], params_wfa["s"])
                clasif = cls.clasificar_zscore('WFA', z_wfa)
                res_wfa = {
                    "z_score": z_wfa, 
                    "id_condicion": clasif["id"], 
                    "diagnostico": clasif["nombre"],
                    "ideal": round(params_wfa["m"], 2)
                }

        # Calcular el peso ideal aproximado
        # Si tiene < 5 años, usamos la mediana de WFA. Si tiene > 5 años, usamos BMI ideal * talla^2
        peso_ideal = 0.0
        if edad_meses <= 60 and res_wfa["ideal"] > 0:
            peso_ideal = res_wfa["ideal"]
        elif params_bmi and talla_cm > 0:
            peso_ideal = round(params_bmi["m"] * ((talla_cm / 100) ** 2), 2)

        return {
            "imc": imc, 
            "edad_meses": edad_meses, 
            "bmi_edad": res_bmi, 
            "talla_edad": res_hfa,
            "peso_edad": res_wfa,
            "peso_ideal_estimado": peso_ideal,
            # Para retrocompatibilidad visual en banners que solo esperan un texto
            "diagnostico_nutri_texto": res_bmi["diagnostico"] if edad_meses > 60 else res_wfa["diagnostico"],
            "diagnostico_talla_texto": res_hfa["diagnostico"],
            "peso_ideal": peso_ideal,
            "talla_ideal": res_hfa["ideal"]
        }
