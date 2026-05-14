import math
import unittest
from datetime import date, timedelta
import sys
import os

# Add backend to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.domain.servicios.servicio_oms import ServicioOMS
from app.core.db import db_cursor

def valor_desde_z(z, l, m, s):
    if l == 0:
        return m * math.exp(s * z)
    return m * ((1 + l * s * z) ** (1 / l))

def fecha_nacimiento_desde_meses(edad_meses, fecha_control):
    # Aproximación de días por mes
    return fecha_control - timedelta(days=int(edad_meses * 30.4375))

def estado_peso_esperado(z_bmi):
    if z_bmi > 1:
        return "disminuir"
    elif z_bmi < -2:
        return "aumentar"
    else:
        return "mantener"

EDADES_MESES_MINIMAS = [
    0, 1, 2, 3, 4, 5, 6,
    11, 12, 13,
    23, 24, 25,
    35, 36,
    47, 48,
    59, 60, 61,
    71, 72,
    119, 120, 121,
    143, 144,
    179, 180,
    227, 228
]

SEXOS = [
    {"id_sexo": 1, "codigo": "M"},
    {"id_sexo": 2, "codigo": "F"}
]

Z_BMI_OBJETIVO = [-3.5, -3.0, -2.5, -2.0, -1.5, -1.0, 0.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]
Z_HFA_OBJETIVO = [-3.5, -3.0, -2.5, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 3.5]

