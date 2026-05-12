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
        Realiza una evaluación antropométrica completa y genera un diagnóstico integral.
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
        
        # 1. Evaluación de indicadores individuales
        # BMI/Edad (Estado nutricional actual)
        res_bmi = cls.evaluar_indicador('BMI', imc, sexo_codigo, edad_dias, edad_meses)
        # Talla/Edad (Crecimiento lineal histórico)
        res_talla = cls.evaluar_indicador('HFA', talla_cm, sexo_codigo, edad_dias, edad_meses)
        # Peso/Edad (Masa corporal total) - Principalmente útil < 10 años
        res_peso = cls.evaluar_indicador('WFA', peso_kg, sexo_codigo, edad_dias, edad_meses)
        
        # 2. Determinación del Diagnóstico Consolidado
        diag_nutri = res_bmi["diagnostico"]
        diag_talla = res_talla["diagnostico"]
        diag_peso = res_peso["diagnostico"]

        z_bmi = res_bmi.get("z_score") or 0
        z_hfa = res_talla.get("z_score") or 0

        # 3. Cálculo de Ideales y Deltas
        talla_ideal = res_talla["ideal"]
        peso_ideal = 0.0

        tiene_talla_baja = z_hfa < -2
        tiene_talla_alta = z_hfa > 3

        if tiene_talla_baja or tiene_talla_alta:
            if res_bmi["ideal"] > 0:
                peso_ideal = round(res_bmi["ideal"] * ((talla_cm / 100) ** 2), 2)
        elif edad_meses <= 60:
            peso_ideal = res_peso["ideal"]
        else:
            if res_bmi["ideal"] > 0:
                peso_ideal = round(res_bmi["ideal"] * ((talla_cm / 100) ** 2), 2)

        ganancia_peso = round(peso_ideal - peso_kg, 2)
        ganancia_talla = round(talla_ideal - talla_cm, 2)

        # estado_peso basado en BMI, no en WFA (para evitar contradicciones)
        if z_bmi > 1:
            estado_peso = "disminuir"
        elif z_bmi < -2:
            estado_peso = "aumentar"
        else:
            estado_peso = "mantener"

        # 4. Construcción del diagnóstico combinado inteligente
        anios = edad_meses // 12
        meses_rest = edad_meses % 12
        if anios > 0:
            edad_texto = f"{anios} año{'s' if anios != 1 else ''}"
            if meses_rest > 0:
                edad_texto += f" y {meses_rest} mes{'es' if meses_rest != 1 else ''}"
        else:
            edad_texto = f"{edad_meses} mes{'es' if edad_meses != 1 else ''}"

        diag_combinado = f"{diag_nutri} / {diag_talla}"
        peso_ideal_str = f"{peso_ideal:.1f}" if peso_ideal > 0 else "N/A"
        talla_ideal_str = f"{talla_ideal:.1f}" if talla_ideal > 0 else "N/A"
        imc_str = f"{round(imc, 1):.1f}"

        diag_nutri_lower = diag_nutri.lower()
        diag_talla_lower = diag_talla.lower()
        diff_talla = abs(talla_cm - talla_ideal)

        apertura = f"Paciente de {edad_texto} ({edad_meses} meses). "

        # -- Descripción de talla --
        if "talla normal" in diag_talla_lower:
            talla_linea = f"La talla para la edad es normal y mide {talla_cm:.1f} cm."
        elif "talla alta" in diag_talla_lower:
            talla_linea = f"La talla para la edad es talla alta y mide {talla_cm:.1f} cm, es muy alto para su edad con {diff_talla:.1f} cm por encima de la mediana."
        else:
            es_severa = "severa" in diag_talla_lower
            grado = "muy bajo" if es_severa else "bajo"
            talla_linea = f"La talla para la edad es {diag_talla.lower()} y mide {talla_cm:.1f} cm, es {grado} para su edad con {diff_talla:.1f} cm por debajo de la mediana."

        # -- Descripción nutricional --
        if "normal" in diag_nutri_lower:
            nutri_linea = "Diagnóstico nutricional normal."
        elif "riesgo" in diag_nutri_lower:
            nutri_linea = f"Diagnóstico nutricional: {diag_nutri}."
        elif "obesidad" in diag_nutri_lower or "sobrepeso" in diag_nutri_lower:
            nutri_linea = f"Diagnóstico nutricional: {diag_nutri}."
        elif "severa" in diag_nutri_lower or "delgadez severa" in diag_nutri_lower or "emaciación severa" in diag_nutri_lower:
            nutri_linea = f"Diagnóstico nutricional: {diag_nutri}."
        else:
            nutri_linea = f"Diagnóstico nutricional: {diag_nutri}."

        # -- Recomendación --
        ideales = f"Peso ideal {peso_ideal_str} kg (IMC: {imc_str}), talla esperada {talla_ideal_str} cm."

        if estado_peso == "aumentar":
            recom = f"Debe aumentar {abs(ganancia_peso):.1f} kg"
            if ganancia_talla > 0.5:
                recom += f" y crecer {ganancia_talla:.1f} cm"
            recom += " para alcanzar el rango normal."
        elif estado_peso == "disminuir":
            recom = f"Debe disminuir {abs(ganancia_peso):.1f} kg."
            if ganancia_talla > 0.5:
                recom += f" Ademas presenta retraso de talla ({ganancia_talla:.1f} cm por debajo de la mediana)."
        else:
            if ganancia_talla > 0.5:
                recom = f"El peso es adecuado para su talla actual, pero presenta retraso de talla ({ganancia_talla:.1f} cm por debajo de la mediana)."
            else:
                recom = "Se encuentra dentro del rango esperado."

        resumen_texto = f"{apertura}{nutri_linea} {talla_linea} {ideales} {recom}"

        return {
            "edad_dias": edad_dias,
            "edad_meses": edad_meses,
            "imc": round(imc, 2),
            "bmi_edad": res_bmi,
            "talla_edad": res_talla,
            "peso_edad": res_peso,
            "diagnostico_nutri_texto": diag_nutri,
            "diagnostico_talla_texto": diag_talla,
            "diagnostico_peso_complementario": diag_peso,
            "diagnostico_combinado": diag_combinado,
            "resumen_clinico": resumen_texto,
            "peso_ideal_estimado": peso_ideal,
            "talla_ideal": talla_ideal,
            "ganancia_peso_necesaria": ganancia_peso,
            "ganancia_talla_necesaria": ganancia_talla,
            "estado_peso": estado_peso
        }
