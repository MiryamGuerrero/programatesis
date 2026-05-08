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
        # Usamos la nueva función optimizada de base de datos
        with db_cursor() as cur:
            cur.execute("SELECT heuristico.evaluar_reglas_completas_paciente(%s)", (id_paciente,))
            resultado = cur.fetchone()[0]
        
        # Obtenemos las reglas originales para trazabilidad (opcional)
        perfil = self.repo_paciente.obtener_por_id(id_paciente)
        if perfil:
            todas_reglas = self.repo_regla.obtener_reglas_por_condiciones(perfil.condiciones_activas)
            resultado['reglas'] = todas_reglas

        return resultado
