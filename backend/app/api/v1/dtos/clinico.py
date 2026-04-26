from pydantic import BaseModel, Field
from datetime import date
from typing import Optional

class PreDiagnosticoRequest(BaseModel):
    id_paciente: str
    fecha_nacimiento: date
    id_sexo: int
    peso_kg: float
    talla_cm: float

class PreDiagnosticoResponse(BaseModel):
    imc: float
    z_score: float
    id_condicion_nutricional: int
    diagnostico_nutri_texto: str
    anios: int
    meses: int

class PacienteRegistroCompleto(BaseModel):
    nombre_completo: str
    fecha_nacimiento: date
    id_sexo: int
    id_provincia: Optional[int] = None
