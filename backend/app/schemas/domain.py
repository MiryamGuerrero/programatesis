from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


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
    recomendacion: str | None = "PERMITIDO"
    frecuencia_sugerida: str | None = None


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


# ======================= SCHEMAS CRUD INGREDIENTES =======================

class IngredienteCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=255)
    id_grupo_alimentario: int | None = None
    energia_kcal: float | None = None
    proteinas_g: float | None = None
    carbohidratos_g: float | None = None
    lipidos_g: float | None = None
    fibra_g: float | None = None
    calcio_mg: float | None = None
    hierro_mg: float | None = None
    potasio_mg: float | None = None
    descripcion: str | None = None
    activo: bool = True


class IngredienteUpdate(BaseModel):
    nombre: str | None = None
    id_grupo_alimentario: int | None = None
    energia_kcal: float | None = None
    proteinas_g: float | None = None
    carbohidratos_g: float | None = None
    lipidos_g: float | None = None
    fibra_g: float | None = None
    calcio_mg: float | None = None
    hierro_mg: float | None = None
    potasio_mg: float | None = None
    descripcion: str | None = None
    activo: bool | None = None


class IngredienteResponse(BaseModel):
    """
    Schema de respuesta para ingrediente con estructura migrada:
    - grupo_alimentario_id: Foreign Key (INT) a tabla grupo_alimentario
    - Etiquetas: removidas (en tabla ingrediente_etiqueta separada)
    - Nutrientes: clasificados en bloques (Macro, Micro, Bioactivos, Índices)
    """
    # Identificación
    id: int
    codigo: str | None = None
    nombre: str
    sinonimo: str | None = None
    
    # Grupo Alimentario (Foreign Key)
    grupo_alimentario_id: int | None = None
    subgrupo_alimentario: str | None = None
    p_comestible: float | None = None
    
    # MACRONUTRIENTES (14 columnas)
    energia_kcal: float | None = None
    agua_g: float | None = None
    alcohol_g: float | None = None
    proteinas_g: float | None = None
    carbohidratos_g: float | None = None
    almidon_g: float | None = None
    azucares_sencillos_g: float | None = None
    azucares_libres_g: float | None = None
    fibra_vegetal_g: float | None = None
    grasa_total_g: float | None = None
    ags_g: float | None = None
    agm_g: float | None = None
    agp_g: float | None = None
    
    # MICRONUTRIENTES - MINERALES (11 columnas)
    calcio_mg: float | None = None
    fosforo_mg: float | None = None
    hierro_mg: float | None = None
    iodo_ug: float | None = None
    cinc_mg: float | None = None
    magnesio_mg: float | None = None
    sodio_mg: float | None = None
    potasio_mg: float | None = None
    manganeso_mg: float | None = None
    cobre_mg: float | None = None
    selenio_ug: float | None = None
    
    # MICRONUTRIENTES - VITAMINAS (15 columnas)
    vitamina_a_ug: float | None = None
    retinol_ug: float | None = None
    carotenoides_ug: float | None = None
    vit_d_ug: float | None = None
    vit_e_mg: float | None = None
    vit_k_ug: float | None = None
    vitamina_b1_mg: float | None = None
    vitamina_b2_mg: float | None = None
    niacina_mg: float | None = None
    vitamina_b6_mg: float | None = None
    folato_ug: float | None = None
    vitamina_b12_ug: float | None = None
    pantotenico_mg: float | None = None
    biotina_ug: float | None = None
    vitamina_c_mg: float | None = None
    
    # COMPUESTOS BIOACTIVOS (6 columnas)
    colesterol_mg: float | None = None
    omega3_g: float | None = None
    tipo_omega3: str | None = None
    grasas_trans_g: float | None = None
    polifenoles_mg: float | None = None
    probioticos_billones: float | None = None
    
    # ÍNDICES/RATIOS (13 columnas)
    densidad_proteica: float | None = None
    densidad_fibra: float | None = None
    densidad_calcio: float | None = None
    densidad_hierro: float | None = None
    densidad_sodio: float | None = None
    densidad_magnesio: float | None = None
    relacion_agp_ags: float | None = None
    relacion_ca_p: float | None = None
    carga_grasa_saturada: float | None = None
    retencion_liquidos: float | None = None
    proporcion_azucar_carbohidrato: float | None = None
    ratio_fibra: float | None = None
    porcentaje_calorias_grasas: float | None = None
    
    # Precios
    precio_libra: float | None = None
    
    model_config = ConfigDict(from_attributes=True)
    

