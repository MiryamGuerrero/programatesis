from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioIngrediente

class CasoUsoGestionarIngredientes:
    def __init__(self, repo_ingrediente: IRepositorioIngrediente):
        self.repo_ingrediente = repo_ingrediente

    def listar_ingredientes(self, consulta: str = None, limite: int = 100, desplazamientoo: int = 0, incluir_inactivos: bool = False) -> List[Dict[str, Any]]:
        return self.repo_ingrediente.listar_ingredientes_admin(consulta, limite, desplazamientoo, incluir_inactivos)

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

        datos_ingrediente = {
            "nombre": datos["nombre"],
            "id_grupo_alimentario": id_grupo,
            "id_subgrupo_alimentario": id_subgrupo,
            "activo": True
        }
        
        datos_limpios = {k: v for k, v in datos_ingrediente.items() if v is not None}
        return self.repo_ingrediente.crear_ingrediente(datos_limpios)

    def recomendar_ingrediente(self, id_paciente: str, id_ingrediente: int, id_profesional: str, id_rol: int, motivo: str = None, prioridad: int = 1) -> bool:
        # Validar que no sea un ingrediente prohibido (alergia)
        permitidos = self.repo_ingrediente.buscar_ingredientes_filtrados(id_paciente, limite=1000)
        permitidos_ids = {p["id"] for p in permitidos}
        
        if id_ingrediente not in permitidos_ids:
            raise ValueError("No se puede recomendar un ingrediente que es alérgico o prohibido para el paciente")

        return self.repo_ingrediente.registrar_recomendacion(id_paciente, id_ingrediente, id_profesional, id_rol, motivo, prioridad)

    def eliminar_recomendacion(self, id_paciente: str, id_ingrediente: int) -> bool:
        return self.repo_ingrediente.eliminar_recomendacion(id_paciente, id_ingrediente)

    def listar_recomendaciones(self, id_paciente: str) -> List[Dict[str, Any]]:
        return self.repo_ingrediente.listar_recomendaciones_paciente(id_paciente)
