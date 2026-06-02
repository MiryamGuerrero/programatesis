"""Pruebas de contrato para la referencia OMS nueva.

Estas pruebas no sustituyen a `test_servicio_oms.py`; validan que el contrato
publico conserve las claves que consume el modulo medico.
"""

import unittest
from datetime import date
from unittest.mock import patch

from app.domain.servicios.servicio_oms import ServicioOMS
from tests.test_servicio_oms import clasificacion_mock, referencia_mock


class TestServicioOMSContrato(unittest.TestCase):
    def test_salida_conserva_claves_compatibles(self):
        with patch.object(ServicioOMS, "obtener_referencia", side_effect=referencia_mock), \
             patch.object(ServicioOMS, "_clasificar_por_regla", side_effect=clasificacion_mock), \
             patch.object(ServicioOMS, "_rango_referencia", return_value=(45.0, 120.0)):
            res = ServicioOMS.evaluar_paciente_integral(
                peso_kg=10,
                talla_cm=100,
                id_sexo=1,
                fecha_nacimiento=date(2023, 1, 1),
                fecha_control=date(2026, 1, 1),
            )

        claves = {
            "edad_dias",
            "edad_meses",
            "imc",
            "diagnostico_peso",
            "diagnostico_talla",
            "diagnostico_nutri_texto",
            "diagnostico_talla_texto",
            "diagnostico_peso_complementario",
            "diagnostico_combinado",
            "resumen_clinico",
            "peso_ideal_estimado",
            "talla_ideal",
            "estado_peso",
            "indicador_nutricional_principal",
            "z_score_principal",
            "id_condicion_nutricional_principal",
            "id_condicion_nutricional_heuristica",
            "talla_edad",
            "peso_edad",
            "bmi_edad",
        }
        self.assertTrue(claves.issubset(res.keys()))
        self.assertEqual(res["indicador_nutricional_principal"], "WFH")
        self.assertIn("no se usa como diagnostico principal", " ".join(res["advertencias"]).lower())


if __name__ == "__main__":
    unittest.main()
