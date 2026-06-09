from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from datetime import date
from ..modelos.paciente import PerfilPaciente
from ..modelos.clinico import ClinicalDiagnosis
from ..modelos.usuario import PerfilUsuario
from ..modelos.reglas import Regla
from ..modelos.seguimiento import RegistroConsumo

class IRepositorioPaciente(ABC):
    @abstractmethod
    def obtener_por_id(self, id_paciente: str) -> Optional[PerfilPaciente]:
        pass

    @abstractmethod
    def buscar_pacientes(self, consulta: str, limite: int = 50) -> List[dict]:
        pass

    @abstractmethod
    def listar_todos_pacientes(self) -> List[dict]:
        pass

    @abstractmethod
    def obtener_resumen_evolucion(self, id_paciente: str) -> List[dict]:
        pass

    @abstractmethod
    def obtener_evolucion_mensual(
        self,
        id_paciente: str,
        fecha_inicio: str | None = None,
        fecha_fin: str | None = None,
        estado_enfermedad: str | None = None,
        en_brote: bool | None = None,
        estado_nutricional: str | None = None,
        solo_alterados: bool = False,
    ) -> Dict[str, Any]:
        pass

    @abstractmethod
    def obtener_expediente_completo(self, id_paciente: str) -> dict:
        pass

    @abstractmethod
    def registrar_paciente_integral(self, payload: dict, id_usuario_creador: str = None) -> dict:
        pass

    @abstractmethod
    def actualizar_paciente_integral(self, id_paciente: str, payload: dict) -> bool:
        pass

    @abstractmethod
    def registrar_control_mensual(self, id_paciente: str, datos: dict, id_medico: str) -> int:
        pass

    @abstractmethod
    def actualizar_control_mensual_especifico(self, id_control: int, datos: dict) -> bool:
        pass

    @abstractmethod
    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        pass

class IRepositorioPerfil(ABC):
    @abstractmethod
    def obtener_por_auth_id(self, auth_id: str) -> Optional[PerfilUsuario]:
        pass

    @abstractmethod
    def actualizar_datos_perfil(self, auth_id: str, datos: dict) -> bool:
        pass

    @abstractmethod
    def buscar_tutor_por_cedula(self, cedula: str) -> Optional[dict]:
        pass

    @abstractmethod
    def registrar_tutor_solo(self, datos: dict) -> str:
        pass

    @abstractmethod
    def listar_usuarios(self) -> List[dict]:
        pass

    @abstractmethod
    def crear_usuario(self, datos: dict) -> str:
        pass

    @abstractmethod
    def obtener_catalogo(self, esquema: str, tabla: str, filtro_tipos: List[int] = None) -> List[dict]:
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
    def listar_ingredientes_admin(self, consulta: str = None, limite: int = 100, desplazamiento: int = 0, incluir_inactivos: bool = False, id_grupo: int = None, id_subgrupo: int = None) -> List[dict]:
        pass

    @abstractmethod
    def contar_ingredientes_admin(self, consulta: str = None, incluir_inactivos: bool = False, id_grupo: int = None, id_subgrupo: int = None) -> int:
        pass

    @abstractmethod
    def crear_ingrediente(self, datos: dict) -> int:
        pass
    
    @abstractmethod
    def obtener_mapa_etiquetas_ingrediente(self) -> dict:
        pass

    @abstractmethod
    def obtener_mapa_etiquetas_receta(self) -> dict:
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

    @abstractmethod
    def obtener_ingrediente(self, id_ingrediente: int) -> Optional[dict]:
        pass

    @abstractmethod
    def actualizar_ingrediente(self, id_ingrediente: int, datos: dict) -> bool:
        pass

    @abstractmethod
    def eliminar_ingrediente(self, id_ingrediente: int) -> bool:
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


class IRepositorioClinico(ABC):
    @abstractmethod
    def obtener_datos_referencia_oms(self, id_sexo: int, edad_meses: int, indicador: str = "IMC_EDAD"):
        pass

    @abstractmethod
    def guardar_control_clinico(self, diagnostico: ClinicalDiagnosis) -> int:
        pass


class IRepositorioComposicion(ABC):
    @abstractmethod
    def obtener_combinaciones_por_condiciones(self, id_momento: int, ids_condiciones: List[int]) -> List[dict]:
        pass


class IRepositorioReceta(ABC):
    @abstractmethod
    def obtener_recetas_por_momento(self, id_momento: int) -> List[dict]:
        pass

    @abstractmethod
    def obtener_recetas_seguras_para_paciente(self, id_paciente: str, id_momento: Optional[int] = None) -> List[dict]:
        pass

    @abstractmethod
    def obtener_receta(self, id_receta: int) -> Optional[dict]:
        pass

    @abstractmethod
    def listar_momentos_comida(self) -> List[dict]:
        pass

    @abstractmethod
    def cambiar_estado_receta(self, id_receta: int, activa: bool) -> bool:
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

    @abstractmethod
    def obtener_lista_compras(self, id_paciente: str, fecha_inicio: date, fecha_fin: date) -> dict:
        pass

class IRepositorioPlan(ABC):
    @abstractmethod
    def guardar_plan_manual(self, id_paciente: str, items: List[Dict], replicate: bool = False) -> bool:
        pass

    @abstractmethod
    def obtener_planes_por_paciente(self, id_paciente: str) -> List[dict]:
        pass

    @abstractmethod
    def eliminar_plan(self, id_plan: int) -> bool:
        pass

    @abstractmethod
    def obtener_detalle_plan(self, id_plan: int) -> List[dict]:
        pass
