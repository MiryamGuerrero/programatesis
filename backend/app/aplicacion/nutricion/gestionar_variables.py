from typing import List, Dict, Any
from ...domain.repositorios.interfaces import IRepositorioNutricion

class CasoUsoGestionarVariables:
    def __init__(self, repo_nutricion: IRepositorioNutricion):
        self.repo_nutricion = repo_nutricion

    def listar_variables(self, consulta: str = None, limite: int = 200) -> List[Dict[str, Any]]:
        return self.repo_nutricion.listar_variables(consulta, limite)

    def upsert_catalogo_variable(self, datos: Dict[str, Any]) -> int:
        return self.repo_nutricion.upsert_definicion_variable(datos)

    def upsert_valor(self, datos: Dict[str, Any], actualizado_por: str) -> None:
        proporcionados = [
            datos.get("valor_numerico") is not None,
            datos.get("valor_texto") is not None,
            datos.get("valor_booleano") is not None,
        ]
        if sum(proporcionados) > 1:
            raise ValueError("Solo se permite un tipo de valor (numerico/texto/booleano)")
            
        self.repo_nutricion.upsert_valor_variable(datos, actualizado_por)

    def upsert_valores_masivo(self, items: List[Dict[str, Any]], actualizado_por: str) -> Dict[str, Any]:
        exitos = 0
        errores = []
        for idx, item in enumerate(items, start=1):
            try:
                self.upsert_valor(item, actualizado_por)
                exitos += 1
            except Exception as e:
                errores.append({"indice": idx, "error": str(e)})
        return {"total": len(items), "exitos": exitos, "errores": errores}
