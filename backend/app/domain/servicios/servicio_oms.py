from typing import Dict, Any, Optional, Tuple, List
from datetime import date
from math import log
import logging
from ...core.db import db_cursor

logger = logging.getLogger(__name__)

class ServicioOMS:
    """
    Servicio especializado en cálculos antropométricos siguiendo los estándares de la OMS.
    Cubre desde el nacimiento hasta los 19 años (0 - 228 meses).
    """

    @staticmethod
    def calcular_edad_dias(fecha_nacimiento: date, fecha_control: date) -> int:
        """Calcula la diferencia exacta en días entre dos fechas."""
        delta = fecha_control - fecha_nacimiento
        return delta.days

    @staticmethod
    def calcular_edad_meses(fecha_nacimiento: date, fecha_control: date) -> int:
        """Calcula meses completos entre dos fechas."""
        meses = (fecha_control.year - fecha_nacimiento.year) * 12 + fecha_control.month - fecha_nacimiento.month
        if fecha_control.day < fecha_nacimiento.day:
            meses -= 1
        return meses

    @staticmethod
    def calcular_imc(peso_kg: float, talla_cm: float) -> float:
        """Calcula el Índice de Masa Corporal (IMC)."""
        if peso_kg <= 0 or talla_cm <= 0:
            return 0.0
        return peso_kg / ((talla_cm / 100) ** 2)

    @staticmethod
    def normalizar_sexo(id_sexo: int) -> str:
        """Convierte id_sexo a código 'M' o 'F'."""
        if id_sexo == 1:
            return 'M'
        if id_sexo == 2:
            return 'F'
        raise ValueError(f"ID de sexo inválido: {id_sexo}. Debe ser 1 (M) o 2 (F).")

    @staticmethod
    def calcular_z_score(valor: float, l: float, m: float, s: float) -> float:
        """Implementa la fórmula LMS de la OMS para calcular Z-score."""
        if valor <= 0 or m <= 0 or s <= 0:
            return 0.0
        if l == 0:
            z = log(valor / m) / s
        else:
            z = (((valor / m) ** l) - 1) / (l * s)
        return z

    @staticmethod
    def obtener_parametros_lms(sexo_codigo: str, edad_dias: int, edad_meses: int, indicador: str) -> Optional[Dict[str, Any]]:
        """
        Busca los valores L, M, S en la tabla oms_curva_punto.
        Para <= 60 meses usa edad_dias, para > 60 meses usa edad_meses.
        """
        with db_cursor() as cur:
            if edad_meses <= 60:
                # Búsqueda por días
                sql = """
                    SELECT l, m, s, id
                    FROM referencia.oms_curva_punto
                    WHERE indicador_codigo = %s AND sexo_codigo = %s AND edad_dias = %s
                    LIMIT 1
                """
                cur.execute(sql, (indicador, sexo_codigo, edad_dias))
            else:
                # Búsqueda por meses
                sql = """
                    SELECT l, m, s, id
                    FROM referencia.oms_curva_punto
                    WHERE indicador_codigo = %s AND sexo_codigo = %s AND edad_meses = %s
                    LIMIT 1
                """
                cur.execute(sql, (indicador, sexo_codigo, edad_meses))
            
            row = cur.fetchone()
            if row:
                return {
                    "l": float(row[0]), 
                    "m": float(row[1]), 
                    "s": float(row[2]),
                    "punto_id": row[3]
                }
            
            # Fallback para niños pequeños si no existe el día exacto (buscar el más cercano)
            if edad_meses <= 60:
                sql_fallback = """
                    SELECT l, m, s, id
                    FROM referencia.oms_curva_punto
                    WHERE indicador_codigo = %s AND sexo_codigo = %s
                    ORDER BY ABS(edad_dias - %s) ASC
                    LIMIT 1
                """
                cur.execute(sql_fallback, (indicador, sexo_codigo, edad_dias))
                row = cur.fetchone()
                if row:
                    return {"l": float(row[0]), "m": float(row[1]), "s": float(row[2]), "punto_id": row[3]}
                    
            return None

    @staticmethod
    def clasificar_zscore(indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        """
        Determina el diagnóstico basado en los rangos de Z-score definidos en la base de datos.
        """
        with db_cursor() as cur:
            sql = """
                SELECT id, diagnostico, severidad
                FROM referencia.oms_clasificacion_zscore
                WHERE indicador_codigo = %s
                AND edad_min_meses <= %s AND edad_max_meses >= %s
                AND (
                    (z_min IS NULL OR (incluye_min AND %s >= z_min) OR (NOT incluye_min AND %s > z_min))
                    AND
                    (z_max IS NULL OR (incluye_max AND %s <= z_max) OR (NOT incluye_max AND %s < z_max))
                )
                ORDER BY orden LIMIT 1
            """
            cur.execute(sql, (indicador, edad_meses, edad_meses, z_score, z_score, z_score, z_score))
            row = cur.fetchone()
            if row:
                return {"id": row[0], "diagnostico": row[1], "severidad": row[2]}
            return {"id": None, "diagnostico": "Sin clasificación disponible", "severidad": None}

    @classmethod
    def evaluar_indicador(cls, indicador: str, valor: float, sexo_codigo: str, edad_dias: int, edad_meses: int) -> Dict[str, Any]:
        """Evalúa un único indicador antropométrico."""
        params = cls.obtener_parametros_lms(sexo_codigo, edad_dias, edad_meses, indicador)
        if not params:
            return {
                "z_score": None, 
                "diagnostico": "Sin referencia OMS para este indicador y edad", 
                "id_clasificacion": None,
                "ideal": 0.0
            }
        
        z_score = cls.calcular_z_score(valor, params["l"], params["m"], params["s"])
        clasificacion = cls.clasificar_zscore(indicador, z_score, edad_meses)
        
        return {
            "z_score": round(z_score, 2),
            "diagnostico": clasificacion["diagnostico"],
            "id_clasificacion": clasificacion["id"],
            "ideal": round(params["m"], 2)
        }

    @staticmethod
    def calcular_peso_desde_imc_mediano(imc_mediano: Optional[float], talla_cm: float) -> float:
        """Calcula el peso ideal aplicando el IMC mediano a la talla actual."""
        if imc_mediano is None or imc_mediano <= 0 or talla_cm <= 0:
            return 0.0
        return round(imc_mediano * ((talla_cm / 100) ** 2), 2)

    @classmethod
    def evaluar_paciente_integral(
        cls, 
        peso_kg: float, 
        talla_cm: float, 
        id_sexo: int, 
        fecha_nacimiento: Any, 
        fecha_control: Optional[Any] = None
    ) -> Dict[str, Any]:
        """
        Realiza una evaluación antropométrica completa siguiendo estándares OMS.
        El diagnóstico nutricional principal y el estado del peso se basan en la relación peso vs talla.
        WFA (Peso/Edad) se mantiene como indicador complementario.
        """
        if peso_kg <= 0: raise ValueError("El peso debe ser mayor a 0")
        if talla_cm <= 0: raise ValueError("La talla debe ser mayor a 0")
        
        if isinstance(fecha_nacimiento, str):
            fecha_nacimiento = date.fromisoformat(fecha_nacimiento)
        
        if fecha_control is None:
            fecha_control = date.today()
        elif isinstance(fecha_control, str):
            fecha_control = date.fromisoformat(fecha_control)
            
        if fecha_nacimiento > date.today():
            raise ValueError("La fecha de nacimiento no puede ser futura")
        if fecha_control < fecha_nacimiento:
            raise ValueError("La fecha de control no puede ser anterior al nacimiento")
            
        sexo_codigo = cls.normalizar_sexo(id_sexo)
        edad_dias = cls.calcular_edad_dias(fecha_nacimiento, fecha_control)
        edad_meses = cls.calcular_edad_meses(fecha_nacimiento, fecha_control)
        
        if edad_meses > 228:
            raise ValueError("La edad excede los 19 años (228 meses) soportados por la OMS")
            
        imc = cls.calcular_imc(peso_kg, talla_cm)
        advertencias = []
        
        # 1. Evaluación de indicadores individuales
        res_bmi = cls.evaluar_indicador('BMI', imc, sexo_codigo, edad_dias, edad_meses)
        res_talla = cls.evaluar_indicador('HFA', talla_cm, sexo_codigo, edad_dias, edad_meses)
        res_peso_edad = cls.evaluar_indicador('WFA', peso_kg, sexo_codigo, edad_dias, edad_meses)
        
        # Futuro: Soporte para WFH (Peso para la talla) si se carga en la base
        res_peso_talla = None 
        
        # 2. Selección de Indicador Nutricional Principal
        # Mientras no exista WFH/WFL, usamos BMI como proxy porque incorpora la talla actual.
        z_principal = None
        indicador_principal = None
        diagnostico_nutri = ""
        peso_ideal_estimado = 0.0
        referencia_peso_talla_disponible = False

        if res_peso_talla and res_peso_talla.get("z_score") is not None:
            indicador_principal = "WFH" # Weight-for-Height
            z_principal = res_peso_talla["z_score"]
            diagnostico_nutri = res_peso_talla["diagnostico"]
            peso_ideal_estimado = res_peso_talla["ideal"]
            referencia_peso_talla_disponible = True
        else:
            indicador_principal = "BMI"
            z_principal = res_bmi.get("z_score")
            diagnostico_nutri = res_bmi["diagnostico"]
            # El peso ideal se estima con la mediana del IMC para la edad aplicada a la Talla Actual
            peso_ideal_estimado = cls.calcular_peso_desde_imc_mediano(res_bmi.get("ideal"), talla_cm)
            referencia_peso_talla_disponible = False
            if edad_meses <= 60:
                advertencias.append("Para menores de 5 años, la OMS recomienda complementar con peso para talla/longitud. Actualmente se usa IMC/edad como aproximación.")

        # 3. Determinación de Estado de Peso
        if z_principal is None:
            estado_peso = "sin_referencia"
        elif z_principal > 1: # > +1SD: Riesgo sobrepeso / Sobrepeso / Obesidad
            estado_peso = "disminuir"
        elif z_principal < -2: # < -2SD: Desnutrición / Delgadez
            estado_peso = "aumentar"
        else:
            estado_peso = "mantener"

        # 4. Clasificación de Talla (HFA)
        z_hfa = res_talla.get("z_score")
        diagnostico_talla = res_talla["diagnostico"]
        talla_mediana = res_talla["ideal"]

        # 5. Hallazgo Complementario (WFA)
        z_wfa = res_peso_edad.get("z_score")
        diagnostico_peso_comp = res_peso_edad["diagnostico"]

        # 6. Cálculos de Deltas (Descriptivos)
        ganancia_peso_necesaria = round(peso_ideal_estimado - peso_kg, 2)
        ganancia_talla_necesaria = round(talla_mediana - talla_cm, 2)

        # 7. Construcción de Resumen Clínico
        apertura = f"Evaluación antropométrica a los {edad_meses} meses. "
        
        # Línea de Nutrición
        if z_principal is None:
            nutri_linea = "Sin referencia OMS para determinar el diagnóstico nutricional principal."
        else:
            nutri_linea = f"Diagnóstico nutricional principal ({indicador_principal}/Edad): {diagnostico_nutri}."

        # Línea de Talla
        if z_hfa is None:
            talla_linea = "Sin referencia OMS para clasificación de talla."
        else:
            if z_hfa < -2:
                talla_linea = f"Presenta {diagnostico_talla.lower()} para la edad. Requiere seguimiento longitudinal y evaluación clínica."
            elif z_hfa > 2:
                talla_linea = "La talla para la edad está por encima del rango esperado. Correlacionar con antecedentes familiares."
            else:
                talla_linea = "La talla para la edad se encuentra dentro del rango esperado."

        # Línea de Recomendación de Peso
        if estado_peso == "aumentar":
            peso_linea = f"Se recomienda intervención para recuperación ponderal. Peso estimado hacia la mediana: {peso_ideal_estimado} kg."
        elif estado_peso == "disminuir":
            peso_linea = f"Se recomienda intervención para reducción gradual del exceso ponderal. Peso estimado hacia la mediana: {peso_ideal_estimado} kg."
        elif estado_peso == "mantener":
            peso_linea = "El peso es adecuado para la talla actual."
        else:
            peso_linea = "No se puede emitir recomendación de peso por falta de referencia."

        # Hallazgo complementario WFA
        complemento_wfa = ""
        if z_wfa is not None and abs(z_wfa) > 2 and estado_peso == "mantener":
            complemento_wfa = f" El peso para la edad se encuentra {diagnostico_peso_comp.lower()} como hallazgo complementario, probablemente asociado a la talla del paciente."
        elif z_wfa is None and edad_meses > 120:
            complemento_wfa = " Peso para la edad no disponible para mayores de 10 años; no afecta el diagnóstico principal."

        resumen_texto = f"{apertura}{nutri_linea} {talla_linea} {peso_linea}{complemento_wfa}"

        return {
            "edad_dias": edad_dias,
            "edad_meses": edad_meses,
            "imc": round(imc, 2),
            "bmi_edad": res_bmi,
            "talla_edad": res_talla,
            "peso_edad": res_peso_edad,
            "diagnostico_nutri_texto": diagnostico_nutri,
            "diagnostico_talla_texto": diagnostico_talla,
            "diagnostico_peso_complementario": diagnostico_peso_comp,
            "diagnostico_combinado": f"{diagnostico_nutri} / {diagnostico_talla}",
            "resumen_clinico": resumen_texto.strip(),
            "peso_ideal_estimado": peso_ideal_estimado,
            "talla_ideal": talla_mediana,
            "ganancia_peso_necesaria": ganancia_peso_necesaria,
            "ganancia_talla_necesaria": ganancia_talla_necesaria,
            "estado_peso": estado_peso,
            "advertencias": advertencias,
            "indicador_nutricional_principal": indicador_principal,
            "peso_edad_es_complementario": True,
            "z_indicador_peso_talla": z_principal,
            "referencia_peso_talla_disponible": referencia_peso_talla_disponible
        }
