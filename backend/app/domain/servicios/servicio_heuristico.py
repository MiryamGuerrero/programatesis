from typing import Set, Dict, List
from ..modelos.reglas import Regla, TipoAccion, TipoObjetivo
from ..modelos.paciente import PerfilPaciente
from ..repositorios.interfaces import IRepositorioIngrediente

class ServicioMotorHeuristico:
    def __init__(self, repo_ingrediente: IRepositorioIngrediente):
        self.repo_ingrediente = repo_ingrediente

    def expandir_reglas(self, perfil: PerfilPaciente) -> Dict:
        """
        Expande reglas de subgrupos y etiquetas a ingredientes y recetas.
        """
        reglas = perfil.reglas_aplicables
        
        ingredientes_prohibidos: Set[int] = set()
        subgrupos_prohibidos: Set[int] = set()
        grupos_prohibidos: Set[int] = set()
        etiquetas_prohibidas: Set[int] = set()
        recetas_prohibidas: Set[int] = set()
        
        recomendaciones: Dict[int, str] = {}
        recomendaciones_etiquetas: Dict[int, str] = {}

        # 1. Separar reglas base por objetivo
        for regla in reglas:
            if regla.accion == TipoAccion.ELIMINAR:
                if regla.tipo_objetivo == TipoObjetivo.INGREDIENTE: ingredientes_prohibidos.add(regla.id_objetivo)
                elif regla.tipo_objetivo == TipoObjetivo.SUBGRUPO: subgrupos_prohibidos.add(regla.id_objetivo)
                elif regla.tipo_objetivo == TipoObjetivo.GRUPO: grupos_prohibidos.add(regla.id_objetivo)
                elif regla.tipo_objetivo == TipoObjetivo.ETIQUETA: etiquetas_prohibidas.add(regla.id_objetivo)
                elif regla.tipo_objetivo == TipoObjetivo.RECETA: recetas_prohibidas.add(regla.id_objetivo)
            elif regla.accion in [TipoAccion.PRIORIZAR, TipoAccion.DISMINUIR]:
                if regla.tipo_objetivo == TipoObjetivo.INGREDIENTE:
                    recomendaciones[regla.id_objetivo] = regla.accion.value
                elif regla.tipo_objetivo == TipoObjetivo.ETIQUETA:
                    recomendaciones_etiquetas[regla.id_objetivo] = regla.accion.value

        # 2. Expansión: Grupos, Subgrupos y Etiquetas -> Ingredientes
        todos_ingredientes = self.repo_ingrediente.listar_todos_activos()
        mapa_etiquetas = self.repo_ingrediente.obtener_mapa_etiquetas_ingrediente()
        
        for ing in todos_ingredientes:
            ing_id = int(ing["id"])
            # Bloqueo por Grupo
            if ing.get("id_grupo_alimentario") in grupos_prohibidos:
                ingredientes_prohibidos.add(ing_id)
            # Bloqueo por Subgrupo
            if ing.get("id_subgrupo_alimentario") in subgrupos_prohibidos:
                ingredientes_prohibidos.add(ing_id)
            # Bloqueo por Etiqueta
            if mapa_etiquetas.get(ing_id, set()) & etiquetas_prohibidas:
                ingredientes_prohibidos.add(ing_id)

        # 3. Expansión: Ingredientes Prohibidos -> Recetas
        mapa_recetas = self.repo_ingrediente.obtener_mapa_ingredientes_receta()
        for receta_id, ids_ingredientes in mapa_recetas.items():
            if any(iid in ingredientes_prohibidos for iid in ids_ingredientes):
                recetas_prohibidas.add(receta_id)

        return {
            "ingredientes_prohibidos": ingredientes_prohibidos,
            "recetas_prohibidas": recetas_prohibidas,
            "recomendaciones": recomendaciones,
            "recomendaciones_etiquetas": recomendaciones_etiquetas,
            "reglas": reglas
        }