class IngredienteListaResponse(BaseModel):
    total: int
    items: list[IngredienteResponse]


# ======================= SCHEMAS CRUD ETIQUETAS =======================

class EtiquetaDefinicionCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=255)
    descripcion: str | None = None
    id_tipo_nutriente: int | None = None
    color_hex: str | None = None
    icono: str | None = None
    activa: bool = True


class EtiquetaDefinicionUpdate(BaseModel):
    nombre: str | None = None
    descripcion: str | None = None
    id_tipo_nutriente: int | None = None
    color_hex: str | None = None
    icono: str | None = None
    activa: bool | None = None


class EtiquetaDefinicionResponse(BaseModel):
    id: int
    nombre: str
    descripcion: str | None = None
    id_tipo_nutriente: int | None = None
    color_hex: str | None = None
    icono: str | None = None
    activa: bool


class EtiquetaCondicionCreate(BaseModel):
    id_etiqueta: int
    orden: int
    operador: str = Field(pattern="^(>|>=|<|<=|==|!=)$")
    valor_umbral: float
    texto_resultado: str = Field(min_length=1, max_length=500)


class EtiquetaCondicionUpdate(BaseModel):
    operador: str | None = Field(default=None, pattern="^(>|>=|<|<=|==|!=)$")
    valor_umbral: float | None = None
    texto_resultado: str | None = None
    orden: int | None = None


class EtiquetaCondicionResponse(BaseModel):
    id: int
    id_etiqueta: int
    orden: int
    operador: str
    valor_umbral: float
    texto_resultado: str


class EtiquetaConDetalleFull(BaseModel):
    id: int
    nombre: str
    descripcion: str | None = None
    id_tipo_nutriente: int | None = None
    color_hex: str | None = None
    icono: str | None = None
    activa: bool
    condiciones: list[EtiquetaCondicionResponse] = Field(default_factory=list)


class EtiquetaListaResponse(BaseModel):
    total: int
    items: list[EtiquetaDefinicionResponse]


class AsignacionEtiquetaIngrediente(BaseModel):
    id_ingrediente: int
    id_etiqueta: int


class AsignacionEtiquetasMultiples(BaseModel):
    id_ingrediente: int
    id_etiquetas: list[int]


# ======================= SCHEMAS ETIQUETAS NUTRICIONALES (Excel) =======================

class EtiquetaNutricionalBase(BaseModel):
    """Catálogo de etiquetas nutricionales del Excel"""
    codigo_interno: str = Field(min_length=1, max_length=50)
    nombre_categoria: str = Field(min_length=1, max_length=255)
    descripcion: str | None = None


class EtiquetaNutricionalCreate(EtiquetaNutricionalBase):
    pass


class EtiquetaNutricionalResponse(EtiquetaNutricionalBase):
    id: int

    model_config = ConfigDict(from_attributes=True)


class IngredienteEtiquetaBase(BaseModel):
    """Relación entre ingrediente y su valor de etiqueta nutricional"""
    ingrediente_id: int
    etiqueta_id: int
    valor_etiqueta: str = Field(min_length=1, max_length=255)


class IngredienteEtiquetaCreate(IngredienteEtiquetaBase):
    pass


class IngredienteEtiquetaResponse(IngredienteEtiquetaBase):
    id: int

    model_config = ConfigDict(from_attributes=True)


class IngredienteEtiquetaDetallada(BaseModel):
    """Etiqueta con su valor para un ingrediente específico"""
    id: int
    nombre_categoria: str
    valor_etiqueta: str
    codigo_interno: str


class IngredienteConEtiquetasResponse(BaseModel):
    """Ingrediente con etiquetas nutricionales (tabla separada)"""
    id: int
    codigo: str | None = None
    nombre: str
    sinonimo: str | None = None
    grupo_alimentario_id: int | None = None
    subgrupo_alimentario: str | None = None
    
    # Macronutrientes principales
    energia_kcal: float | None = None
    proteinas_g: float | None = None
    carbohidratos_g: float | None = None
    grasa_total_g: float | None = None
    fibra_vegetal_g: float | None = None
    
    # Micronutrientes principales
    calcio_mg: float | None = None
    hierro_mg: float | None = None
    vitamina_c_mg: float | None = None
    
    # Relación con etiquetas (tabla separada)
    etiquetas: list[IngredienteEtiquetaDetallada] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class ListaEtiquetasNutricionales(BaseModel):
    total: int
    items: list[EtiquetaNutricionalResponse]


