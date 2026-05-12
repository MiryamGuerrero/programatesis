from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioIngrediente

class CasoUsoGestionarIngredientes:
    def __init__(self, repo_ingrediente: IRepositorioIngrediente):
        self.repo_ingrediente = repo_ingrediente

    def listar_ingredientes(self, consulta: str = None, limite: int = 100, desplazamientoo: int = 0, incluir_inactivos: bool = False, id_grupo: int = None, id_subgrupo: int = None) -> List[Dict[str, Any]]:
        return self.repo_ingrediente.listar_ingredientes_admin(consulta, limite, desplazamientoo, incluir_inactivos, id_grupo, id_subgrupo)

    def buscar_para_paciente(self, id_paciente: str, consulta: str = None, limite: int = 50) -> List[Dict[str, Any]]:
        return self.repo_ingrediente.buscar_ingredientes_filtrados(id_paciente, consulta, limite)

    def crear_ingrediente(self, datos: Dict[str, Any]) -> int:
        id_grupo = self.repo_ingrediente.resolver_id_grupo(
            datos.get("id_grupo_alimentario"), 
            datos.get("grupo_nombre")
        )
        id_subgrupo = self.repo_ingrediente.resolver_id_subgrupo(
            id_grupo,
            datos.get("id_subgrupo_alimentario"),
            datos.get("subgrupo_nombre")
        )

        datos_para_repo = datos.copy()
        datos_para_repo["id_grupo_alimentario"] = id_grupo
        datos_para_repo["id_subgrupo_alimentario"] = id_subgrupo
        datos_para_repo["activo"] = True
        
        # Eliminar campos auxiliares
        datos_para_repo.pop("grupo_nombre", None)
        datos_para_repo.pop("subgrupo_nombre", None)
        
        datos_limpios = {k: v for k, v in datos_para_repo.items() if v is not None}
        return self.repo_ingrediente.crear_ingrediente(datos_limpios)

    def actualizar_ingrediente(self, id_ingrediente: int, datos: Dict[str, Any]) -> bool:
        # Resolver IDs si vienen nombres
        id_grupo = self.repo_ingrediente.resolver_id_grupo(
            datos.get("id_grupo_alimentario"), 
            datos.get("grupo_nombre")
        )
        id_subgrupo = self.repo_ingrediente.resolver_id_subgrupo(
            id_grupo,
            datos.get("id_subgrupo_alimentario"),
            datos.get("subgrupo_nombre")
        )

        datos_para_repo = datos.copy()
        if id_grupo: datos_para_repo["id_grupo_alimentario"] = id_grupo
        if id_subgrupo: datos_para_repo["id_subgrupo_alimentario"] = id_subgrupo
        
        # Eliminar campos auxiliares
        datos_para_repo.pop("grupo_nombre", None)
        datos_para_repo.pop("subgrupo_nombre", None)

        datos_limpios = {k: v for k, v in datos_para_repo.items() if v is not None}
        return self.repo_ingrediente.actualizar_ingrediente(id_ingrediente, datos_limpios)

    def eliminar_ingrediente(self, id_ingrediente: int) -> bool:
        return self.repo_ingrediente.eliminar_ingrediente(id_ingrediente)
