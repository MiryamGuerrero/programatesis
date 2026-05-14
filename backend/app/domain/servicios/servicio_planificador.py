import random
from datetime import date, timedelta
from typing import List, Set, Dict
from ..modelos.plan_nutricional import PlanSemanal, DiaPlan, ItemPlan

class ServicioPlanificadorNutricional:
    @staticmethod
    def generar_plan_7_dias(
        id_paciente: str,
        fecha_inicio: date,
        recetas_por_momento: Dict[int, List[dict]],
        momentos_catalogo: List[dict]
    ) -> PlanSemanal:
        dias_plan = []
        
        for i in range(7):
            fecha_dia = fecha_inicio + timedelta(days=i)
            comidas_dia = []
            
            for momento in momentos_catalogo:
                id_m = momento["id"]
                nombre_m = momento["nombre"]
                
                # Opciones ya vienen filtradas por el repositorio
                opciones = recetas_por_momento.get(id_m, [])
                
                if opciones:
                    # Separar potenciadas de normales
                    potenciadas = [r for r in opciones if r.get("es_potenciada")]
                    normales = [r for r in opciones if not r.get("es_potenciada")]
                    
                    # Logica de seleccion: Priorizar potenciadas si existen (80% prob)
                    if potenciadas and (random.random() < 0.8 or not normales):
                        seleccionada = random.choice(potenciadas)
                    else:
                        seleccionada = random.choice(normales) if normales else random.choice(potenciadas)

                    comidas_dia.append(ItemPlan(
                        id_receta=seleccionada["id"],
                        nombre_receta=seleccionada["nombre"],
                        id_momento=id_m,
                        nombre_momento=nombre_m
                    ))
            
            dias_plan.append(DiaPlan(fecha=fecha_dia, comidas=comidas_dia))
            
        return PlanSemanal(id_paciente=id_paciente, fecha_inicio=fecha_inicio, dias=dias_plan)
