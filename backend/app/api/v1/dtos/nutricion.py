from datetime import date
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

class AsignarComidaManualFechasRequest(BaseModel):
    id_paciente: str
    id_receta: int
    id_momento: int
    fechas: List[date]

class RecetasPermitidasRequest(BaseModel):
    id_paciente: str
    id_momento: Optional[int] = None
    id_tipo_plato: Optional[int] = None
    consulta: Optional[str] = None
    limite: int = 100
    offset: int = 0

class RecetasPermitidasResponse(BaseModel):
    id_paciente: str
    recetas: List[dict]

class RecomendacionIngredienteRequest(BaseModel):
    id_paciente: str
    id_ingrediente: int
    motivo: Optional[str] = None
    prioridad: int = 1

class PlanAutomaticoRequest(BaseModel):
    id_paciente: str
    fecha_inicio: date
    dias: int = 7
    momentos_ids: Optional[List[int]] = None
