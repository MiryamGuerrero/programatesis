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
        # 1. Obtener restricciones heurísticas
        resultado_heuristico = self.caso_evaluacion.ejecutar(id_paciente)
        recetas_prohibidas = set(resultado_heuristico["recetas_prohibidas"])

        # 2. Cargar catálogo de recetas por momento
        momentos = self.repo_receta.listar_momentos_comida()
        recetas_por_momento = {}
        for m in momentos:
            recetas_por_momento[m["id"]] = self.repo_receta.obtener_recetas_por_momento(m["id"])

        # 3. Generar plan mediante servicio de dominio
        return ServicioPlanificadorNutricional.generar_plan_7_dias(
            id_paciente=id_paciente,
            fecha_inicio=fecha_inicio,
            recetas_por_momento=recetas_por_momento,
            ids_recetas_prohibidas=recetas_prohibidas,
            momentos_catalogo=momentos
        )
