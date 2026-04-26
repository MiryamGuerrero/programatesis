from datetime import date
from typing import List, Dict
from ...domain.modelos.seguimiento import RegistroConsumo
from ...domain.repositorios.interfaces import IRepositorioSeguimiento

class CasoUsoGestionarSeguimiento:
    def __init__(self, repo_seguimiento: IRepositorioSeguimiento):
        self.repo_seguimiento = repo_seguimiento

    def obtener_menu_diario(self, id_paciente: str, fecha: date) -> List[Dict]:
        return self.repo_seguimiento.obtener_plan_del_dia(id_paciente, fecha)

    def registrar_comida_consumida(self, datos: Dict) -> bool:
        registro = RegistroConsumo(**datos)
        return self.repo_seguimiento.registrar_consumo(registro)

    def obtener_estadisticas_adherencia(self, id_paciente: str, dias: int = 7) -> Dict:
        return self.repo_seguimiento.obtener_adherencia(id_paciente, dias)