class TestServicioOMSExhaustivo(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        # Preload LMS parameters to speed up synthetic patient generation
        cls.lms_cache = {}
        with db_cursor() as cur:
            cur.execute("SELECT indicador_codigo, sexo_codigo, edad_dias, edad_meses, l, m, s FROM referencia.oms_curva_punto")
            for ind, sexo, dias, meses, l, m, s in cur.fetchall():
                mes_val = meses if meses is not None else (dias // 30 if dias is not None else 0)
                dia_val = dias if dias is not None else (meses * 30 if meses is not None else 0)
                
                key = (ind, sexo, mes_val if mes_val > 60 else dia_val)
                cls.lms_cache[key] = (float(l), float(m), float(s))
                
                if mes_val <= 60:
                    key_meses = (ind, sexo, mes_val, 'mes')
                    if key_meses not in cls.lms_cache:
                        cls.lms_cache[key_meses] = (float(l), float(m), float(s))

    def get_lms(self, indicador, sexo_codigo, edad_meses, edad_dias):
        if edad_meses > 60:
            return self.lms_cache.get((indicador, sexo_codigo, edad_meses))
        else:
            res = self.lms_cache.get((indicador, sexo_codigo, edad_dias))
            if not res:
                res = self.lms_cache.get((indicador, sexo_codigo, edad_meses, 'mes'))
            return res

    def crear_paciente_sintetico(self, edad_meses, sexo_codigo, z_bmi, z_hfa):
        fecha_control = date(2024, 1, 1)
        fecha_nacimiento = fecha_nacimiento_desde_meses(edad_meses, fecha_control)
        edad_dias = (fecha_control - fecha_nacimiento).days
        
        hfa_lms = self.get_lms('HFA', sexo_codigo, edad_meses, edad_dias)
        if not hfa_lms: return None
        
        talla_cm = valor_desde_z(z_hfa, *hfa_lms)
        
        bmi_lms = self.get_lms('BMI', sexo_codigo, edad_meses, edad_dias)
        if not bmi_lms: return None
            
        imc = valor_desde_z(z_bmi, *bmi_lms)
        peso_kg = imc * ((talla_cm / 100) ** 2)
        
        return {
            "fecha_nacimiento": fecha_nacimiento,
            "fecha_control": fecha_control,
            "talla_cm": talla_cm,
            "peso_kg": peso_kg,
            "edad_dias": edad_dias,
            "edad_meses": edad_meses
        }

    def test_errores_basicos(self):
        with self.assertRaises(ValueError):
            ServicioOMS.evaluar_paciente_integral(0, 100, 1, "2020-01-01", "2026-05-13")
        with self.assertRaises(ValueError):
            ServicioOMS.evaluar_paciente_integral(20, 0, 1, "2020-01-01", "2026-05-13")
        with self.assertRaises(ValueError):
            ServicioOMS.evaluar_paciente_integral(20, 100, 3, "2020-01-01", "2026-05-13")
        with self.assertRaises(ValueError):
            ServicioOMS.evaluar_paciente_integral(20, 100, 1, "2027-01-01", "2026-05-13")
        with self.assertRaises(ValueError):
            ServicioOMS.evaluar_paciente_integral(20, 100, 1, "2022-01-01", "2021-01-01")
        with self.assertRaises(ValueError):
            ServicioOMS.evaluar_paciente_integral(70, 170, 1, "2000-05-13", "2026-05-13")

    def run_matrix(self, edades):
        fallas = []
        PROHIBIDAS_MANTENER = [
            "debe aumentar", "debe disminuir", "bajar de peso", "subir de peso",
            "perder peso", "ganar peso", "aumentar kg", "disminuir kg",
            "aumentar ", "disminuir "
        ]
        PROHIBIDAS_SIEMPRE = [
            "debe crecer", "crecer para alcanzar", "crecer x", "para alcanzar el rango normal"
        ]

        casos_probados = 0
        for edad_meses in edades:
            print(f"Probando edad: {edad_meses} meses...")
            for sexo in SEXOS:
                for z_bmi in Z_BMI_OBJETIVO:
                    for z_hfa in Z_HFA_OBJETIVO:
                        caso = self.crear_paciente_sintetico(edad_meses, sexo["codigo"], z_bmi, z_hfa)
                        if not caso: continue
                        
                        try:
                            # Use exact days/months as calculated internally by OMS to ensure matching
                            fecha_nacimiento = caso["fecha_nacimiento"]
                            fecha_control = caso["fecha_control"]
                            edad_meses_real = ServicioOMS.calcular_edad_meses(fecha_nacimiento, fecha_control)
                            
                            resultado = ServicioOMS.evaluar_paciente_integral(
                                peso_kg=caso["peso_kg"],
                                talla_cm=caso["talla_cm"],
                                id_sexo=sexo["id_sexo"],
                                fecha_nacimiento=fecha_nacimiento,
                                fecha_control=fecha_control,
                            )
                            
                            casos_probados += 1

                            self.assertEqual(resultado["indicador_nutricional_principal"], "BMI", "indicador_nutricional_principal != BMI")
                            self.assertEqual(resultado["diagnostico_nutri_texto"], resultado["bmi_edad"]["diagnostico"])
                            self.assertEqual(resultado["estado_peso"], estado_peso_esperado(z_bmi), "estado_peso incorrecto")
                            
                            imc_mediano = resultado["bmi_edad"]["ideal"]
                            peso_ideal_esperado = round(imc_mediano * ((caso["talla_cm"] / 100) ** 2), 2)
                            self.assertAlmostEqual(resultado["peso_ideal_estimado"], peso_ideal_esperado, delta=0.02)
                            
                            texto = resultado["resumen_clinico"].lower()
                            if resultado["estado_peso"] == "mantener":
                                for frase in PROHIBIDAS_MANTENER:
                                    self.assertNotIn(frase, texto, f"Frase prohibida en mantener: {frase}")
                            
                            for frase in PROHIBIDAS_SIEMPRE:
                                self.assertNotIn(frase, texto, f"Frase prohibida siempre: {frase}")
                                
                            if edad_meses_real <= 120 and resultado["peso_edad"]["z_score"] is not None:
                                self.assertEqual(resultado["diagnostico_peso_complementario"], resultado["peso_edad"]["diagnostico"])
                                
                            if edad_meses_real > 120:
                                self.assertIsNone(resultado["peso_edad"]["z_score"], "z_score no es None en WFA > 120")
                                self.assertIn("sin referencia", resultado["peso_edad"]["diagnostico"].lower(), "diagnostico no dice sin referencia")
                                
                            if edad_meses_real <= 60:
                                self.assertIn("advertencias", resultado)
                                advs = "".join(resultado["advertencias"]).lower()
                                self.assertTrue("peso para talla" in advs or "peso para longitud" in advs, "Falta advertencia WFL")
                            else:
                                advs = "".join(resultado.get("advertencias", [])).lower()
                                self.assertFalse("peso para talla" in advs or "peso para longitud" in advs, "Advertencia WFL en mayor de 5 años")

                        except AssertionError as e:
                            fallas.append({
                                "edad": edad_meses_real,
                                "sexo": sexo["codigo"],
                                "z_bmi": z_bmi,
                                "z_hfa": z_hfa,
                                "error": str(e),
                            })
                            
        if fallas:
            print(f"\\n--- SE ENCONTRARON {len(fallas)} FALLAS ---")
            for f in fallas[:10]:
                print(f)
        self.assertEqual(len(fallas), 0, f"Fallas: {len(fallas)}")
        print(f"\\nCasos probados exitosamente: {casos_probados}")

    def test_matriz_minima_obligatoria(self):
        print("\\nEjecutando matriz mínima obligatoria...")
        self.run_matrix(EDADES_MESES_MINIMAS)

    # Comentado para evitar el timeout de 5 minutos en el pipeline automatizado.
    # El usuario puede descomentar esto localmente para la prueba exhaustiva.
    # def test_matriz_exhaustiva_completa(self):
    #     print("\\nEjecutando matriz exhaustiva completa (0 a 228 meses)...")
    #     self.run_matrix(list(range(0, 229)))

if __name__ == '__main__':
    unittest.main()
