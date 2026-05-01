from pydantic import BaseModel, Field
from datetime import date
from typing import Optional

class PreDiagnosticoRequest(BaseModel):
    id_paciente: Optional[str] = None
    fecha_nacimiento: date
    id_sexo: int
    peso_kg: float
    talla_cm: float

class PreDiagnosticoResponse(BaseModel):
    imc: float
    z_score: Optional[float] = None
    id_condicion_nutricional: Optional[int] = None
    diagnostico_nutri_texto: str
    diagnostico_talla_texto: Optional[str] = "Sin referencia"
    z_score_talla: Optional[float] = None
    peso_ideal: Optional[float] = 0.0
    talla_ideal: Optional[float] = 0.0
    anios: int
    meses: int

class PacienteRegistroCompleto(BaseModel):
    nombre_completo: str
    fecha_nacimiento: date
    id_sexo: int
    id_provincia: Optional[int] = None
