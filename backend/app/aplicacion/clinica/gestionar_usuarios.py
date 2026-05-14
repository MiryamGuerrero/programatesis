from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioPerfil

class CasoUsoGestionarUsuarios:
    def __init__(self, repo_perfil: IRepositorioPerfil):
        self.repo_perfil = repo_perfil

    def listar_todos(self) -> List[Dict[str, Any]]:
        return self.repo_perfil.listar_usuarios()

    def registrar_usuario(self, datos: Dict[str, Any]) -> str:
        return self.repo_perfil.crear_usuario(datos)

    def buscar_tutor_por_cedula(self, cedula: str) -> Dict[str, Any]:
        tutor = self.repo_perfil.buscar_tutor_por_cedula(cedula)
        if not tutor:
            return {"existe": False}
        return {"existe": True, "tutor": tutor}

    def registrar_tutor_solo(self, datos: Dict[str, Any]) -> str:
        return self.repo_perfil.registrar_tutor_solo(datos)
