from datetime import date
from typing import List, Optional, Set
from pydantic import BaseModel, ConfigDict
from .reglas import Regla
from ..excepciones import ErrorValidacion

class Alergia(BaseModel):
    id_ingrediente: Optional[int] = None
    id_subgrupo: Optional[int] = None
    id_etiqueta: Optional[int] = None

class PerfilPaciente(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id_paciente: str
    nombre: str
    fecha_nacimiento: date
    id_sexo: int
    cedula: Optional[str] = None
    alergias: List[Alergia] = []
    condiciones_activas: List[int] = []
    reglas_aplicables: List[Regla] = []

    def validar(self):
        """Valida las reglas de integridad del paciente."""
        if self.fecha_nacimiento > date.today():
            raise ErrorValidacion("La fecha de nacimiento no puede ser en el futuro")
        
        # Ejemplo de regla clínica: solo niños menores de 18 años (sistema pediátrico)
        edad = (date.today() - self.fecha_nacimiento).days // 365
        if edad > 18:
            raise ErrorValidacion("El sistema está diseñado para pacientes pediátricos (menores de 18 años)")

    @property
    def ingredientes_prohibidos(self) -> Set[int]:
        return {r.id_objetivo for r in self.reglas_aplicables if r.accion == "ELIMINAR" and r.tipo_objetivo == "INGREDIENTE"}
