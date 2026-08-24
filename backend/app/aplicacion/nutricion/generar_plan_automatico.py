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
        historial_recientes = [] # Memoria de recetas usadas para evitar repeticiones
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
                    # --- FILTRO HEURÍSTICO INTELIGENTE POR MOMENTO ---
                    # Evitar que condiciones de peso Normal habiliten comidas hipercalóricas de noche o en snacks
                    
                    if m_id == 5: # Merienda (Noche)
                        # Eliminar totalmente opciones energéticas
                        combinaciones = [c for c in combinaciones if c.get("rol") != "COMBINACION_ENERGETICA"]
                        # Priorizar ligeras y suaves
                        ligeras = [c for c in combinaciones if c.get("rol") in ("COMBINACION_LIGERA", "COMBINACION_SUAVE")]
                        if ligeras:
                            combinaciones = ligeras
                            
                    elif m_id in (2, 4): # Snacks (Media Mañana y Media Tarde)
                        # Priorizar combinaciones con pocos platillos (1 o 2)
                        cortas = [c for c in combinaciones if len(c.get("platillos", [])) <= 2]
                        if cortas:
                            combinaciones = cortas
                            
                    elif m_id == 3: # Almuerzo
                        # Priorizar equilibradas o energéticas
                        fuertes = [c for c in combinaciones if c.get("rol") in ("COMBINACION_EQUILIBRADA", "COMBINACION_ENERGETICA")]
                        if fuertes:
                            combinaciones = fuertes

                    # Intentar aplicar una combinación nutricional balanceada
                    random.shuffle(combinaciones) 
                    for combinacion in combinaciones:
                        platillos = combinacion["platillos"]
                        todas_disponibles = True
                        temp_comidas = []
                        tipos_cubiertos = set() # Tracking de tipos ya resueltos
                        
                        # Analizar si la combinación YA exige un plato dulce por naturaleza
                        tipos_dulces = {22, 34, 35, 36, 37, 44, 46} # Pancakes, Postre, Compota, Jugo, Fruta, Yogur, Batido
                        combinacion_exige_dulce = any(p["id"] in tipos_dulces for p in platillos)
                        tiene_dulce_accidental = False
                        
                        # Tracking de grupos de proteínas fuertes para evitar mezclas raras (ej. Pescado con Pescado, Pollo con Carne)
                        grupos_proteina_fuertes = {7, 8} # 7: Carnes Y Derivados, 8: Pescados Y Derivados
                        grupos_proteina_usados = set()
                        
                        for platillo in platillos:
                            tipo_plato_id = platillo["id"]
                            
                            # Regla Interna: Si un plato anterior (multipropósito) ya cubrió este tipo de comida, lo saltamos
                            if tipo_plato_id in tipos_cubiertos:
                                continue
                                
                            opciones = recetas_por_momento_y_tipo[m_id].get(tipo_plato_id, [])
                            
                            # Heurística Anti-Repetición de Proteína Fuerte
                            if opciones and grupos_proteina_usados:
                                # Filtrar recetas que contengan grupos de proteína fuertes (7, 8) para que no haya doble carne/pescado
                                opciones_filtradas_proteina = [op for op in opciones if not (set(op.get("g_ids") or []) & grupos_proteina_fuertes)]
                                if opciones_filtradas_proteina:
                                    opciones = opciones_filtradas_proteina
                            
                            # Heurística Anti-Empalago: Si la comida ya es dulce, forzamos opciones saladas para los otros platos
                            if opciones and (combinacion_exige_dulce or tiene_dulce_accidental) and tipo_plato_id not in tipos_dulces:
                                palabras_dulces = ["dulce", "miel", "chocolate", "manzana", "fresa", "fruta", "postre", "yogur", "compota", "batido", "jugo", "pancake", "panque", "pera", "platano", "durazno"]
                                opciones_saladas = [op for op in opciones if not any(w in op["nombre"].lower() for w in palabras_dulces)]
                                if opciones_saladas:
                                    opciones = opciones_saladas
                                    
                            if opciones:
                                r_elegida = self._seleccionar_receta_con_prioridad(opciones, historial_recientes)
                                
                                # Registrar si elegimos un plato dulce por accidente (ej. Wrap dulce)
                                if tipo_plato_id not in tipos_dulces:
                                    palabras_dulces = ["dulce", "miel", "chocolate", "manzana", "fresa", "fruta", "postre", "yogur", "compota", "batido", "jugo", "pancake", "panque", "pera", "platano", "durazno"]
                                    if any(w in r_elegida["nombre"].lower() for w in palabras_dulces):
                                        tiene_dulce_accidental = True
                                        
                                historial_recientes.append(r_elegida["id"])
                                if len(historial_recientes) > 20: # Recuerda las últimas 20 recetas (~4 días)
                                    historial_recientes.pop(0)
                                    
                                # Registrar si la receta usa una proteína fuerte (Carne o Pescado)
                                g_ids_receta = set(r_elegida.get("g_ids") or [])
                                grupos_proteina_usados.update(g_ids_receta & grupos_proteina_fuertes)

                                    
                                # Marcar TODOS los tipos que cubre esta receta para evitar redundancias luego (ej. Arroz)
                                for t_id in (r_elegida.get("tipos_plato_ids") or []):
                                    tipos_cubiertos.add(t_id)
                                    
                                temp_comidas.append(ItemPlan(
                                    id_receta=r_elegida["id"],
                                    nombre_receta=r_elegida["nombre"],
                                    id_momento=m_id,
                                    nombre_momento=momentos_cat.get(m_id, "Momento"),
                                    semaforo=r_elegida.get("semaforo", "neutral"),
                                    imagen_url=r_elegida.get("imagen_url")
                                ))
                            else:
                                # Si falta un plato crítico que no fue cubierto, la combinación entera falla
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
                        r_elegida = self._seleccionar_receta_con_prioridad(opciones_fallback, historial_recientes)
                        historial_recientes.append(r_elegida["id"])
                        if len(historial_recientes) > 20:
                            historial_recientes.pop(0)
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

    def _seleccionar_receta_con_prioridad(self, recetas: List[dict], historial_recientes: Optional[List[int]] = None) -> dict:
        if historial_recientes is None:
            historial_recientes = []

        # Pesos base optimizados usando los flags pre-calculados en SQL
        pesos = []
        for r in recetas:
            peso = 1.0
            
            # Penalización fuerte si la receta ya salió recientemente para forzar variedad
            if r["id"] in historial_recientes:
                peso *= 0.05

            # Prioridad 1: Preferencia del usuario (corazón)
            if r.get("es_preferida"): peso *= 6.0
            # Prioridad 2: Recomendación clínica (Apto/Potenciado)
            if r.get("es_potenciada"): peso *= 4.0
            # Prioridad 3: Restricción clínica leve (Disminuir)
            if r.get("es_disminuida"): peso *= 0.1
            
            pesos.append(peso)
            
        return random.choices(recetas, weights=pesos, k=1)[0]

    def asignar_comidas_manuales_fechas(self, id_paciente: str, id_receta: int, id_momento: int, fechas: List[date], id_usuario: int = None) -> dict:
        if not fechas:
            raise ValueError("Debe proveer al menos una fecha")
            
        # Ordenar fechas para saber el rango
        fechas_ord = sorted(fechas)
        fecha_min = fechas_ord[0]
        fecha_max = fechas_ord[-1]
        
        # Crear un "Plan" cabecera especial para estas inserciones manuales (o buscar uno existente que calce)
        # Por simplicidad, creamos un plan que cubra este rango con id_origen_plan = 2 (Nutricionista/Médico)
        id_plan = self.repo_seguimiento.crear_plan_nutricional({
            "id_paciente": id_paciente,
            "id_origen_plan": 2, 
            "id_estado_plan": 2, 
            "fecha_inicio": fecha_min,
            "fecha_fin": fecha_max,
            "comidas_por_dia": 1,
            "creado_por": id_usuario
        })
        
        items_a_insertar = []
        for f in fechas_ord:
            items_a_insertar.append({
                "id_plan": id_plan,
                "fecha_programada": f,
                "id_momento": id_momento,
                "id_receta": id_receta
            })
            
        self.repo_seguimiento.agregar_items_plan(items_a_insertar)
        
        return {
            "success": True,
            "items_inserted": len(items_a_insertar),
            "id_plan": id_plan
        }
