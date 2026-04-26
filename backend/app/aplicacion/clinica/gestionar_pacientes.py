from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioPaciente

class CasoUsoGestionarPacientes:
    def __init__(self, repo_paciente: IRepositorioPaciente):
        self.repo_paciente = repo_paciente

    def buscar(self, consulta: str, limite: int = 50) -> List[Dict[str, Any]]:
        return self.repo_paciente.buscar_pacientes(consulta, limite)

    def registrar_nuevo_paciente(self, datos: Dict[str, Any]) -> str:
        if not datos.get("nombre") or not datos.get("fecha_nacimiento"):
            raise ValueError("Datos incompletos para el registro")
        return self.repo_paciente.registrar_paciente_completo(datos)

    def eliminar(self, id_paciente: str) -> bool:
        return self.repo_paciente.eliminar_paciente_integral(id_paciente)
