from typing import Optional, Literal
from pydantic import BaseModel, ConfigDict, Field

class NutritionalVariable(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: Optional[int] = None
    codigo: str
    nombre_visible: str
    tipo_dato: Literal["numeric", "text", "boolean", "date", "json"] = "numeric"
    clasificacion: Optional[str] = None
    categoria_funcional: Optional[str] = None
    unidad: Optional[str] = None
    descripcion: Optional[str] = None
    es_calculable: bool = False
    participa_en_calculos: bool = False
    participa_en_reglas: bool = False
    permite_nulos: bool = True
    ausencia_bloquea_etiqueta: bool = False
    activo: bool = True

class VariableValue(BaseModel):
    id_ingrediente: int
    variable_codigo: str
    valor_numerico: Optional[float] = None
    valor_texto: Optional[str] = None
    valor_booleano: Optional[bool] = None
    estado_dato: str = "valor_real"
    origen_asignacion: str = "manual"
    justificacion: Optional[str] = None
