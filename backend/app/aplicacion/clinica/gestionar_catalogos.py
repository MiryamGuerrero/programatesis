from typing import List, Dict, Any
from ...infraestructura.repositorios.repositorio_perfil import RepositorioPerfilPostgres

class CasoUsoGestionarCatalogos:
    def __init__(self, repo_perfil: RepositorioPerfilPostgres):
        self.repo_perfil = repo_perfil

    def obtener_maestro(self, esquema: str, tabla: str) -> List[Dict[str, Any]]:
        return self.repo_perfil.obtener_catalogo(esquema, tabla)
