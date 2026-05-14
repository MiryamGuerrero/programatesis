from datetime import date
from ...domain.repositorios.interfaces import IRepositorioReceta
from ...domain.servicios.servicio_planificador import ServicioPlanificadorNutricional
from .evaluar_reglas_paciente import CasoUsoEvaluarReglasPaciente

class CasoUsoGenerarPlanSemanal:
    def __init__(
        self,
        caso_evaluacion: CasoUsoEvaluarReglasPaciente,
        repo_receta: IRepositorioReceta
    ):
        self.caso_evaluacion = caso_evaluacion
        self.repo_receta = repo_receta

    def ejecutar(self, id_paciente: str, fecha_inicio: date):
        # 1. Obtener catálogo de recetas filtradas (seguras + potenciadas)
        momentos = self.repo_receta.listar_momentos_comida()
        recetas_por_momento = {}
        for m in momentos:
            recetas_por_momento[m["id"]] = self.repo_receta.obtener_recetas_seguras_para_paciente(id_paciente, m["id"])

        # 2. Generar plan mediante servicio de dominio
        return ServicioPlanificadorNutricional.generar_plan_7_dias(
            id_paciente=id_paciente,
            fecha_inicio=fecha_inicio,
            recetas_por_momento=recetas_por_momento,
            momentos_catalogo=momentos
        )
