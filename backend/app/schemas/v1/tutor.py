from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date

class SuccessResponse(BaseModel):
    success: bool = True

class TipSaludableResponse(BaseModel):
    mensaje: str
    categoria: str

class RegistroConsumoRequest(BaseModel):
    id_plan_item: int
    id_estado_consumo: int
    observacion: Optional[str] = None

class GenerarPlanRequest(BaseModel):
    id_paciente: str
    dias: int
    fecha_inicio: date
    momentos_obligatorios: List[int]
    momentos_opcionales: List[int]

class IntercambiarRecetaRequest(BaseModel):
    id_plan_item: int

class PacienteResponse(BaseModel):
    id: str
    nombre_completo: str
    # Agrega mas campos segun sea necesario para la documentacion

class SubgrupoPreferenciaResponse(BaseModel):
    id: int
    nombre: str
    emoji: Optional[str]
    grupo: str
    es_preferido: bool
