from typing import List, Optional
from ...core.db import db_cursor
from ...domain.modelos.clinico import ClinicalDiagnosis

class RepositorioClinicoPostgres:
    def obtener_datos_referencia_oms(self, id_sexo: int, edad_meses: int, indicador: str = "IMC_EDAD"):
        with db_cursor() as cur:
            sql = """
                select l, m, s, id_condicion_nutricional, diagnostico_texto
                from referencia.oms_curva
                where id_sexo = %s and edad_meses = %s and indicador_codigo = %s
                limit 1
            """
            cur.execute(sql, (id_sexo, edad_meses, indicador))
            row = cur.fetchone()
            if not row: return None
            return {
                "l": float(row[0]), "m": float(row[1]), "s": float(row[2]),
                "id_condicion": row[3], "diagnostico": row[4]
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
