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
        # 1. Obtener el perfil del paciente con sus condiciones activas
        perfil = self.repo_paciente.obtener_por_id(id_paciente)
        if not perfil:
            return {"error": "Paciente no encontrado", "recetas_prohibidas": [], "ingredientes_prohibidos": []}
        
        # 2. Obtener reglas de conocimiento (KBRS - Nivel 1: Seguridad/Exclusión)
        # 2.1 Reglas por condiciones (Patología, Estado Nutricional, Temporales)
        reglas_condiciones = self.repo_regla.obtener_reglas_por_condiciones(perfil.condiciones_activas)
        
        # 2.2 Reglas por alergias específicas e intolerancias (Lactosa, Gluten, etc.)
        reglas_alergias = self.repo_regla.obtener_alergias_por_paciente(id_paciente)
        
        # 3. Consolidar reglas en el perfil
        perfil.reglas_aplicables = reglas_condiciones + reglas_alergias
        
        # 4. Ejecutar Motor Heurístico de Inferencia (Nivel 1 y Nivel 2 inicial)
        # Este servicio expande subgrupos a ingredientes y detecta recetas inseguras
        resultado = self.servicio_heuristico.expandir_reglas(perfil)
        
        return resultado
