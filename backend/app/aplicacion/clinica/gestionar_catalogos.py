from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioPerfil
from ...domain.servicios.restricciones_alimentarias import catalogo_restricciones

class CasoUsoGestionarCatalogos:
    def __init__(self, repo_perfil: IRepositorioPerfil):
        self.repo_perfil = repo_perfil

    def obtener_maestro(self, esquema: str, tabla: str) -> List[Dict[str, Any]]:
        return self.repo_perfil.obtener_catalogo(esquema, tabla)

    def obtener_catalogos_registro_paciente(self) -> Dict[str, List[Dict[str, Any]]]:
        condiciones = self.repo_perfil.obtener_catalogo("heuristico", "condicion")
        return {
            "parentescos": self.repo_perfil.obtener_catalogo("usuarios", "parentesco"),
            "sexos": self.repo_perfil.obtener_catalogo("usuarios", "catalogo_sexo"),
            "patologias": [
                c for c in condiciones
                if (c.get("id_tipo") or c.get("id_tipo_condicion")) == 1
            ],
            "condiciones_temporales": [
                c for c in condiciones
                if (c.get("id_tipo") or c.get("id_tipo_condicion")) == 2
            ],
            "ingredientes": self.repo_perfil.obtener_catalogo("nutricion", "ingrediente"),
            "cantones": self.repo_perfil.obtener_catalogo("usuarios", "canton"),
            "parroquias": self.repo_perfil.obtener_catalogo("usuarios", "parroquia"),
            "subgrupos": self.repo_perfil.obtener_catalogo("nutricion", "subgrupo_alimentario"),
            "restricciones_alimentarias": catalogo_restricciones(),
        }
