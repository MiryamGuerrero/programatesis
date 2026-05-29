import random
from datetime import date, timedelta
from typing import List, Dict, Optional
from ...domain.repositorios.interfaces import IRepositorioReceta, IRepositorioSeguimiento, IRepositorioPaciente
from .evaluar_reglas_paciente import CasoUsoEvaluarReglasPaciente
from ...infraestructura.repositorios.repositorio_composicion import RepositorioComposicionPostgres

class CasoUsoGenerarPlanAutomatico:
    def __init__(
        self,
        repo_receta: IRepositorioReceta,
        repo_seguimiento: IRepositorioSeguimiento,
        repo_paciente: IRepositorioPaciente,
        repo_composicion: RepositorioComposicionPostgres
    ):
        self.repo_receta = repo_receta
        self.repo_seguimiento = repo_seguimiento
        self.repo_paciente = repo_paciente
        self.repo_composicion = repo_composicion

    def ejecutar(
        self, 
        id_paciente: str, 
        dias: int, 
        fecha_inicio: date,
        momentos_obligatorios: List[int],
        momentos_opcionales: List[int]
    ) -> dict:
        # 1. Obtener perfil del paciente (para condiciones)
        perfil = self.repo_paciente.obtener_por_id(id_paciente)
        if not perfil:
            raise ValueError("Paciente no encontrado")
        
        condiciones_ids = perfil.condiciones_activas
        
        # 2. Crear el plan nutricional (cabecera)
        fecha_fin = fecha_inicio + timedelta(days=dias - 1)
        id_plan = self.repo_seguimiento.crear_plan_nutricional({
            "id_paciente": id_paciente,
            "id_origen_plan": 2, # Sistema
            "id_estado_plan": 2, # Activo
            "fecha_inicio": fecha_inicio,
            "fecha_fin": fecha_fin,
            "comidas_por_dia": len(momentos_obligatorios) + len(momentos_opcionales)
        })
        
        # 3. Preparar catálogo de recetas seguras
        momentos_todos = sorted(list(set(momentos_obligatorios + momentos_opcionales)))
        recetas_seguras_cache = {}
        for m_id in momentos_todos:
            recetas_seguras_cache[m_id] = self.repo_receta.obtener_recetas_seguras_para_paciente(id_paciente, m_id)

        items_a_insertar = []
        
        # 4. Generar items día por día
        for i in range(dias):
            fecha_dia = fecha_inicio + timedelta(days=i)
            
            for m_id in momentos_todos:
                # Buscar combinaciones aplicables
                combinaciones = self.repo_composicion.obtener_combinaciones_por_condiciones(m_id, condiciones_ids)
                
                if not combinaciones:
                    # Si no hay combinaciones, buscar una receta segura al azar
                    recetas_posibles = recetas_seguras_cache.get(m_id, [])
                    if recetas_posibles:
                        receta_elegida = self._seleccionar_receta_con_prioridad(recetas_posibles)
                        items_a_insertar.append({
                            "id_plan": id_plan,
                            "fecha_programada": fecha_dia,
                            "id_momento": m_id,
                            "id_receta": receta_elegida["id"]
                        })
                    continue

                # Elegir una combinación al azar
                combinacion = random.choice(combinaciones)
                platillos = combinacion["platillos"] # List of {id: tipo_plato_id, nombre: ...}
                
                for platillo in platillos:
                    tipo_plato_id = platillo["id"]
                    # Filtrar recetas seguras por tipo de plato
                    recetas_tipo = [r for r in recetas_seguras_cache.get(m_id, []) if tipo_plato_id in (r.get("tipos_plato_ids") or [])]
                    
                    if recetas_tipo:
                        receta_elegida = self._seleccionar_receta_con_prioridad(recetas_tipo)
                        items_a_insertar.append({
                            "id_plan": id_plan,
                            "fecha_programada": fecha_dia,
                            "id_momento": m_id,
                            "id_receta": receta_elegida["id"]
                        })

        # 5. Guardar items
        if items_a_insertar:
            self.repo_seguimiento.agregar_items_plan(items_a_insertar)
            
        return {
            "id_plan": id_plan, 
            "dias_generados": dias, 
            "items_generados": len(items_a_insertar),
            "fecha_inicio": fecha_inicio.isoformat(),
            "fecha_fin": fecha_fin.isoformat()
        }

    def intercambiar_receta(self, id_plan_item: int) -> dict:
        # 1. Obtener detalle del item actual
        item_actual = self.repo_seguimiento.obtener_item_plan_con_detalle(id_plan_item)
        if not item_actual:
            raise ValueError("Item de plan no encontrado")
        
        if item_actual["id_origen_plan"] != 2:
            raise ValueError("Solo se pueden intercambiar recetas en planes generados por el sistema")
            
        id_paciente = item_actual["id_paciente"]
        id_momento = item_actual["id_momento"]
        id_receta_actual = item_actual["id_receta"]
        
        # 2. Obtener tipo de plato de la receta actual
        receta_info = self.repo_receta.obtener_receta(id_receta_actual)
        if not receta_info:
            raise ValueError("Receta actual no encontrada")
            
        tipos_actuales = receta_info.get("tipos_plato_ids") or []
        
        # 3. Buscar alternativas seguras
        recetas_seguras = self.repo_receta.obtener_recetas_seguras_para_paciente(id_paciente, id_momento)
        
        # Filtrar por tipo de plato y excluir la actual
        alternativas = [
            r for r in recetas_seguras 
            if r["id"] != id_receta_actual and any(t in (r.get("tipos_plato_ids") or []) for t in tipos_actuales)
        ]
        
        if not alternativas:
            # Si no hay del mismo tipo, intentar cualquier otra segura para el momento
            alternativas = [r for r in recetas_seguras if r["id"] != id_receta_actual]
            
        if not alternativas:
            raise ValueError("No se encontraron recetas alternativas seguras")
            
        # 4. Elegir una y actualizar
        nueva_receta = self._seleccionar_receta_con_prioridad(alternativas)
        self.repo_seguimiento.intercambiar_receta_item(id_plan_item, nueva_receta["id"])
        
        return {
            "id_plan_item": id_plan_item, 
            "nueva_receta": {
                "id": nueva_receta["id"],
                "nombre": nueva_receta["nombre"],
                "imagen_url": nueva_receta.get("imagen_url")
            }
        }

    def _seleccionar_receta_con_prioridad(self, recetas: List[dict]) -> dict:
        # Pesos base
        pesos = []
        for r in recetas:
            peso = 1.0
            if r.get("es_preferida"): peso *= 2.0
            if r.get("es_potenciada") or r.get("es_recomendada"): peso *= 1.5
            if r.get("es_disminuida"): peso *= 0.5
            pesos.append(peso)
            
        return random.choices(recetas, weights=pesos, k=1)[0]
