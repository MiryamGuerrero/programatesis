from typing import Dict
from ...domain.repositorios.interfaces import IRepositorioPaciente, IRepositorioRegla, IRepositorioIngrediente
from ...domain.servicios.resolutor_conflictos import ServicioResolutorConflictos
from ...domain.servicios.servicio_heuristico import ServicioMotorHeuristico

class CasoUsoEvaluarReglasPaciente:
    def __init__(
        self,
        repo_paciente: IRepositorioPaciente,
        repo_regla: IRepositorioRegla,
        repo_ingrediente: IRepositorioIngrediente
    ):
        self.repo_paciente = repo_paciente
        self.repo_regla = repo_regla
        self.servicio_heuristico = ServicioMotorHeuristico(repo_ingrediente)

    def ejecutar(self, id_paciente: str) -> Dict:
        perfil = self.repo_paciente.obtener_por_id(id_paciente)
        if not perfil:
            raise ValueError(f"Paciente {id_paciente} no encontrado")

        reglas_condicion = self.repo_regla.obtener_reglas_por_condiciones(perfil.condiciones_activas)
        alergias = self.repo_regla.obtener_alergias_por_paciente(id_paciente)
        
        todas_reglas = reglas_condicion + alergias
        perfil.reglas_aplicables = ServicioResolutorConflictos.resolver(todas_reglas)

        return self.servicio_heuristico.expandir_reglas(perfil)
