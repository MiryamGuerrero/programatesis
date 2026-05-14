import unittest
from unittest.mock import patch, MagicMock
from datetime import date
import sys
import os

# Add backend to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.domain.servicios.servicio_oms import ServicioOMS

class TestServicioOMS(unittest.TestCase):

    def setUp(self):
        self.fecha_nacimiento = date(2022, 1, 1)
        self.fecha_control = date(2024, 1, 1) # 24 meses
        self.id_sexo = 1 # M

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_a_imc_normal_wfa_bajo(self, mock_eval):
        # Caso A: menor de 5 años con IMC normal y WFA bajo
        # Simulamos retornos de indicadores
        mock_eval.side_effect = [
            {"z_score": 0.0, "diagnostico": "Normal", "id_clasificacion": 110, "ideal": 16.0}, # BMI
            {"z_score": 0.0, "diagnostico": "Talla normal", "id_clasificacion": 112, "ideal": 87.0}, # HFA
            {"z_score": -2.5, "diagnostico": "Bajo peso", "id_clasificacion": 101, "ideal": 12.0}, # WFA
        ]

        res = ServicioOMS.evaluar_paciente_integral(12.0, 87.0, self.id_sexo, self.fecha_nacimiento, self.fecha_control)

        self.assertEqual(res["estado_p_eso" if "estado_p_eso" in res else "estado_peso"], "mantener")
        self.assertEqual(res["indicador_nutricional_principal"], "BMI")
        self.assertIn("normal", res["diagnostico_nutri_texto"].lower())
        self.assertIn("Bajo peso", res["diagnostico_peso_complementario"])
        self.assertNotIn("debe aumentar", res["resumen_clinico"].lower())
        self.assertNotIn("debe disminuir", res["resumen_clinico"].lower())

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_b_talla_baja_peso_adecuado_talla(self, mock_eval):
        # Caso B: menor de 5 años con talla baja y peso adecuado para talla actual
        mock_eval.side_effect = [
            {"z_score": -0.5, "diagnostico": "Normal", "id_clasificacion": 110, "ideal": 16.0}, # BMI
            {"z_score": -2.5, "diagnostico": "Talla baja", "id_clasificacion": 117, "ideal": 87.0}, # HFA
            {"z_score": -2.5, "diagnostico": "Bajo peso", "id_clasificacion": 101, "ideal": 12.0}, # WFA
        ]

        # Peso actual 10kg, talla 80cm. IMC = 15.6 (Normal)
        res = ServicioOMS.evaluar_paciente_integral(10.0, 80.0, self.id_sexo, self.fecha_nacimiento, self.fecha_control)

        self.assertEqual(res["estado_peso"], "mantener")
        self.assertIn("adecuado para la talla actual", res["resumen_clinico"])
        self.assertIn("talla baja", res["resumen_clinico"].lower())
        self.assertNotIn("debe aumentar", res["resumen_clinico"].lower())

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_c_z_bmi_bajo(self, mock_eval):
        # Caso C: z_bmi < -2
        mock_eval.side_effect = [
            {"z_score": -2.5, "diagnostico": "Delgadez", "id_clasificacion": 104, "ideal": 16.0}, # BMI
            {"z_score": 0.0, "diagnostico": "Talla normal", "id_clasificacion": 112, "ideal": 87.0}, # HFA
            {"z_score": -2.5, "diagnostico": "Bajo peso", "id_clasificacion": 101, "ideal": 12.0}, # WFA
        ]

        res = ServicioOMS.evaluar_paciente_integral(9.0, 87.0, self.id_sexo, self.fecha_nacimiento, self.fecha_control)

        self.assertEqual(res["estado_peso"], "aumentar")
        # Peso ideal = 16.0 * (0.87^2) = 12.11
        self.assertAlmostEqual(res["peso_ideal_estimado"], 12.11, places=2)
        self.assertIn("recuperación ponderal", res["resumen_clinico"])

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_d_z_bmi_alto(self, mock_eval):
        # Caso D: z_bmi > +1
        mock_eval.side_effect = [
            {"z_score": 1.5, "diagnostico": "Sobrepeso", "id_clasificacion": 118, "ideal": 16.0}, # BMI
            {"z_score": 0.0, "diagnostico": "Talla normal", "id_clasificacion": 112, "ideal": 87.0}, # HFA
            {"z_score": 1.5, "diagnostico": "Peso elevado", "id_clasificacion": 118, "ideal": 12.0}, # WFA
        ]

        res = ServicioOMS.evaluar_paciente_integral(15.0, 87.0, self.id_sexo, self.fecha_nacimiento, self.fecha_control)

        self.assertEqual(res["estado_peso"], "disminuir")
        self.assertIn("exceso ponderal", res["resumen_clinico"])

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_e_mayor_10_anios(self, mock_eval):
        # Caso E: paciente mayor de 10 años
        fecha_nac = date(2010, 1, 1)
        fecha_ctrl = date(2021, 1, 1) # 132 meses (> 10 años)
        
        mock_eval.side_effect = [
            {"z_score": 0.0, "diagnostico": "Normal", "id_clasificacion": 110, "ideal": 18.0}, # BMI
            {"z_score": 0.0, "diagnostico": "Talla normal", "id_clasificacion": 112, "ideal": 150.0}, # HFA
            {"z_score": None, "diagnostico": "Sin referencia", "id_clasificacion": None, "ideal": 0.0}, # WFA
        ]

        res = ServicioOMS.evaluar_paciente_integral(45.0, 150.0, self.id_sexo, fecha_nac, fecha_ctrl)

        self.assertEqual(res["estado_peso"], "mantener")
        self.assertIsNone(res["peso_edad"]["z_score"])
        self.assertIn("Peso para la edad no disponible", res["resumen_clinico"])

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_f_bmi_faltante(self, mock_eval):
        # Caso F: referencia BMI faltante
        mock_eval.side_effect = [
            {"z_score": None, "diagnostico": "Sin referencia", "id_clasificacion": None, "ideal": 0.0}, # BMI
            {"z_score": 0.0, "diagnostico": "Talla normal", "id_clasificacion": 112, "ideal": 87.0}, # HFA
            {"z_score": 0.0, "diagnostico": "Peso normal", "id_clasificacion": 110, "ideal": 12.0}, # WFA
        ]

        res = ServicioOMS.evaluar_paciente_integral(12.0, 87.0, self.id_sexo, self.fecha_nacimiento, self.fecha_control)

        self.assertEqual(res["estado_peso"], "sin_referencia")
        self.assertIn("Sin referencia OMS para determinar el diagnóstico nutricional principal", res["resumen_clinico"])

    @patch('app.domain.servicios.servicio_oms.ServicioOMS.evaluar_indicador')
    def test_caso_g_talla_baja_bmi_normal(self, mock_eval):
        # Caso G: talla baja con BMI normal
        mock_eval.side_effect = [
            {"z_score": 0.0, "diagnostico": "Normal", "id_clasificacion": 110, "ideal": 16.0}, # BMI
            {"z_score": -2.5, "diagnostico": "Talla baja", "id_clasificacion": 117, "ideal": 87.0}, # HFA
            {"z_score": -2.5, "diagnostico": "Bajo peso", "id_clasificacion": 101, "ideal": 12.0}, # WFA
        ]

        res = ServicioOMS.evaluar_paciente_integral(10.0, 80.0, self.id_sexo, self.fecha_nacimiento, self.fecha_control)

        self.assertEqual(res["estado_peso"], "mantener")
        self.assertIn("Normal", res["diagnostico_nutri_texto"])
        self.assertIn("Talla baja", res["diagnostico_talla_texto"])
        self.assertNotIn("aumentar", res["resumen_clinico"].lower())

if __name__ == '__main__':
    unittest.main()
