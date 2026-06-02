import unittest
from datetime import date
from unittest.mock import patch

from app.domain.servicios.servicio_oms import ServicioOMS


def valor_desde_z(z: float, m: float, s: float = 0.1, l: float = 1.0) -> float:
    if l == 0:
        raise AssertionError("Los tests sinteticos usan L=1")
    return m * (1 + l * s * z) ** (1 / l)


def clasificacion_mock(indicador: str, z: float, edad_meses: int):
    if indicador in {"WFL", "WFH"}:
        if z < -3:
            return {"diagnostico": "Emaciacion severa", "id_condicion": 100, "grupo": "peso"}
        if z < -2:
            return {"diagnostico": "Emaciacion", "id_condicion": 101, "grupo": "peso"}
        if z <= 1:
            return {"diagnostico": "Normal / Eutrofico", "id_condicion": 110, "grupo": "peso"}
        if z <= 2:
            return {"diagnostico": "Riesgo de sobrepeso", "id_condicion": 111, "grupo": "peso"}
        if z <= 3:
            return {"diagnostico": "Sobrepeso infantil", "id_condicion": 104, "grupo": "peso"}
        return {"diagnostico": "Obesidad infantil", "id_condicion": 105, "grupo": "peso"}

    if indicador == "BMI":
        if z < -3:
            return {"diagnostico": "Delgadez severa", "id_condicion": 118, "grupo": "peso"}
        if z < -2:
            return {"diagnostico": "Delgadez", "id_condicion": 119, "grupo": "peso"}
        if z <= 1:
            return {"diagnostico": "Normal / Eutrofico", "id_condicion": 110, "grupo": "peso"}
        if z <= 2:
            return {"diagnostico": "Sobrepeso", "id_condicion": 122, "grupo": "peso"}
        return {"diagnostico": "Obesidad", "id_condicion": 123, "grupo": "peso"}

    if indicador in {"LHFA", "HFA"}:
        if z < -3:
            return {"diagnostico": "Talla baja severa", "id_condicion": 124, "grupo": "talla"}
        if z < -2:
            return {"diagnostico": "Talla baja", "id_condicion": 125, "grupo": "talla"}
        if z <= 2:
            return {"diagnostico": "Talla normal", "id_condicion": 112, "grupo": "talla"}
        return {"diagnostico": "Talla alta", "id_condicion": 117, "grupo": "talla"}

    return {"diagnostico": "Peso normal para edad", "id_condicion": 202, "grupo": "peso_alerta"}


def referencia_mock(indicador, sexo, *, edad_meses, edad_dias, medida_cm=None):
    if indicador in {"WFL", "WFH", "WFA"}:
        m = 10.0
    elif indicador == "BMI":
        m = 16.0
    else:
        m = 100.0
    return {
        "id": 1,
        "ref_code": indicador,
        "sexo": sexo,
        "edad_meses": edad_meses,
        "edad_dias": edad_dias,
        "medida_cm": medida_cm,
        "l": 1.0,
        "m": m,
        "s": 0.1,
        "sd0": m,
        "distancia": 0,
    }


