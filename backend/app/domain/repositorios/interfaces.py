from abc import ABC, abstractmethod
from typing import List, Optional
from datetime import date
from ..modelos.paciente import PerfilPaciente
from ..modelos.usuario import PerfilUsuario
from ..modelos.reglas import Regla
from ..modelos.seguimiento import RegistroConsumo

class IRepositorioPaciente(ABC):
    @abstractmethod
    def obtener_por_id(self, id_paciente: str) -> Optional[PerfilPaciente]:
        pass

class IRepositorioPerfil(ABC):
    @abstractmethod
    def obtener_por_auth_id(self, auth_id: str) -> Optional[PerfilUsuario]:
        pass

    @abstractmethod
    def actualizar_datos_perfil(self, auth_id: str, datos: dict) -> bool:
        pass

class IRepositorioRegla(ABC):
    @abstractmethod
    def obtener_reglas_por_condiciones(self, ids_condiciones: List[int]) -> List[Regla]:
        pass
    
    @abstractmethod
    def obtener_alergias_por_paciente(self, id_paciente: str) -> List[Regla]:
        pass

class IRepositorioIngrediente(ABC):
    @abstractmethod
    def listar_todos_activos(self) -> List[dict]:
        pass

    @abstractmethod
    def listar_ingredientes_admin(self, consulta: str = None, limite: int = 100, desplazamiento: int = 0, incluir_inactivos: bool = False) -> List[dict]:
        pass

    @abstractmethod
    def crear_ingrediente(self, datos: dict) -> int:
        pass
    
    @abstractmethod
    def obtener_mapa_etiquetas_ingrediente(self) -> dict:
        pass

    @abstractmethod
    def obtener_mapa_ingredientes_receta(self) -> dict:
        pass

    @abstractmethod
    def registrar_recomendacion(self, id_paciente: str, id_ingrediente: int, id_profesional: str, id_rol: int, motivo: str = None, prioridad: int = 1) -> bool:
        pass

    @abstractmethod
    def eliminar_recomendacion(self, id_paciente: str, id_ingrediente: int) -> bool:
        pass

    @abstractmethod
    def listar_recomendaciones_paciente(self, id_paciente: str) -> List[dict]:
        pass

class IRepositorioNutricion(ABC):
    @abstractmethod
    def listar_variables(self, q: str = None, limit: int = 200) -> List[dict]:
        pass

    @abstractmethod
    def upsert_definicion_variable(self, variable: dict) -> int:
        pass

    @abstractmethod
    def obtener_variable_por_id(self, variable_id: int) -> Optional[dict]:
        pass

    @abstractmethod
    def upsert_valor_variable(self, datos_valor: dict, actualizado_por: str) -> None:
        pass

class IRepositorioReceta(ABC):
    @abstractmethod
    def obtener_recetas_por_momento(self, id_momento: int) -> List[dict]:
        pass

    @abstractmethod
    def obtener_recetas_seguras_para_paciente(self, id_paciente: str, id_momento: Optional[int] = None) -> List[dict]:
        pass

    @abstractmethod
    def listar_momentos_comida(self) -> List[dict]:
        pass

class IRepositorioSeguimiento(ABC):
    @abstractmethod
    def registrar_consumo(self, registro: RegistroConsumo) -> bool:
        pass

    @abstractmethod
    def obtener_plan_del_dia(self, id_paciente: str, fecha: date) -> List[dict]:
        pass

    @abstractmethod
    def obtener_adherencia(self, id_paciente: str, dias_atras: int) -> dict:
        pass

    @abstractmethod
    def obtener_reporte_adherencia_medico(self, id_medico: str) -> List[dict]:
        pass
