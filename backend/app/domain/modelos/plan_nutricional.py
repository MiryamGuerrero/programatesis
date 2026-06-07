from datetime import date
from typing import List, Optional
from pydantic import BaseModel, ConfigDict

class ItemPlan(BaseModel):
    id_receta: int
    nombre_receta: str
    id_momento: int
    nombre_momento: str
    semaforo: str = "neutral"
    imagen_url: Optional[str] = None

class DiaPlan(BaseModel):
    fecha: date
    comidas: List[ItemPlan]

class PlanSemanal(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id_paciente: str
    fecha_inicio: date
    dias: List[DiaPlan]
