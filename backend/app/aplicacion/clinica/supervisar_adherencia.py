from typing import List, Dict
from ...domain.repositorios.interfaces import IRepositorioSeguimiento

class CasoUsoSupervisarAdherenciaPacientes:
    def __init__(self, repo_seguimiento: IRepositorioSeguimiento):
        self.repo_seguimiento = repo_seguimiento

    def ejecutar(self, id_medico: str) -> List[Dict]:
        """Obtiene la adherencia de todos los pacientes de un médico."""
        return self.repo_seguimiento.obtener_reporte_adherencia_medico(id_medico)
