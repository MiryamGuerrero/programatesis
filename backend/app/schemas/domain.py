from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


class ImcRequest(BaseModel):
    peso_kg: float = Field(gt=0)
    talla_cm: float = Field(gt=0)


class ImcResponse(BaseModel):
    imc: float
    clasificacion: str


class DiagnosticoOmsRequest(BaseModel):
    indicador_codigo: str = "IMC_EDAD"
    id_sexo: int
    edad_meses: int = Field(ge=0, le=228)
    valor: float = Field(gt=0)


class DiagnosticoOmsResponse(BaseModel):
    z_score: float
    diagnostico: str
    l: float | None = None
    m: float | None = None
    s: float | None = None


class ReglaAplicada(BaseModel):
    id_regla: int
    accion: str
    objetivo: str
    objetivo_id: int
    mensaje_error: str | None = None


class ReglasEvaluacionRequest(BaseModel):
    id_condiciones: list[int]
    ingrediente_ids: list[int] = Field(default_factory=list)
    grupo_ids: list[int] = Field(default_factory=list)
    etiqueta_ids: list[int] = Field(default_factory=list)


class ReglasEvaluacionResponse(BaseModel):
    reglas_aplicadas: list[ReglaAplicada]
    ingredientes_eliminados: list[int]
    grupos_eliminados: list[int]
    etiquetas_eliminadas: list[int]


class IngredientesPermitidosRequest(BaseModel):
    id_paciente: str


class IngredientePermitido(BaseModel):
    id: int
    nombre: str
    id_grupo_alimentario: int | None = None
    motivo: str | None = None


class IngredientesPermitidosResponse(BaseModel):
    permitidos: list[IngredientePermitido]
    restringidos: list[IngredientePermitido]


class RecetasPermitidasRequest(BaseModel):
    id_paciente: str
    id_momento: int | None = None


class NutrienteTotal(BaseModel):
    nutriente: str
    unidad: str
    total: float


class RecetaPermitida(BaseModel):
    id: int
    nombre: str
    calorias_estimadas: float | None = None
    nutrientes: list[NutrienteTotal] = Field(default_factory=list)


class RecetasPermitidasResponse(BaseModel):
    recetas: list[RecetaPermitida]


class PlanAutomaticoRequest(BaseModel):
    id_paciente: str
    fecha_inicio: date
    dias: int = Field(default=7, ge=1, le=30)
    comidas_por_dia: int = Field(default=4, ge=1, le=8)


class PlanItem(BaseModel):
    fecha: date
    id_momento: int
    momento: str
    id_receta: int
    receta: str


class PlanAutomaticoResponse(BaseModel):
    items: list[PlanItem]


class ReemplazoEquivalenteRequest(BaseModel):
    id_ingrediente_original: int
    cantidad_gramos: float | None = Field(default=None, gt=0)


class ReemplazoEquivalenteItem(BaseModel):
    id_ingrediente_reemplazo: int
    nombre: str
    ratio_conversion: float
    gramos_recomendados: float | None = None
    mensaje_aviso: str | None = None


class ReemplazoEquivalenteResponse(BaseModel):
    reemplazos: list[ReemplazoEquivalenteItem]


class AdherenciaCalculoRequest(BaseModel):
    id_plan: int
    id_paciente: str | None = None


class AdherenciaCalculoResponse(BaseModel):
    total_items: int
    items_reportados: int
    adherencia_pct: float
    dolor_promedio: float | None = None
    comparacion: str | None = None


class PreferenciasAprendidasRequest(BaseModel):
    id_paciente: str
    persistir: bool = False


class PreferenciaReceta(BaseModel):
    id_receta: int
    score: float


class PreferenciaIngrediente(BaseModel):
    id_ingrediente: int
    score: float


class PreferenciasAprendidasResponse(BaseModel):
    recetas: list[PreferenciaReceta]
    ingredientes: list[PreferenciaIngrediente]


RoleName = Literal["admin", "medico", "nutricionista", "tutor"]
