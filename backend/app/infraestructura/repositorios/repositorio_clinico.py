from typing import List, Optional
from ...core.db import db_cursor
from ...domain.modelos.clinico import ClinicalDiagnosis
from ...domain.servicios.servicio_oms import ServicioOMS

class RepositorioClinicoPostgres:
    def obtener_datos_referencia_oms(self, id_sexo: int, edad_meses: int, indicador: str = "IMC_EDAD"):
        sexo = ServicioOMS.normalizar_sexo(id_sexo)
        ref_code = {"IMC_EDAD": "BMI", "BMI_EDAD": "BMI", "TALLA_EDAD": "HFA"}.get(str(indicador), str(indicador))
        referencia = ServicioOMS.obtener_referencia(
            ref_code,
            sexo,
            edad_meses=edad_meses,
            edad_dias=int(edad_meses * 30.4375),
        )
        if not referencia:
            return None
        return {
            "l": referencia["l"],
            "m": referencia["m"],
            "s": referencia["s"],
            "id_condicion": None,
            "diagnostico": None,
        }

    def guardar_control_clinico(self, diagnostico: ClinicalDiagnosis) -> int:
        with db_cursor() as cur:
            sql = """
                insert into clinico.control_paciente (
                    id_paciente, peso_kg, talla_cm, imc_calculado,
                    id_condicion_nutricional_resultado, diagnostico_oms_texto,
                    edad_meses, fecha_control
                ) values (%s, %s, %s, %s, %s, %s, %s, now())
                returning id
            """
            cur.execute(sql, (
                diagnostico.id_paciente, diagnostico.peso_kg, diagnostico.talla_cm,
                diagnostico.imc, diagnostico.id_condicion_nutricional,
                diagnostico.diagnostico_oms, diagnostico.edad_meses
            ))
            return cur.fetchone()[0]
