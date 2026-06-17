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
        momentos_opcionales: List[int],
        log_callback: Optional[callable] = None
    ) -> dict:
        if log_callback: log_callback("Analizando perfil clínico y reglas de seguridad...")
        # 1. Generar la estructura del plan en memoria usando la misma lógica
        plan_semanal = self.generar_plan_objeto(
            id_paciente=id_paciente,
            fecha_inicio=fecha_inicio,
            dias=dias,
            momentos_ids=sorted(list(set(momentos_obligatorios + momentos_opcionales))),
            log_callback=log_callback
        )
        
        if log_callback: log_callback(f"Guardando plan de {dias} días en el sistema...")
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
        momentos_ids: List[int],
        log_callback: Optional[callable] = None
    ) -> PlanSemanal:
        # 1. Obtener perfil del paciente (para condiciones)
        perfil = self.repo_paciente.obtener_por_id(id_paciente)
        if not perfil:
            raise ValueError("Paciente no encontrado")
        
        condiciones_ids = perfil.condiciones_activas
        
        # 2. Obtener momentos y filtrar si es el día de hoy
        todos_momentos = self.repo_receta.listar_momentos_comida()
        momentos_cat = {m["id"]: m["nombre"] for m in todos_momentos}
        
        hoy = date.today()
        from datetime import datetime
        ahora = datetime.now().time() if fecha_inicio == hoy else None

        # 3. OPTIMIZACIÓN CRÍTICA Nivel 1: Traer todas las combinaciones aplicables de golpe
        if log_callback: log_callback("Cargando reglas de combinación clínica...")
        todas_combinaciones = self.repo_composicion.obtener_todas_combinaciones_por_condiciones(
            momentos_ids, condiciones_ids
        )
        
        # Mapa de [id_momento] -> List[Combinaciones]
        combinaciones_por_momento = {}
        for c in todas_combinaciones:
            m_id = c["id_momento"]
            if m_id not in combinaciones_por_momento:
                combinaciones_por_momento[m_id] = []
            combinaciones_por_momento[m_id].append(c)

        # 3. OPTIMIZACIÓN CRÍTICA Nivel 2: Traer todo el catálogo de recetas seguras una sola vez
        if log_callback: log_callback("Sincronizando catálogo masivo de recetas seguras...")
        pool_recetas_seguras = self.repo_receta.obtener_recetas_seguras_bulk(
            id_paciente, limite=1500
        )
        
        # Mapa de [id_momento][id_tipo_plato] -> List[Recetas]
        recetas_por_momento_y_tipo = {}
        for m_id in momentos_ids:
            recetas_por_momento_y_tipo[m_id] = {}
            # Filtrar recetas que sirven para este momento
            recetas_momento = [r for r in pool_recetas_seguras if m_id in (r.get("momentos_ids") or [])]
            
            # Sub-categorizar por tipos de plato para las combinaciones
            for r in recetas_momento:
                for t_id in (r.get("tipos_plato_ids") or []):
                    if t_id not in recetas_por_momento_y_tipo[m_id]:
                        recetas_por_momento_y_tipo[m_id][t_id] = []
                    recetas_por_momento_y_tipo[m_id][t_id].append(r)
            
            # Guardar también el pool general del momento para fallbacks
            recetas_por_momento_y_tipo[m_id]["general"] = recetas_momento

        dias_plan = []
        
        # 4. Generar items día por día (Procesamiento en memoria ultra-rápido)
        if log_callback: log_callback(f"Generando menús inteligentes para {dias} días...")
        for i in range(dias):
            fecha_dia = fecha_inicio + timedelta(days=i)
            comidas_dia = []
            
            # Cada 7 días reportamos progreso
            if log_callback and i > 0 and i % 7 == 0:
                log_callback(f"Procesando semana {i // 7 + 1}...")

            # Filtrar momentos que ya pasaron si es hoy
            momentos_dia = []
            for m_id in momentos_ids:
                if fecha_dia == hoy and ahora:
                    m_data = next((m for m in todos_momentos if m["id"] == m_id), None)
                    if m_data and m_data.get("hora_fin") and ahora > m_data["hora_fin"]:
                        continue
                momentos_dia.append(m_id)
            
            for m_id in momentos_dia:
                # Usar combinaciones pre-cargadas
                combinaciones = combinaciones_por_momento.get(m_id, [])
                
                receta_seleccionada = None
                
                if combinaciones:
                    # Intentar aplicar una combinación nutricional balanceada
                    random.shuffle(combinaciones) 
                    for combinacion in combinaciones:
                        platillos = combinacion["platillos"]
                        todas_disponibles = True
                        temp_comidas = []
                        
                        for platillo in platillos:
                            tipo_plato_id = platillo["id"]
                            opciones = recetas_por_momento_y_tipo[m_id].get(tipo_plato_id, [])
                            if opciones:
                                r_elegida = self._seleccionar_receta_con_prioridad(opciones)
                                temp_comidas.append(ItemPlan(
                                    id_receta=r_elegida["id"],
                                    nombre_receta=r_elegida["nombre"],
                                    id_momento=m_id,
                                    nombre_momento=momentos_cat.get(m_id, "Momento"),
                                    semaforo=r_elegida.get("semaforo", "neutral"),
                                    imagen_url=r_elegida.get("imagen_url")
                                ))
                            else:
                                todas_disponibles = False
                                break
                        
                        if todas_disponibles:
                            comidas_dia.extend(temp_comidas)
                            receta_seleccionada = True
                            break

                # Fallback: Si no hay combinaciones o no hay recetas para los tipos
                if not receta_seleccionada:
                    opciones_fallback = recetas_por_momento_y_tipo[m_id].get("general", [])
                    if opciones_fallback:
                        r_elegida = self._seleccionar_receta_con_prioridad(opciones_fallback)
                        comidas_dia.append(ItemPlan(
                            id_receta=r_elegida["id"],
                            nombre_receta=r_elegida["nombre"],
                            id_momento=m_id,
                            nombre_momento=momentos_cat.get(m_id, "Momento"),
                            semaforo=r_elegida.get("semaforo", "neutral"),
                            imagen_url=r_elegida.get("imagen_url")
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
        # Pesos base optimizados usando los flags pre-calculados en SQL
        pesos = []
        for r in recetas:
            peso = 1.0
            # Prioridad 1: Preferencia del usuario (corazón)
            if r.get("es_preferida"): peso *= 2.0
            # Prioridad 2: Recomendación clínica (Apto/Potenciado)
            if r.get("es_potenciada"): peso *= 1.5
            # Prioridad 3: Restricción clínica leve (Disminuir)
            if r.get("es_disminuida"): peso *= 0.5
            
            pesos.append(peso)
            
        return random.choices(recetas, weights=pesos, k=1)[0]
