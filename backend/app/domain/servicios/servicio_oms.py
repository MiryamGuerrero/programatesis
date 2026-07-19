from __future__ import annotations

from datetime import date
from math import log
from typing import Any, Dict, Optional

class ServicioOMS:
    """Clasificacion antropometrica OMS usando referencia.oms_referencia_zscore.

    Regla central: el diagnostico principal de peso no usa WFA. Para menores de
    5 anios usa peso para longitud/talla (WFL/WFH) y desde 61 meses usa BMI.
    """

    CONDICION_HEURISTICA_NOMBRE = {
        100: "Emaciacion severa",
        101: "Emaciacion",
        104: "Sobrepeso",
        105: "Obesidad",
        110: "Normal",
        111: "Posible riesgo de sobrepeso",
        112: "Talla normal",
        117: "Talla alta",
        118: "Delgadez severa",
        119: "Delgadez",
        122: "Sobrepeso",
        123: "Obesidad",
        124: "Talla baja severa",
        125: "Talla baja",
    }

    INDICADOR_NOMBRE_CLINICO = {
        "WFL": "peso para longitud",
        "WFH": "peso para talla",
        "BMI": "IMC para edad",
        "LHFA": "longitud/talla para edad",
        "HFA": "talla para edad",
        "WFA": "peso para edad",
    }

    @staticmethod
    def calcular_edad_dias(fecha_nacimiento: date, fecha_control: date) -> int:
        return (fecha_control - fecha_nacimiento).days

    @staticmethod
    def calcular_edad_meses(fecha_nacimiento: date, fecha_control: date) -> int:
        meses = (fecha_control.year - fecha_nacimiento.year) * 12 + fecha_control.month - fecha_nacimiento.month
        if fecha_control.day < fecha_nacimiento.day:
            meses -= 1
        return meses

    @staticmethod
    def calcular_imc(peso_kg: float, talla_cm: float) -> float:
        if peso_kg <= 0 or talla_cm <= 0:
            raise ValueError("Peso y talla deben ser mayores a 0")
        talla_m = talla_cm / 100
        return peso_kg / (talla_m * talla_m)

    @staticmethod
    def normalizar_sexo(id_sexo: int | str) -> str:
        token = str(id_sexo).strip().upper()
        if token in {"1", "M", "MASCULINO", "HOMBRE"}:
            return "M"
        if token in {"2", "F", "FEMENINO", "MUJER"}:
            return "F"
        raise ValueError("Sexo invalido. Use 1/M para masculino o 2/F para femenino.")

    @staticmethod
    def calcular_z_score(valor: float, l: float, m: float, s: float) -> float:
        if valor <= 0 or m <= 0 or s <= 0:
            raise ValueError("Valor, M y S deben ser mayores a 0 para calcular z-score")
        if l == 0:
            return log(valor / m) / s
        return (((valor / m) ** l) - 1) / (l * s)

    @staticmethod
    def _to_date(value: Any, field_name: str) -> date:
        if value is None:
            raise ValueError(f"{field_name} es requerido")
        if isinstance(value, date):
            return value
        if isinstance(value, str):
            return date.fromisoformat(value)
        raise ValueError(f"{field_name} debe ser una fecha valida")

    @staticmethod
    def seleccionar_indicador_peso(edad_meses: int) -> str:
        if 0 <= edad_meses <= 23:
            return "WFL"
        if 24 <= edad_meses <= 60:
            return "WFH"
        if 61 <= edad_meses <= 228:
            return "BMI"
        raise ValueError("Edad fuera del rango OMS disponible (0 a 228 meses)")

    @staticmethod
    def seleccionar_indicador_talla(edad_meses: int) -> str:
        if 0 <= edad_meses <= 60:
            return "LHFA"
        if 61 <= edad_meses <= 228:
            return "HFA"
        raise ValueError("Edad fuera del rango OMS disponible (0 a 228 meses)")

    @staticmethod
    def _explicacion(indicador: str, diagnostico: str) -> str:
        base = {
            "WFL": "Peso comparado con la longitud acostado; evita diagnosticar solo por edad.",
            "WFH": "Peso comparado con la talla de pie; evita diagnosticar solo por edad.",
            "BMI": "IMC comparado con la edad; apropiado desde 61 meses.",
            "LHFA": "Longitud/talla comparada con la edad para menores de 5 anios.",
            "HFA": "Talla comparada con la edad para escolares y adolescentes.",
            "WFA": "Peso para edad usado solo como alerta secundaria.",
        }.get(indicador, "Indicador OMS.")
        return f"{base} Clasificacion: {diagnostico}."

    @staticmethod
    def _clasificar_por_regla(indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        raise NotImplementedError("La clasificacion OMS por BD se implementa en infraestructura.")

    @classmethod
    def _nombre_heuristico(cls, id_condicion: Optional[int], diagnostico: str) -> str:
        if id_condicion in cls.CONDICION_HEURISTICA_NOMBRE:
            return cls.CONDICION_HEURISTICA_NOMBRE[id_condicion]
        return diagnostico

    @classmethod
    def _id_heuristico(cls, id_condicion: Optional[int]) -> Optional[int]:
        if id_condicion in cls.CONDICION_HEURISTICA_NOMBRE:
            return int(id_condicion)
        return None

    @classmethod
    def clasificar_zscore(cls, indicador: str, z_score: float, edad_meses: int) -> Dict[str, Any]:
        clasificacion = cls._clasificar_por_regla(indicador, z_score, edad_meses)
        return {
            "id": clasificacion["id_condicion"],
            "diagnostico": clasificacion["diagnostico"],
            "severidad": clasificacion["grupo"],
        }

    @staticmethod
    def _rango_referencia(indicador: str, sexo: str, campo: str) -> tuple[Optional[float], Optional[float]]:
        raise NotImplementedError("El rango OMS por BD se implementa en infraestructura.")

    @classmethod
    def obtener_referencia(
        cls,
        indicador: str,
        sexo: str,
        *,
        edad_meses: int,
        edad_dias: int,
        medida_cm: Optional[float] = None,
    ) -> Optional[Dict[str, Any]]:
        raise NotImplementedError("La referencia OMS por BD se implementa en infraestructura.")

    @classmethod
    def evaluar_indicador(
        cls,
        indicador: str,
        valor: float,
        sexo_codigo: str,
        edad_dias: int,
        edad_meses: int,
        medida_cm: Optional[float] = None,
    ) -> Dict[str, Any]:
        referencia = cls.obtener_referencia(
            indicador,
            sexo_codigo,
            edad_meses=edad_meses,
            edad_dias=edad_dias,
            medida_cm=medida_cm,
        )
        if referencia is None:
            return {
                "indicador": indicador,
                "z_score": None,
                "diagnostico": "Sin referencia OMS cargada",
                "id_clasificacion": None,
                "id_condicion": None,
                "ideal": 0.0,
                "referencia": None,
                "explicacion": "No existe fila de referencia para el indicador solicitado.",
            }

        z_score = cls.calcular_z_score(valor, referencia["l"], referencia["m"], referencia["s"])
        clasificacion = cls._clasificar_por_regla(indicador, z_score, edad_meses)
        return {
            "indicador": indicador,
            "z_score": round(z_score, 2),
            "z_score_raw": z_score,
            "diagnostico": clasificacion["diagnostico"],
            "diagnostico_heuristico": cls._nombre_heuristico(
                clasificacion["id_condicion"], clasificacion["diagnostico"]
            ),
            "id_clasificacion": clasificacion["id_condicion"],
            "id_condicion": clasificacion["id_condicion"],
            "id_condicion_heuristico": cls._id_heuristico(clasificacion["id_condicion"]),
            "ideal": round(float(referencia["m"]), 2),
            "referencia": referencia,
            "explicacion": cls._explicacion(indicador, clasificacion["diagnostico"]),
        }

    @staticmethod
    def calcular_peso_desde_imc_mediano(imc_mediano: Optional[float], talla_cm: float) -> float:
        if imc_mediano is None or imc_mediano <= 0:
            return 0.0
        return round(imc_mediano * ((talla_cm / 100) ** 2), 2)

    @classmethod
    def mapear_oms_a_heuristico(cls, id_condicion: Optional[int], default: int) -> int:
        return int(id_condicion) if cls._id_heuristico(id_condicion) else default

    @classmethod
    def _construir_resumen_clinico(
        cls,
        *,
        sexo_txt: str,
        edad_meses: int,
        peso_kg: float,
        talla_cm: float,
        indicador_peso: str,
        indicador_talla: str,
        res_peso: Dict[str, Any],
        res_talla: Dict[str, Any],
        res_wfa: Dict[str, Any],
    ) -> str:
        anios = edad_meses // 12
        meses_restantes = edad_meses % 12
        edad_txt = f"{anios} años y {meses_restantes} meses" if anios > 0 else f"{meses_restantes} meses"
        
        nombre_peso = cls.INDICADOR_NOMBRE_CLINICO.get(indicador_peso, indicador_peso)
        nombre_talla = cls.INDICADOR_NOMBRE_CLINICO.get(indicador_talla, indicador_talla)
        diagnostico_peso = res_peso.get("diagnostico_heuristico") or res_peso["diagnostico"]
        diagnostico_talla = res_talla.get("diagnostico_heuristico") or res_talla["diagnostico"]

        partes = [
            (
                f"Paciente {sexo_txt} de {edad_txt}, evaluado con peso de {peso_kg:g} kg "
                f"y talla de {talla_cm:g} cm."
            ),
            (
                f"Estado nutricional: {diagnostico_peso.upper()} (basado en {nombre_peso}). "
                f"Crecimiento lineal: {diagnostico_talla.upper()} (basado en {nombre_talla})."
            ),
        ]

        # Casos especiales de importancia clínica
        talla_baja = res_talla.get("id_condicion") in {124, 125}
        peso_adecuado = res_peso.get("id_condicion") == 110
        
        if talla_baja and peso_adecuado:
            partes.append(
                "Nota: Se observa un retraso en el crecimiento lineal (talla baja), "
                "sin embargo, el peso actual es proporcional a su estatura. "
                "No debe interpretarse como desnutrición aguda."
            )

        z_peso = res_peso.get("z_score")
        if z_peso is not None:
            if z_peso > 2:
                partes.append("Alerta: El paciente presenta indicadores de exceso de peso significativo.")
            elif z_peso < -2:
                partes.append("Alerta: Se detecta un déficit ponderal que requiere intervención nutricional.")

        if res_wfa["z_score"] is not None and abs(res_wfa["z_score"] - (z_peso or 0)) > 1.5:
             partes.append(
                 "Existe una discrepancia significativa entre el peso para la edad y el indicador principal; "
                 "esto confirma la importancia de no usar el peso para la edad como único criterio diagnóstico."
             )

        partes.append("Se recomienda seguimiento clínico periódico para monitorear la evolución de las curvas de crecimiento.")
        return " ".join(partes)

    @classmethod
    def evaluar_paciente_integral(
        cls,
        peso_kg: float,
        talla_cm: float,
        id_sexo: int | str,
        fecha_nacimiento: Any,
        fecha_control: Optional[Any] = None,
    ) -> Dict[str, Any]:
        if peso_kg is None:
            raise ValueError("peso_kg es requerido")
        if talla_cm is None:
            raise ValueError("talla_cm es requerida")
        if id_sexo is None:
            raise ValueError("sexo es requerido")

        peso_kg = float(peso_kg)
        talla_cm = float(talla_cm)
        if peso_kg <= 0:
            raise ValueError("El peso debe ser mayor a 0")
        if talla_cm <= 0:
            raise ValueError("La talla debe ser mayor a 0")

        fecha_nacimiento = cls._to_date(fecha_nacimiento, "fecha_nacimiento")
        fecha_control = cls._to_date(fecha_control or date.today(), "fecha_evaluacion")
        if fecha_control < fecha_nacimiento:
            raise ValueError("La fecha de evaluacion no puede ser anterior al nacimiento")

        sexo_codigo = cls.normalizar_sexo(id_sexo)
        edad_dias = cls.calcular_edad_dias(fecha_nacimiento, fecha_control)
        edad_meses = cls.calcular_edad_meses(fecha_nacimiento, fecha_control)
        if edad_dias < 0 or edad_meses < 0:
            raise ValueError("La edad no puede ser negativa")
        if edad_meses > 228:
            raise ValueError("El paciente tiene más de 19 años. La evaluación OMS pediátrica no aplica para esta edad.")

        imc = cls.calcular_imc(peso_kg, talla_cm)
        indicador_peso = cls.seleccionar_indicador_peso(edad_meses)
        indicador_talla = cls.seleccionar_indicador_talla(edad_meses)
        advertencias: list[str] = []

        if peso_kg < 1 or peso_kg > 250:
            advertencias.append("Peso fuera de limites clinicamente esperables; revisar digitacion.")

        if indicador_peso in {"WFL", "WFH"}:
            min_cm, max_cm = cls._rango_referencia(indicador_peso, sexo_codigo, "medida_cm")
            if min_cm is not None and (talla_cm < min_cm or talla_cm > max_cm):
                raise ValueError(f"Talla/longitud fuera de la tabla {indicador_peso}: {talla_cm} cm no esta entre {min_cm} y {max_cm} cm")
            valor_peso = peso_kg
            medida_lookup = talla_cm
        else:
            valor_peso = imc
            medida_lookup = None

        res_peso = cls.evaluar_indicador(
            indicador_peso,
            valor_peso,
            sexo_codigo,
            edad_dias,
            edad_meses,
            medida_cm=medida_lookup,
        )
        res_talla = cls.evaluar_indicador(
            indicador_talla,
            talla_cm,
            sexo_codigo,
            edad_dias,
            edad_meses,
        )

        res_wfa = cls.evaluar_indicador("WFA", peso_kg, sexo_codigo, edad_dias, edad_meses)
        if res_wfa["z_score"] is not None:
            advertencias.append("WFA se reporta solo como alerta secundaria; no se usa como diagnostico principal.")

        z_peso = res_peso.get("z_score")
        if z_peso is None:
            estado_peso = "sin_referencia"
        elif z_peso < -2:
            estado_peso = "aumentar"
        elif z_peso > 1:
            estado_peso = "disminuir"
        else:
            estado_peso = "mantener"

        if indicador_peso == "BMI":
            peso_ideal = cls.calcular_peso_desde_imc_mediano(res_peso.get("ideal"), talla_cm)
        else:
            peso_ideal = float(res_peso.get("ideal") or 0)

        talla_ideal = float(res_talla.get("ideal") or 0)
        ganancia_peso = round(peso_ideal - peso_kg, 2) if peso_ideal else 0.0
        ganancia_talla = round(talla_ideal - talla_cm, 2) if talla_ideal else 0.0

        sexo_txt = "masculino" if sexo_codigo == "M" else "femenino"
        resumen = cls._construir_resumen_clinico(
            sexo_txt=sexo_txt,
            edad_meses=edad_meses,
            peso_kg=peso_kg,
            talla_cm=talla_cm,
            indicador_peso=indicador_peso,
            indicador_talla=indicador_talla,
            res_peso=res_peso,
            res_talla=res_talla,
            res_wfa=res_wfa,
        )
        diagnostico_peso_texto = res_peso.get("diagnostico_heuristico") or res_peso["diagnostico"]
        diagnostico_talla_texto = res_talla.get("diagnostico_heuristico") or res_talla["diagnostico"]

        return {
            "edad_dias": edad_dias,
            "edad_meses": edad_meses,
            "sexo": sexo_codigo,
            "tipo_medicion": "longitud_acostado" if edad_meses < 24 else "talla_de_pie",
            "imc": round(imc, 2),
            "diagnostico_peso": res_peso,
            "diagnostico_talla": res_talla,
            "peso_edad": res_wfa,
            "bmi_edad": res_peso if indicador_peso == "BMI" else cls.evaluar_indicador("BMI", imc, sexo_codigo, edad_dias, edad_meses),
            "talla_edad": res_talla,
            "diagnostico_nutri_texto": diagnostico_peso_texto,
            "diagnostico_talla_texto": diagnostico_talla_texto,
            "diagnostico_peso_complementario": res_wfa["diagnostico"],
            "diagnostico_combinado": f"{diagnostico_peso_texto} / {diagnostico_talla_texto}",
            "resumen_clinico": resumen,
            "peso_ideal_estimado": round(peso_ideal, 2),
            "talla_ideal": round(talla_ideal, 2),
            "ganancia_peso_necesaria": ganancia_peso,
            "ganancia_talla_necesaria": ganancia_talla,
            "estado_peso": estado_peso,
            "advertencias": advertencias,
            "indicador_nutricional_principal": indicador_peso,
            "indicador_talla_principal": indicador_talla,
            "peso_edad_es_complementario": True,
            "z_score_principal": z_peso,
            "id_condicion_nutricional_principal": res_peso["id_condicion"],
            "id_condicion_nutricional_heuristica": res_peso.get("id_condicion_heuristico"),
            "referencia_peso_talla_disponible": indicador_peso in {"WFL", "WFH"},
        }

    @classmethod
    def evaluar_estado_nutricional(
        cls,
        sexo_id: int,
        fecha_nacimiento: Any,
        fecha_control: Any,
        peso_kg: float,
        talla_cm: float,
        tipo_medicion: Optional[str] = None,
    ) -> Dict[str, Any]:
        return cls.evaluar_paciente_integral(peso_kg, talla_cm, sexo_id, fecha_nacimiento, fecha_control)