class TestServicioOMSNuevo(unittest.TestCase):
    def setUp(self):
        self.patcher_ref = patch.object(ServicioOMS, "obtener_referencia", side_effect=referencia_mock)
        self.patcher_clas = patch.object(ServicioOMS, "_clasificar_por_regla", side_effect=clasificacion_mock)
        self.patcher_range = patch.object(ServicioOMS, "_rango_referencia", return_value=(45.0, 120.0))
        self.patcher_ref.start()
        self.patcher_clas.start()
        self.patcher_range.start()

    def tearDown(self):
        patch.stopall()

    def evaluar(self, edad_meses, sexo, z_peso=0.0, z_talla=0.0):
        fecha_control = date(2026, 1, 1)
        year = fecha_control.year - (edad_meses // 12)
        month = fecha_control.month - (edad_meses % 12)
        while month <= 0:
            year -= 1
            month += 12
        fecha_nacimiento = date(year, month, 1)
        talla = valor_desde_z(z_talla, 100.0)
        if edad_meses <= 60:
            peso = valor_desde_z(z_peso, 10.0)
        else:
            imc = valor_desde_z(z_peso, 16.0)
            peso = imc * ((talla / 100) ** 2)
        return ServicioOMS.evaluar_paciente_integral(peso, talla, sexo, fecha_nacimiento, fecha_control)

    def test_nino_menor_2_usa_wfl(self):
        self.assertEqual(self.evaluar(12, 1)["indicador_nutricional_principal"], "WFL")

    def test_nina_menor_2_usa_wfl(self):
        res = self.evaluar(18, 2)
        self.assertEqual(res["sexo"], "F")
        self.assertEqual(res["indicador_nutricional_principal"], "WFL")

    def test_nino_2_a_5_usa_wfh(self):
        self.assertEqual(self.evaluar(36, 1)["indicador_nutricional_principal"], "WFH")

    def test_nina_2_a_5_usa_wfh(self):
        self.assertEqual(self.evaluar(60, 2)["indicador_nutricional_principal"], "WFH")

    def test_nino_mayor_5_usa_bmi(self):
        self.assertEqual(self.evaluar(72, 1)["indicador_nutricional_principal"], "BMI")

    def test_nina_mayor_5_usa_bmi(self):
        self.assertEqual(self.evaluar(120, 2)["indicador_nutricional_principal"], "BMI")

    def test_talla_baja_severa(self):
        self.assertEqual(self.evaluar(36, 1, z_talla=-3.5)["diagnostico_talla"]["id_condicion"], 124)

    def test_talla_baja(self):
        self.assertEqual(self.evaluar(36, 1, z_talla=-2.5)["diagnostico_talla"]["id_condicion"], 125)

    def test_talla_normal(self):
        self.assertEqual(self.evaluar(36, 1, z_talla=0)["diagnostico_talla"]["id_condicion"], 112)

    def test_talla_alta(self):
        self.assertEqual(self.evaluar(72, 1, z_talla=2.5)["diagnostico_talla"]["id_condicion"], 117)

    def test_emaciacion_severa(self):
        self.assertEqual(self.evaluar(12, 1, z_peso=-3.5)["diagnostico_peso"]["id_condicion"], 100)

    def test_emaciacion(self):
        self.assertEqual(self.evaluar(24, 2, z_peso=-2.5)["diagnostico_peso"]["id_condicion"], 101)

    def test_normal(self):
        self.assertEqual(self.evaluar(24, 1, z_peso=0)["diagnostico_peso"]["id_condicion"], 110)

    def test_riesgo_sobrepeso(self):
        self.assertEqual(self.evaluar(24, 1, z_peso=1.5)["diagnostico_peso"]["id_condicion"], 111)

    def test_sobrepeso(self):
        self.assertEqual(self.evaluar(24, 1, z_peso=2.5)["diagnostico_peso"]["id_condicion"], 104)

    def test_obesidad(self):
        self.assertEqual(self.evaluar(24, 1, z_peso=3.5)["diagnostico_peso"]["id_condicion"], 105)

    def test_edad_fuera_de_rango(self):
        with self.assertRaises(ValueError):
            self.evaluar(229, 1)

    def test_sexo_incorrecto(self):
        with self.assertRaises(ValueError):
            self.evaluar(12, 9)

    def test_talla_fuera_de_tabla(self):
        with patch.object(ServicioOMS, "_rango_referencia", return_value=(80.0, 120.0)):
            with self.assertRaises(ValueError):
                self.evaluar(12, 1, z_talla=-6)

    def test_misma_edad_distinta_talla_no_depende_solo_de_edad(self):
        def ref_por_talla(indicador, sexo, *, edad_meses, edad_dias, medida_cm=None):
            ref = referencia_mock(indicador, sexo, edad_meses=edad_meses, edad_dias=edad_dias, medida_cm=medida_cm)
            if indicador == "WFH":
                ref["m"] = 8.0 if medida_cm and medida_cm < 100 else 14.0
                ref["sd0"] = ref["m"]
            return ref

        with patch.object(ServicioOMS, "obtener_referencia", side_effect=ref_por_talla):
            fecha_control = date(2026, 1, 1)
            fecha_nacimiento = date(2023, 1, 1)
            bajo = ServicioOMS.evaluar_paciente_integral(10.0, 90.0, 1, fecha_nacimiento, fecha_control)
            alto = ServicioOMS.evaluar_paciente_integral(10.0, 110.0, 1, fecha_nacimiento, fecha_control)

        self.assertEqual(bajo["indicador_nutricional_principal"], "WFH")
        self.assertNotEqual(bajo["diagnostico_peso"]["diagnostico"], alto["diagnostico_peso"]["diagnostico"])

    def test_resumen_talla_baja_peso_adecuado_no_bajo_peso_por_edad(self):
        res = self.evaluar(24, 1, z_peso=0, z_talla=-2.5)
        resumen = res["resumen_clinico"].lower()

        self.assertEqual(res["indicador_nutricional_principal"], "WFH")
        self.assertEqual(res["id_condicion_nutricional_heuristica"], 110)
        self.assertIn("peso es adecuado para su talla actual", resumen)
        self.assertIn("no debe clasificarse como bajo peso solo por edad", resumen)
        self.assertIn("para 24 meses, el peso se evalua con peso para talla", resumen)


if __name__ == "__main__":
    unittest.main()
