from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict

class RegistroConsumo(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id_plan_item: int
    id_estado_consumo: int # 1: Consumido, 2: No consumido, 3: Reemplazado
    id_receta_reemplazo: Optional[int] = None
    fecha_consumo: datetime = datetime.now()
    observacion: Optional[str] = None

class EstadisticasAdherencia(BaseModel):
    total_planificado: int
    total_consumido: int
    porcentaje_cumplimiento: float
    racha_dias: int
