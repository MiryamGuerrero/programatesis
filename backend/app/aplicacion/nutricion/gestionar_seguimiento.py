from datetime import date
from typing import List, Dict
from ...domain.modelos.seguimiento import RegistroConsumo
from ...domain.repositorios.interfaces import IRepositorioSeguimiento

class CasoUsoGestionarSeguimiento:
    def __init__(self, repo_seguimiento: IRepositorioSeguimiento):
        self.repo_seguimiento = repo_seguimiento

    def obtener_plan_del_dia(self, id_paciente: str, fecha: date) -> List[Dict]:
        return self.repo_seguimiento.obtener_plan_del_dia(id_paciente, fecha)

    def obtener_dias_con_plan(self, id_paciente: str, mes: int, anio: int) -> List[date]:
        return self.repo_seguimiento.obtener_dias_con_plan(id_paciente, mes, anio)

    def registrar_comida_consumida(self, datos: dict) -> bool:
        registro = RegistroConsumo(**datos)
        return self.repo_seguimiento.registrar_consumo(registro)

    def obtener_estadisticas_adherencia(self, id_paciente: str, dias: int = 7) -> Dict:
        return self.repo_seguimiento.obtener_adherencia(id_paciente, dias)

    def obtener_lista_compras(self, id_paciente: str, fecha_inicio: date, fecha_fin: date) -> dict:
        return self.repo_seguimiento.obtener_lista_compras(id_paciente, fecha_inicio, fecha_fin)