# ======================= ESQUEMAS PARA REGLAS DE ETIQUETAS =======================

class EtiquetaNutricionalReglaBase(BaseModel):
    """Base para regla de etiqueta nutricional"""
    etiqueta_id: int
    nutriente_columna: str = Field(
        min_length=1, 
        max_length=100,
        description="Nombre del campo nutricional (ej: energia_kcal, calcio_mg)"
    )
    operador: str = Field(
        pattern="^(>|>=|<|<=|==|!=)$",
        description="Operador de comparacion"
    )
    valor_umbral: float = Field(gt=0, description="Valor de comparacion")
    orden: int = Field(default=1, ge=1, description="Orden de evaluacion")
    resultado_texto: str | None = Field(
        default=None,
        max_length=500,
        description="Texto a mostrar si se cumple la condicion"
    )
    activa: bool = Field(default=True, description="Si la regla esta activa")


class EtiquetaNutricionalReglaCreate(EtiquetaNutricionalReglaBase):
    """Para crear una nueva regla"""
    pass


class EtiquetaNutricionalReglaUpdate(BaseModel):
    """Para actualizar una regla existente"""
    operador: str | None = Field(
        default=None,
        pattern="^(>|>=|<|<=|==|!=)$"
    )
    valor_umbral: float | None = Field(default=None, gt=0)
    orden: int | None = Field(default=None, ge=1)
    resultado_texto: str | None = Field(default=None, max_length=500)
    activa: bool | None = None


class EtiquetaNutricionalReglaResponse(EtiquetaNutricionalReglaBase):
    """Respuesta de una regla"""
    id: int
    creada_en: str | None = None
    actualizada_en: str | None = None

    model_config = ConfigDict(from_attributes=True)


class EtiquetaNutricionalConReglasResponse(BaseModel):
    """Etiqueta nutricional con todas sus reglas"""
    id: int
    codigo_interno: str
    nombre_categoria: str
    descripcion: str | None = None
    reglas: list[EtiquetaNutricionalReglaResponse] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class AplicarReglasRequest(BaseModel):
    """Solicitud para aplicar reglas a ingredientes"""
    etiqueta_ids: list[int] | None = Field(
        default=None,
        description="Etiquetas especificas (None = todas)"
    )
    ingrediente_ids: list[int] | None = Field(
        default=None,
        description="Ingredientes especificos (None = todos)"
    )
    remplazar_existentes: bool = Field(
        default=True,
        description="Si reemplazar etiquetas existentes"
    )


class AplicarReglasResponse(BaseModel):
    """Resultado de aplicar reglas"""
    ingredientes_procesados: int
    etiquetas_asignadas: int
    etiquetas_removidas: int
    errores: list[str] = Field(default_factory=list)
    mensaje: str


class IngredienteEtiquetaAuditoriaResponse(BaseModel):
    """Registro de auditoria de aplicacion de reglas"""
    id: int
    ingrediente_id: int
    etiqueta_id: int
    regla_id: int | None = None
    valor_nutriente: float | None = None
    operador: str | None = None
    valor_umbral: float | None = None
    resultado_texto: str | None = None
    aplicada_en: str
    aplicado_por: str

    model_config = ConfigDict(from_attributes=True)


class ListaReglasResponse(BaseModel):
    """Lista de reglas de etiquetas"""
    total: int
    items: list[EtiquetaNutricionalReglaResponse]


class PlanManualRequest(BaseModel):
    id_paciente: str
    plan: dict
    replicate: bool = True


class PlanManualResponse(BaseModel):
    id_plan: int
    status: str


RoleName = Literal["admin", "medico", "nutricionista", "tutor"]


class RegistroTutorRequest(BaseModel):
    email: str = Field(min_length=1, max_length=255)
    nombre_completo: str = Field(min_length=1, max_length=255)
    id_paciente: str
    id_parentesco: int | None = None
    es_principal: bool = True


class ControlClinicoInicialRequest(BaseModel):
    peso_kg: float = Field(gt=0)
    talla_cm: float = Field(gt=0)
    imc_calculado: float | None = Field(default=None, gt=0)
    edad_meses: int | None = Field(default=None, ge=0, le=228)
    nivel_dolor_eva: int | None = Field(default=None, ge=0, le=10)
    nivel_inflamacion: int | None = Field(default=None, ge=0, le=10)
    nivel_fatiga: int | None = Field(default=None, ge=0, le=10)
    minutos_rigidez_matutina: int | None = Field(default=None, ge=0)
    inflamacion_pcr: float | None = Field(default=None, ge=0)
    hay_brote_activo: bool | None = None
    id_condicion_nutricional_resultado: int | None = Field(default=None, gt=0)
    diagnostico_oms_texto: str | None = Field(default=None, max_length=150)
    nota_evolucion: str | None = None
    id_condiciones_activas: list[int] = Field(default_factory=list)


