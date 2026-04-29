from typing import Dict, Any
from ...infraestructura.repositorios.repositorio_clinico import RepositorioClinicoPostgres
from ...domain.servicios.servicio_oms import ServicioOMS

class CasoUsoGestionarControlClinico:
    def __init__(self, repo_clinico: RepositorioClinicoPostgres):
        self.repo_clinico = repo_clinico

    def calcular_estado_nutricional(self, peso: float, talla: float, edad_meses: int, id_sexo: int) -> Dict[str, Any]:
        """
        Realiza la evaluación nutricional completa usando el estándar OMS.
        """
        evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla, id_sexo, edad_meses)
        
        # Mantenemos compatibilidad con la estructura esperada por el frontend si es necesario,
        # pero priorizamos la nueva estructura rica en datos.
        return {
            "imc": evaluacion["imc"],
            "z_score": evaluacion["bmi_edad"]["z_score"],
            "id_condicion_nutricional": evaluacion["bmi_edad"]["id_condicion"],
            "diagnostico_nutri_texto": evaluacion["bmi_edad"]["diagnostico"],
            "diagnostico_talla_texto": evaluacion["talla_edad"]["diagnostico"],
            "z_score_talla": evaluacion["talla_edad"]["z_score"],
            "detalle_integral": evaluacion
        }
