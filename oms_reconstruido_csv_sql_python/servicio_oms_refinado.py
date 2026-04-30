from datetime import date
from math import log
from typing import Any, Dict, Optional, Tuple

class ServicioOMS:
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
    def clasificar_bmi_edad(z: float) -> str:
        if z < -3:
            return "Delgadez severa"
        if z < -2:
            return "Delgadez"
        if z <= 1:
            return "Normal"
        if z <= 2:
            return "Sobrepeso"
        return "Obesidad"

    @staticmethod
    def clasificar_talla_edad(z: float) -> str:
        if z < -3:
            return "Talla baja severa"
        if z < -2:
            return "Talla baja"
        if z <= 3:
            return "Talla adecuada para la edad"
        return "Talla muy alta para la edad"

    @classmethod
    def evaluar_paciente(cls, peso_kg: float, talla_cm: float, referencia_bmi: Dict[str, Any], referencia_hfa: Dict[str, Any]) -> Dict[str, Any]:
        imc = cls.calcular_imc(peso_kg, talla_cm)

        z_bmi = cls.calcular_z_score(imc, float(referencia_bmi["l"]), float(referencia_bmi["m"]), float(referencia_bmi["s"]))
        z_hfa = cls.calcular_z_score(talla_cm, float(referencia_hfa["l"]), float(referencia_hfa["m"]), float(referencia_hfa["s"]))

        return {
            "imc": imc,
            "bmi_edad": {
                "z_score": z_bmi,
                "diagnostico": cls.clasificar_bmi_edad(z_bmi)
            },
            "talla_edad": {
                "z_score": z_hfa,
                "diagnostico": cls.clasificar_talla_edad(z_hfa)
            }
        }