class ControlClinicoActualResponse(ControlClinicoInicialRequest):
    id_control: int
    id_paciente: str
    fecha_control: date


class AlergiaIngredienteRequest(BaseModel):
    id_ingrediente: int = Field(gt=0)
    observacion: str | None = None


class AlergiaGrupoRequest(BaseModel):
    id_grupo_alimentario: int = Field(gt=0)
    observacion: str | None = None


class AlergiaIngredienteItem(BaseModel):
    id_ingrediente: int
    nombre_ingrediente: str
    observacion: str | None = None
    fecha_registro: date


class AlergiaGrupoItem(BaseModel):
    id_grupo_alimentario: int
    nombre_grupo: str
    observacion: str | None = None
    fecha_registro: date


class AlergiasPacienteResponse(BaseModel):
    ingredientes: list[AlergiaIngredienteItem] = Field(default_factory=list)
    grupos: list[AlergiaGrupoItem] = Field(default_factory=list)


class CondicionTemporalItem(BaseModel):
    id_condicion: int
    nombre: str
    descripcion: str | None = None


class CondicionesTemporalesResponse(BaseModel):
    id_paciente: str
    id_condiciones_temporales: list[int] = Field(default_factory=list)
    condiciones: list[CondicionTemporalItem] = Field(default_factory=list)


class ActualizarCondicionesTemporalesRequest(BaseModel):
    id_condiciones_temporales: list[int] = Field(default_factory=list)


class TipoCondicionCreateRequest(BaseModel):
    codigo: str = Field(min_length=1, max_length=30)
    nombre: str = Field(min_length=1, max_length=60)


class TipoCondicionUpdateRequest(BaseModel):
    codigo: str | None = Field(default=None, min_length=1, max_length=30)
    nombre: str | None = Field(default=None, min_length=1, max_length=60)


class CondicionCreateRequest(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    id_tipo_condicion: int = Field(gt=0)
    descripcion: str | None = None
    activa: bool = True


class CondicionUpdateRequest(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=150)
    id_tipo_condicion: int | None = Field(default=None, gt=0)
    descripcion: str | None = None
    activa: bool | None = None


class EvolucionControlItem(BaseModel):
    id_control: int
    fecha_control: date
    peso_kg: float | None = None
    talla_cm: float | None = None
    imc_calculado: float | None = None
    nivel_dolor_eva: int | None = None
    nivel_inflamacion: int | None = None


class EvolucionPacienteResumenResponse(BaseModel):
    id_paciente: str
    paciente_nombre: str | None = None
    total_controles: int
    ultimo_control: ControlClinicoActualResponse | None = None
    historial_controles: list[EvolucionControlItem] = Field(default_factory=list)
    condiciones_temporales_activas: list[CondicionTemporalItem] = Field(default_factory=list)
    total_alergias_ingrediente: int = 0
    total_alergias_grupo: int = 0
    id_plan_vigente: int | None = None
    adherencia_pct: float | None = None
    dolor_promedio: float | None = None
    comparacion_adherencia_dolor: str | None = None


class RegistroPacienteRequest(BaseModel):
    nombre_completo: str = Field(min_length=1, max_length=255)
    fecha_nacimiento: date
    id_sexo: int
    id_provincia: int | None = None
    control_clinico_inicial: ControlClinicoInicialRequest | None = None
    id_usuario_tutor: str
    id_parentesco: int | None = None
    es_principal: bool = True


class RegistroTutorSoloRequest(BaseModel):
    email: str = Field(min_length=1, max_length=255)
    nombre_completo: str = Field(min_length=1, max_length=255)


class RegistroPacienteSoloRequest(BaseModel):
    nombre_completo: str = Field(min_length=1, max_length=255)
    fecha_nacimiento: date
    id_sexo: int
    id_provincia: int | None = None
    control_clinico_inicial: ControlClinicoInicialRequest | None = None


class VincularTutorPacienteRequest(BaseModel):
    id_usuario_tutor: str
    id_paciente: str
    id_parentesco: int | None = None
    es_principal: bool = True


class ActualizarVinculoTutorPacienteRequest(BaseModel):
    id_parentesco: int | None = None
    es_principal: bool = True
