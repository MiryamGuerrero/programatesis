from enum import Enum
from typing import Optional
from pydantic import BaseModel, ConfigDict

class TipoAccion(str, Enum):
    ELIMINAR = "ELIMINAR"
    DISMINUIR = "DISMINUIR"
    PRIORIZAR = "PRIORIZAR"
    AUMENTAR = "AUMENTAR"

class TipoObjetivo(str, Enum):
    INGREDIENTE = "INGREDIENTE"
    SUBGRUPO = "SUBGRUPO"
    GRUPO = "GRUPO"
    ETIQUETA = "ETIQUETA"
    RECETA = "RECETA"

class FuenteRegla(str, Enum):
    CLINICA = "CLINICA"
    NUTRICIONAL = "NUTRICIONAL"
    TEMPORAL = "TEMPORAL"
    ALERGIA = "ALERGIA"

class Regla(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id_regla: Optional[int] = None
    fuente: FuenteRegla
    accion: TipoAccion
    tipo_objetivo: TipoObjetivo
    id_objetivo: int
    mensaje: Optional[str] = None
    prioridad: int = 100
    
    def __hash__(self):
        return hash((self.fuente, self.accion, self.tipo_objetivo, self.id_objetivo))
