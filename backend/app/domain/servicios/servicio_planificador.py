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
        ids_recetas_prohibidas: Set[int],
        momentos_catalogo: List[dict]
    ) -> PlanSemanal:
        dias_plan = []
        
        for i in range(7):
            fecha_dia = fecha_inicio + timedelta(days=i)
            comidas_dia = []
            
            for momento in momentos_catalogo:
                id_m = momento["id"]
                nombre_m = momento["nombre"]
                
                # Filtrar solo seguras
                opciones_seguras = [
                    r for r in recetas_por_momento.get(id_m, [])
                    if r["id"] not in ids_recetas_prohibidas
                ]
                
                if opciones_seguras:
                    seleccionada = random.choice(opciones_seguras)
                    comidas_dia.append(ItemPlan(
                        id_receta=seleccionada["id"],
                        nombre_receta=seleccionada["nombre"],
                        id_momento=id_m,
                        nombre_momento=nombre_m
                    ))
            
            dias_plan.append(DiaPlan(fecha=fecha_dia, comidas=comidas_dia))
            
        return PlanSemanal(id_paciente=id_paciente, fecha_inicio=fecha_inicio, dias=dias_plan)
