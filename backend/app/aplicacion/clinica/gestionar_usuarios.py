from typing import List, Dict, Any
from ...infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres

class CasoUsoGestionarUsuarios:
    def __init__(self, repo_perfil: RepositorioPerfilPostgres):
        self.repo_perfil = repo_perfil

    def listar_todos(self) -> List[Dict[str, Any]]:
        return self.repo_perfil.listar_usuarios()

    def registrar_usuario(self, datos: Dict[str, Any]) -> str:
        return self.repo_perfil.crear_usuario(datos)
