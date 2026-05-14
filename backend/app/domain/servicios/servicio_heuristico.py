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
        mapa_etiquetas_ing = self.repo_ingrediente.obtener_mapa_etiquetas_ingrediente()
        
        for ing in todos_ingredientes:
            ing_id = int(ing["id"])
            # Bloqueo por Grupo
            if ing.get("id_grupo_alimentario") in grupos_prohibidos:
                ingredientes_prohibidos.add(ing_id)
            # Bloqueo por Subgrupo
            if ing.get("id_subgrupo_alimentario") in subgrupos_prohibidos:
                ingredientes_prohibidos.add(ing_id)
            # Bloqueo por Etiqueta
            if mapa_etiquetas_ing.get(ing_id, set()) & etiquetas_prohibidas:
                ingredientes_prohibidos.add(ing_id)

        # 3. Expansión: Ingredientes Prohibidos y Etiquetas -> Recetas
        mapa_ingredientes_rec = self.repo_ingrediente.obtener_mapa_ingredientes_receta()
        mapa_etiquetas_rec = self.repo_ingrediente.obtener_mapa_etiquetas_receta()
        
        # Primero, identificar todas las recetas en el sistema
        todas_recetas_ids = set(mapa_ingredientes_rec.keys()) | set(mapa_etiquetas_rec.keys())
        
        for receta_id in todas_recetas_ids:
            # Bloqueo por Ingrediente Prohibido
            ids_ingredientes = mapa_ingredientes_rec.get(receta_id, set())
            if any(iid in ingredientes_prohibidos for iid in ids_ingredientes):
                recetas_prohibidas.add(receta_id)
            
            # Bloqueo por Etiqueta Directa en Receta
            ids_etiquetas = mapa_etiquetas_rec.get(receta_id, set())
            if ids_etiquetas & etiquetas_prohibidas:
                recetas_prohibidas.add(receta_id)

        # 4. Obtener Preferencias (Opcional - Para visualización en Frontend)
        preferencias_receta = self.repo_ingrediente.obtener_preferencias_receta(perfil.id_paciente)

        return {
            "ingredientes_prohibidos": list(ingredientes_prohibidos),
            "recetas_prohibidas": list(recetas_prohibidas),
            "preferencias_receta": preferencias_receta,
            "recomendaciones": recomendaciones,
            "recomendaciones_etiquetas": recomendaciones_etiquetas,
            "reglas": reglas
        }

