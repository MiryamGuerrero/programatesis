from typing import Optional
from pydantic import BaseModel

class ClinicalDiagnosis(BaseModel):
    id_paciente: str
    peso_kg: float
    talla_cm: float
    imc: float
    z_score: Optional[float] = None
    diagnostico_oms: str
    id_condicion_nutricional: int
    edad_meses: int
