from pydantic import BaseModel, Field
from datetime import date
from typing import Any, Optional

class PreDiagnosticoRequest(BaseModel):
    id_paciente: Optional[str] = None
    fecha_nacimiento: date
    id_sexo: int
    peso_kg: float
    talla_cm: float


class EstadoNutricionalOMSRequest(BaseModel):
    sexo_id: int
    fecha_nacimiento: date
    fecha_control: date
    peso_kg: float
    talla_cm: float
    tipo_medicion: Optional[str] = None

class PreDiagnosticoResponse(BaseModel):
    imc: float
    z_score: Optional[float] = None
    id_condicion_nutricional: Optional[int] = None
    id_condicion_nutricional_oms: Optional[int] = None
    diagnostico_nutri_texto: str
    diagnostico_talla_texto: Optional[str] = "Sin referencia"
    diagnostico_peso_complementario: Optional[str] = "Sin referencia"
    diagnostico_combinado: Optional[str] = "Sin clasificación"
    resumen_clinico: Optional[str] = ""
    z_score_talla: Optional[float] = None
    peso_ideal: Optional[float] = 0.0
    talla_ideal: Optional[float] = 0.0
    ganancia_peso_necesaria: Optional[float] = 0.0
    ganancia_talla_necesaria: Optional[float] = 0.0
    estado_peso: Optional[str] = "mantener"
    anios: int
    meses: int

class PacienteRegistroCompleto(BaseModel):
    nombre_completo: str
    fecha_nacimiento: date
    id_sexo: int
    id_canton: Optional[int] = None
    id_parroquia: Optional[int] = None
    cedula: Optional[str] = None


class TutorRegistroIntegral(BaseModel):
    nombre: str
    cedula: Optional[str] = None
    email: str
    id_parentesco: Optional[int] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    password: Optional[str] = None


class PacienteIdentidadRegistro(BaseModel):
    id: Optional[str] = None
    nombre_completo: str
    cedula: Optional[str] = None
    id_sexo: int
    id_canton: Optional[int] = None
    id_parroquia: Optional[int] = None
    fecha_nacimiento: date


class SaludRegistroIntegral(BaseModel):
    id_patologia_base: int
    peso_kg: Optional[Any] = None
    talla_cm: Optional[Any] = None
    articulaciones_inflamadas: Optional[Any] = None
    articulaciones_dolorosas: Optional[Any] = None
    minutos_rigidez: Optional[Any] = None
    puntos_dolor: Optional[int] = 0
    escala_inflamacion: Optional[int] = 0
    fatiga: Optional[int] = 10
    en_brote: Optional[bool] = False
    estado_enfermedad: Optional[str] = None
    observaciones: Optional[str] = None
    es_intolerante_lactosa: Optional[bool] = None
    restricciones_alimentarias: list[str] = Field(default_factory=list)
    alergias_subgrupos: list[int] = Field(default_factory=list)
    alergias_ingredientes: list[int] = Field(default_factory=list)
    condiciones_temporales: list[dict[str, Any]] = Field(default_factory=list)
    recomendaciones_ingredientes: list[int] = Field(default_factory=list)
    fecha_proxima_cita: Optional[date] = None


class SaludFijaUpdate(BaseModel):
    id_patologia_base: int
    peso_kg: Optional[Any] = None
    talla_cm: Optional[Any] = None
    articulaciones_inflamadas: Optional[Any] = None
    articulaciones_dolorosas: Optional[Any] = None
    minutos_rigidez: Optional[Any] = None
    puntos_dolor: Optional[int] = 0
    escala_inflamacion: Optional[int] = 0
    fatiga: Optional[int] = 10
    en_brote: Optional[bool] = False
    estado_enfermedad: Optional[str] = None
    observaciones: Optional[str] = None
    es_intolerante_lactosa: Optional[bool] = None
    restricciones_alimentarias: list[str] = Field(default_factory=list)
    alergias_subgrupos: list[int] = Field(default_factory=list)
    alergias_ingredientes: list[int] = Field(default_factory=list)
    condiciones_temporales: list[dict[str, Any]] = Field(default_factory=list)
    recomendaciones_ingredientes: list[int] = Field(default_factory=list)
    fecha_proxima_cita: Optional[date] = None


class RegistroPacienteIntegralRequest(BaseModel):
    tutor: TutorRegistroIntegral
    paciente: PacienteIdentidadRegistro
    salud: SaludRegistroIntegral


class ActualizarExpedienteFijoRequest(BaseModel):
    tutor: TutorRegistroIntegral
    paciente: PacienteIdentidadRegistro
    salud: SaludFijaUpdate
