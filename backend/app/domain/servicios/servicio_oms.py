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
    def clasificar_zscore(indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        """
        Busca la clasificación en la tabla maestra de condiciones filtrando por indicador,
        rango de edad y límites de Z-score. Solo considera condiciones activas.
        """
        with db_cursor() as cur:
            sql = """
                SELECT id, nombre
                FROM heuristico.condicion
                WHERE indicador_codigo = %s AND id_tipo_condicion = 3
                AND activa = true
                AND (edad_min_meses IS NULL OR %s >= edad_min_meses)
                AND (edad_max_meses IS NULL OR %s <= edad_max_meses)
                AND (
                    (z_min IS NULL OR (incluye_min AND %s >= z_min) OR (NOT incluye_min AND %s > z_min))
                    AND
                    (z_max IS NULL OR (incluye_max AND %s <= z_max) OR (NOT incluye_max AND %s < z_max))
                )
                ORDER BY orden_oms LIMIT 1
            """
            cur.execute(sql, (indicador, edad_meses, edad_meses, z_score, z_score, z_score, z_score))
            row = cur.fetchone()
            return {"id": row[0], "nombre": row[1]} if row else {"id": None, "nombre": "Sin clasificación"}

    @classmethod
    def evaluar_paciente_integral(cls, peso_kg: float, talla_cm: float, id_sexo: int, edad_meses: int) -> Dict[str, Any]:
        imc = cls.calcular_imc(peso_kg, talla_cm)
        
        # Evaluación BMI (Principal para todas las edades)
        params_bmi = cls.obtener_parametros_lms(id_sexo, edad_meses, 'BMI')
        res_bmi = {"z_score": None, "id_condicion": None, "diagnostico": "Sin referencia", "ideal": 0.0}
        if params_bmi:
            z_bmi = cls.calcular_z_score(imc, params_bmi["l"], params_bmi["m"], params_bmi["s"])
            clasif = cls.clasificar_zscore('BMI', z_bmi, edad_meses)
            res_bmi = {
                "z_score": z_bmi, 
                "id_condicion": clasif["id"], 
                "diagnostico": clasif["nombre"],
                "ideal": round(params_bmi["m"], 2)
            }

        # Evaluación Talla (HFA)
        params_hfa = cls.obtener_parametros_lms(id_sexo, edad_meses, 'HFA')
        res_hfa = {"z_score": None, "id_condicion": None, "diagnostico": "Sin referencia", "ideal": 0.0}
        if params_hfa:
            z_hfa = cls.calcular_z_score(talla_cm, params_hfa["l"], params_hfa["m"], params_hfa["s"])
            clasif = cls.clasificar_zscore('HFA', z_hfa, edad_meses)
            res_hfa = {
                "z_score": z_hfa, 
                "id_condicion": clasif["id"], 
                "diagnostico": clasif["nombre"],
                "ideal": round(params_hfa["m"], 2)
            }
            
        # Evaluación Peso para la edad (WFA) - Solo hasta los 60 meses
        res_wfa = {"z_score": None, "id_condicion": None, "diagnostico": "No aplica para mayores de 60 meses", "ideal": 0.0}
        if edad_meses <= 60:
            params_wfa = cls.obtener_parametros_lms(id_sexo, edad_meses, 'WFA')
            if params_wfa:
                z_wfa = cls.calcular_z_score(peso_kg, params_wfa["l"], params_wfa["m"], params_wfa["s"])
                clasif = cls.clasificar_zscore('WFA', z_wfa, edad_meses)
                res_wfa = {
                    "z_score": z_wfa, 
                    "id_condicion": clasif["id"], 
                    "diagnostico": clasif["nombre"],
                    "ideal": round(params_wfa["m"], 2)
                }

        # Calcular el peso ideal estimado
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
            # Diagnósticos principales según requerimiento
            "diagnostico_nutri_texto": res_bmi["diagnostico"],
            "diagnostico_talla_texto": res_hfa["diagnostico"],
            "diagnostico_peso_complementario": res_wfa["diagnostico"],
            "diagnostico_combinado": f"{res_bmi['diagnostico']} / {res_hfa['diagnostico']}",
            "peso_ideal": peso_ideal,
            "talla_ideal": res_hfa["ideal"]
        }

