from typing import Dict, Any
from ...infraestructura.repositorios.repositorio_clinico import RepositorioClinicoPostgres
from ...domain.servicios.servicio_oms import ServicioOMS

class CasoUsoGestionarControlClinico:
    def __init__(self, repo_clinico: RepositorioClinicoPostgres):
        self.repo_clinico = repo_clinico

    def calcular_estado_nutricional(self, peso: float, talla: float, id_sexo: int, fecha_nacimiento: Any, fecha_control: Any = None) -> Dict[str, Any]:
        """
        Realiza la evaluación nutricional completa usando el estándar OMS.
        """
        evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla, id_sexo, fecha_nacimiento, fecha_control)
        
        return {
            "imc": evaluacion["imc"],
            "z_score": evaluacion["z_score_principal"],
            "id_condicion_nutricional": evaluacion["id_condicion_nutricional_principal"],
            "diagnostico_nutri_texto": evaluacion["diagnostico_nutri_texto"],
            "diagnostico_talla_texto": evaluacion["talla_edad"]["diagnostico"],
            "z_score_talla": evaluacion["talla_edad"]["z_score"],
            "detalle_integral": evaluacion
        }
