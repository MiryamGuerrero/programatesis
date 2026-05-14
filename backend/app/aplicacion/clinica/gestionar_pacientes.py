from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioPaciente

class CasoUsoGestionarPacientes:
    def __init__(self, repo_paciente: IRepositorioPaciente):
        self.repo_paciente = repo_paciente

    def buscar(self, consulta: str, limite: int = 50) -> List[Dict[str, Any]]:
        return self.repo_paciente.buscar_pacientes(consulta, limite)

    def listar_todos(self) -> List[Dict[str, Any]]:
        return self.repo_paciente.listar_todos_pacientes()

    def obtener_resumen_evolucion(self, id_paciente: str) -> List[Dict[str, Any]]:
        return self.repo_paciente.obtener_resumen_evolucion(id_paciente)

    def obtener_expediente_completo(self, id_paciente: str) -> Dict[str, Any]:
        return self.repo_paciente.obtener_expediente_completo(id_paciente)

    def registrar_nuevo_paciente(
        self,
        datos: Dict[str, Any],
        id_usuario_creador: str | None = None,
    ) -> dict:
        return self.repo_paciente.registrar_paciente_integral(datos, id_usuario_creador)

    def actualizar_expediente(self, id_paciente: str, datos: Dict[str, Any]) -> bool:
        return self.repo_paciente.actualizar_paciente_integral(id_paciente, datos)

    def registrar_control_mensual(
        self,
        id_paciente: str,
        datos: Dict[str, Any],
        id_medico: str,
    ) -> int:
        return self.repo_paciente.registrar_control_mensual(id_paciente, datos, id_medico)

    def actualizar_control_mensual(self, id_control: int, datos: Dict[str, Any]) -> bool:
        return self.repo_paciente.actualizar_control_mensual_especifico(id_control, datos)

    def eliminar(self, id_paciente: str) -> bool:
        return self.repo_paciente.eliminar_paciente_integral(id_paciente)
