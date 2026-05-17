from pydantic import BaseModel, Field
from typing import List, Optional

class PlanManualItem(BaseModel):
    id_receta: int
    id_momento: int

class PlanManualRequest(BaseModel):
    id_paciente: str
    plan: List[PlanManualItem]
    replicate: bool = False

class PlanManualResponse(BaseModel):
    success: bool
    id_plan: int

class RecetasPermitidasRequest(BaseModel):
    id_paciente: str
    id_momento: Optional[int] = None
    id_tipo_plato: Optional[int] = None

class RecetasPermitidasResponse(BaseModel):
    id_paciente: str
    recetas: List[dict]

class RecomendacionIngredienteRequest(BaseModel):
    id_paciente: str
    id_ingrediente: int
    motivo: Optional[str] = None
    prioridad: int = 1
