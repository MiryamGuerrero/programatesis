from typing import Dict, Any, Optional, Tuple
from datetime import date
from math import log
from ...core.db import db_cursor

class ServicioOMS05:
    """Servicio OMS para niños de 0 a 60 meses."""

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
            raise ValueError("Peso y talla deben ser mayores a cero")
        return round(peso_kg / ((talla_cm / 100) ** 2), 2)

    @staticmethod
    def calcular_z_score(valor: float, l: float, m: float, s: float) -> float:
        if valor <= 0 or m <= 0 or s <= 0:
            raise ValueError("Valor, M y S deben ser mayores a cero")
        if l == 0:
            z = log(valor / m) / s
        else:
            z = (((valor / m) ** l) - 1) / (l * s)
        return round(z, 2)

    @staticmethod
    def obtener_parametros_lms(id_sexo: int, edad_meses: int, indicador: str) -> Optional[Dict[str, Any]]:
        if edad_meses < 0 or edad_meses > 60:
            return None
        sexo_codigo = 'M' if id_sexo == 1 else 'F'
        with db_cursor() as cur:
            cur.execute("""
                SELECT l, m, s
                FROM referencia.oms_curva_punto
                WHERE indicador_codigo = %s
                  AND sexo_codigo = %s
                  AND edad_meses = %s
                LIMIT 1
            """, (indicador, sexo_codigo, edad_meses))
            row = cur.fetchone()
        return {"l": float(row[0]), "m": float(row[1]), "s": float(row[2])} if row else None

    @staticmethod
    def clasificar_zscore(indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        with db_cursor() as cur:
            cur.execute("""
                SELECT id, nombre, nivel_alerta, color_alerta
                FROM heuristico.condicion
                WHERE indicador_codigo = %s
                  AND id_tipo_condicion = 3
                  AND (edad_min_meses IS NULL OR %s >= edad_min_meses)
                  AND (edad_max_meses IS NULL OR %s <= edad_max_meses)
                  AND (z_min IS NULL OR (incluye_min AND %s >= z_min) OR (NOT incluye_min AND %s > z_min))
                  AND (z_max IS NULL OR (incluye_max AND %s <= z_max) OR (NOT incluye_max AND %s < z_max))
                ORDER BY orden_oms
                LIMIT 1
            """, (indicador, edad_meses, edad_meses, z_score, z_score, z_score, z_score))
            row = cur.fetchone()
        if not row:
            return {"id": None, "nombre": "Sin clasificación", "nivel_alerta": None, "color_alerta": None}
        return {"id": row[0], "nombre": row[1], "nivel_alerta": row[2], "color_alerta": row[3]}

    @classmethod
    def evaluar_paciente_0_5(cls, peso_kg: float, talla_cm: float, id_sexo: int, edad_meses: int) -> Dict[str, Any]:
        if edad_meses < 0 or edad_meses > 60:
            return {"error": "El algoritmo OMS 0-5 solo clasifica pacientes de 0 a 60 meses"}

        imc = cls.calcular_imc(peso_kg, talla_cm)

        def evaluar(indicador: str, valor: float) -> Dict[str, Any]:
            params = cls.obtener_parametros_lms(id_sexo, edad_meses, indicador)
            if not params:
                return {"z_score": None, "id_condicion": None, "diagnostico": "Sin referencia", "ideal": 0.0}
            z = cls.calcular_z_score(valor, params["l"], params["m"], params["s"])
            clasif = cls.clasificar_zscore(indicador, z, edad_meses)
            return {
                "z_score": z,
                "id_condicion": clasif["id"],
                "diagnostico": clasif["nombre"],
                "nivel_alerta": clasif["nivel_alerta"],
                "color_alerta": clasif["color_alerta"],
                "ideal": round(params["m"], 2)
            }

        res_bmi = evaluar('BMI', imc)
        res_hfa = evaluar('HFA', talla_cm)
        res_wfa = evaluar('WFA', peso_kg)

        peso_ideal_estimado = 0.0
        params_bmi = cls.obtener_parametros_lms(id_sexo, edad_meses, 'BMI')
        if params_bmi:
            peso_ideal_estimado = round(params_bmi["m"] * ((talla_cm / 100) ** 2), 2)

        return {
            "imc": imc,
            "edad_meses": edad_meses,
            "bmi_edad": res_bmi,
            "talla_edad": res_hfa,
            "peso_edad": res_wfa,
            "diagnostico_nutri_texto": res_bmi["diagnostico"],
            "diagnostico_talla_texto": res_hfa["diagnostico"],
            "diagnostico_peso_texto": res_wfa["diagnostico"],
            "peso_ideal_estimado": peso_ideal_estimado,
            "talla_ideal": res_hfa["ideal"]
        }
