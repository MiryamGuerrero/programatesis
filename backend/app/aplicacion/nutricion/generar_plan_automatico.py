import random
from datetime import date, timedelta
from typing import List, Dict, Optional
from ...domain.repositorios.interfaces import (
    IRepositorioComposicion,
    IRepositorioPaciente,
    IRepositorioReceta,
    IRepositorioSeguimiento,
)
from .evaluar_reglas_paciente import CasoUsoEvaluarReglasPaciente

from ...domain.modelos.plan_nutricional import PlanSemanal, DiaPlan, ItemPlan

class CasoUsoGenerarPlanAutomatico:
    def __init__(
        self,
        repo_receta: IRepositorioReceta,
        repo_seguimiento: IRepositorioSeguimiento,
        repo_paciente: IRepositorioPaciente,
        repo_composicion: IRepositorioComposicion
    ):
        self.repo_receta = repo_receta
        self.repo_seguimiento = repo_seguimiento
        self.repo_paciente = repo_paciente
        self.repo_composicion = repo_composicion

    def ejecutar_tutor(
        self, 
        id_paciente: str, 
        dias: int, 
        fecha_inicio: date,
        momentos_obligatorios: List[int],
        momentos_opcionales: List[int]
    ) -> dict:
        # 1. Generar la estructura del plan en memoria usando la misma lógica
        plan_semanal = self.generar_plan_objeto(
            id_paciente=id_paciente,
            fecha_inicio=fecha_inicio,
            dias=dias,
            momentos_ids=sorted(list(set(momentos_obligatorios + momentos_opcionales)))
        )
        
        # 2. Crear el plan nutricional (cabecera) en la BD
        id_plan = self.repo_seguimiento.crear_plan_nutricional({
            "id_paciente": id_paciente,
            "id_origen_plan": 2, # Sistema
            "id_estado_plan": 2, # Activo
            "fecha_inicio": fecha_inicio,
            "fecha_fin": plan_semanal.dias[-1].fecha,
            "comidas_por_dia": len(momentos_obligatorios) + len(momentos_opcionales)
        })

        # 3. Preparar items para insertar
        items_a_insertar = []
        for dia in plan_semanal.dias:
            for comida in dia.comidas:
                items_a_insertar.append({
                    "id_plan": id_plan,
                    "fecha_programada": dia.fecha,
                    "id_momento": comida.id_momento,
                    "id_receta": comida.id_receta,
                    "semaforo": comida.semaforo
                })

        # 4. Guardar items
        if items_a_insertar:
            self.repo_seguimiento.agregar_items_plan(items_a_insertar)
            
        return {
            "id_plan": id_plan, 
            "dias_generados": dias, 
            "items_generated": len(items_a_insertar),
            "fecha_inicio": fecha_inicio.isoformat(),
            "fecha_fin": plan_semanal.dias[-1].fecha.isoformat()
        }

    def generar_plan_objeto(
        self,
        id_paciente: str,
        fecha_inicio: date,
        dias: int,
        momentos_ids: List[int]
    ) -> PlanSemanal:
        # 1. Obtener perfil del paciente (para condiciones)
        perfil = self.repo_paciente.obtener_por_id(id_paciente)
        if not perfil:
            raise ValueError("Paciente no encontrado")
        
        condiciones_ids = perfil.condiciones_activas
        
        # 2. Obtener momentos y filtrar si es el día de hoy
        todos_momentos = self.repo_receta.listar_momentos_comida()
        momentos_cat = {m["id"]: m["nombre"] for m in todos_momentos}
        
        # Lógica de omisión inteligente por horario
        hoy = date.today()
        ahora = None
        if fecha_inicio == hoy:
            from datetime import datetime
            ahora = datetime.now().time()

        def debe_omitir(m_id):
            if fecha_inicio != hoy:
                return False
            m_data = next((m for m in todos_momentos if m["id"] == m_id), None)
            if not m_data or not m_data.get("hora_fin"):
                return False
            # Si la hora actual es mayor a la hora de fin del momento, se omite
            return ahora > m_data["hora_fin"]

        # 3. Preparar catálogo de recetas seguras
        recetas_seguras_cache = {}
        for m_id in momentos_ids:
            recetas_seguras_cache[m_id] = self.repo_receta.obtener_recetas_seguras_para_paciente(id_paciente, m_id)

        dias_plan = []
        
        # 4. Generar items día por día
        for i in range(dias):
            fecha_dia = fecha_inicio + timedelta(days=i)
            comidas_dia = []
            
            # Solo filtramos momentos por horario el primer día si es hoy
            momentos_dia = [m_id for m_id in momentos_ids if not (fecha_dia == hoy and debe_omitir(m_id))]
            
            for m_id in momentos_dia:
                # Buscar combinaciones aplicables
                combinaciones = self.repo_composicion.obtener_combinaciones_por_condiciones(m_id, condiciones_ids)
                
                if not combinaciones:
                    # Si no hay combinaciones, buscar una receta segura al azar
                    recetas_posibles = recetas_seguras_cache.get(m_id, [])
                    if recetas_posibles:
                        receta_elegida = self._seleccionar_receta_con_prioridad(recetas_posibles)
                        comidas_dia.append(ItemPlan(
                            id_receta=receta_elegida["id"],
                            nombre_receta=receta_elegida["nombre"],
                            id_momento=m_id,
                            nombre_momento=momentos_cat.get(m_id, "Momento"),
                            semaforo=receta_elegida.get("semaforo", "neutral"),
                            imagen_url=receta_elegida.get("imagen_url")
                        ))
                    continue

                # Elegir una combinación al azar
                combinacion = random.choice(combinaciones)
                platillos = combinacion["platillos"]
                
                for platillo in platillos:
                    tipo_plato_id = platillo["id"]
                    # Filtrar recetas seguras por tipo de plato
                    recetas_tipo = [r for r in recetas_seguras_cache.get(m_id, []) if tipo_plato_id in (r.get("tipos_plato_ids") or [])]
                    
                    if recetas_tipo:
                        receta_elegida = self._seleccionar_receta_con_prioridad(recetas_tipo)
                        comidas_dia.append(ItemPlan(
                            id_receta=receta_elegida["id"],
                            nombre_receta=receta_elegida["nombre"],
                            id_momento=m_id,
                            nombre_momento=momentos_cat.get(m_id, "Momento"),
                            semaforo=receta_elegida.get("semaforo", "neutral"),
                            imagen_url=receta_elegida.get("imagen_url")
                        ))

            dias_plan.append(DiaPlan(fecha=fecha_dia, comidas=comidas_dia))
            
        return PlanSemanal(id_paciente=id_paciente, fecha_inicio=fecha_inicio, dias=dias_plan)

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
        
        # Filtrar estrictamente por tipo de plato y excluir la actual
        alternativas = [
            r for r in recetas_seguras 
            if r["id"] != id_receta_actual and any(t in (r.get("tipos_plato_ids") or []) for t in tipos_actuales)
        ]
        
        if not alternativas:
            # Ya no intentamos con cualquier tipo, lanzamos error descriptivo
            raise ValueError("Por el momento no se tienen más recetas con este tipo de plato disponibles para el paciente.")
            
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
