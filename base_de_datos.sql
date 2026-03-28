-- =====================================================
-- EXTENSIONES
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- ESQUEMAS
-- =====================================================
CREATE SCHEMA IF NOT EXISTS seguridad;
CREATE SCHEMA IF NOT EXISTS usuarios;
CREATE SCHEMA IF NOT EXISTS clinico;
CREATE SCHEMA IF NOT EXISTS nutricion;
CREATE SCHEMA IF NOT EXISTS heuristico;
CREATE SCHEMA IF NOT EXISTS interaccion;
CREATE SCHEMA IF NOT EXISTS referencia;

-- =====================================================
-- 1. SEGURIDAD
-- =====================================================
CREATE TABLE seguridad.log_auditoria (
    id BIGSERIAL PRIMARY KEY,
    id_usuario UUID,
    accion VARCHAR(100) NOT NULL,
    esquema_afectado VARCHAR(100),
    tabla_afectada VARCHAR(100) NOT NULL,
    id_registro_afectado VARCHAR(100),
    detalle TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE seguridad.log_error (
    id BIGSERIAL PRIMARY KEY,
    modulo VARCHAR(100) NOT NULL,
    mensaje TEXT NOT NULL,
    stack_trace TEXT,
    payload JSONB,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. USUARIOS
-- =====================================================
CREATE TABLE usuarios.catalogo_sexo (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(5) UNIQUE NOT NULL,
    descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE usuarios.region_natural (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE usuarios.provincia (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_region INTEGER REFERENCES usuarios.region_natural(id)
);

CREATE TABLE usuarios.parentesco (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE usuarios.rol (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE usuarios.usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_rol INTEGER NOT NULL REFERENCES usuarios.rol(id),
    email VARCHAR(255) UNIQUE NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    telefono VARCHAR(30),
    direccion TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE usuarios.paciente (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_completo VARCHAR(200) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    id_sexo INTEGER NOT NULL REFERENCES usuarios.catalogo_sexo(id),
    id_provincia INTEGER REFERENCES usuarios.provincia(id),
    fecha_ultimo_control DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE usuarios.tutor_paciente (
    id BIGSERIAL PRIMARY KEY,
    id_usuario_tutor UUID NOT NULL REFERENCES usuarios.usuario(id),
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_parentesco INTEGER REFERENCES usuarios.parentesco(id),
    es_principal BOOLEAN DEFAULT FALSE,
    UNIQUE(id_usuario_tutor, id_paciente)
);

CREATE INDEX idx_tutor_paciente_tutor ON usuarios.tutor_paciente(id_usuario_tutor);
CREATE INDEX idx_tutor_paciente_paciente ON usuarios.tutor_paciente(id_paciente);

-- =====================================================
-- 3. REFERENCIAS OMS
-- =====================================================
CREATE TABLE referencia.indicador_antropometrico (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE referencia.oms_referencia (
    id BIGSERIAL PRIMARY KEY,
    id_indicador INTEGER NOT NULL REFERENCES referencia.indicador_antropometrico(id),
    id_sexo INTEGER NOT NULL REFERENCES usuarios.catalogo_sexo(id),
    meses INTEGER NOT NULL,
    l DECIMAL(12,6),
    m DECIMAL(12,6),
    s DECIMAL(12,6),
    sd5neg DECIMAL(12,6),
    sd4neg DECIMAL(12,6),
    sd3neg DECIMAL(12,6),
    sd2neg DECIMAL(12,6),
    sd1neg DECIMAL(12,6),
    sd0 DECIMAL(12,6),
    sd1 DECIMAL(12,6),
    sd2 DECIMAL(12,6),
    sd3 DECIMAL(12,6),
    sd4 DECIMAL(12,6),
    UNIQUE(id_indicador, id_sexo, meses)
);

-- =====================================================
-- 4. HEURISTICO
-- =====================================================
CREATE TABLE heuristico.catalogo_tipo_condicion (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(60) UNIQUE NOT NULL
);

CREATE TABLE heuristico.condicion (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    id_tipo_condicion INTEGER NOT NULL REFERENCES heuristico.catalogo_tipo_condicion(id),
    descripcion TEXT,
    activa BOOLEAN DEFAULT TRUE,
    UNIQUE(nombre, id_tipo_condicion)
);

CREATE TABLE heuristico.catalogo_accion (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    peso_puntaje INTEGER
);

CREATE TABLE heuristico.catalogo_objetivo_regla (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL
);

-- primero nutrición para respetar FKs de regla
-- =====================================================
-- 5. NUTRICION
-- =====================================================
CREATE TABLE nutricion.etiqueta_nutricional (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(60) UNIQUE NOT NULL,
    nombre_visible VARCHAR(120) NOT NULL
);

CREATE TABLE nutricion.grupo_alimentario (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(120) UNIQUE NOT NULL
);

CREATE TABLE nutricion.ingrediente (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    id_grupo_alimentario INTEGER REFERENCES nutricion.grupo_alimentario(id),
    imagen_url TEXT,
    id_region INTEGER REFERENCES usuarios.region_natural(id),
    es_basico BOOLEAN DEFAULT FALSE,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE nutricion.ingrediente_etiqueta (
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    id_etiqueta INTEGER NOT NULL REFERENCES nutricion.etiqueta_nutricional(id),
    PRIMARY KEY (id_ingrediente, id_etiqueta)
);

CREATE TABLE nutricion.nutriente (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    unidad_medida VARCHAR(20) NOT NULL
);

CREATE TABLE nutricion.ingrediente_nutriente (
    id BIGSERIAL PRIMARY KEY,
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    id_nutriente INTEGER NOT NULL REFERENCES nutricion.nutriente(id),
    valor_por_100g DECIMAL(12,4) NOT NULL,
    UNIQUE(id_ingrediente, id_nutriente)
);

CREATE TABLE nutricion.tipo_plato (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE nutricion.momento_comida (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    orden INTEGER
);

CREATE TABLE nutricion.receta (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    instrucciones_preparacion TEXT,
    porciones INTEGER DEFAULT 1,
    calorias_totales DECIMAL(12,2),
    score_antiinflamatorio INTEGER,
    id_provincia_origen INTEGER REFERENCES usuarios.provincia(id),
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE nutricion.receta_imagen (
    id BIGSERIAL PRIMARY KEY,
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    imagen_url TEXT NOT NULL,
    orden INTEGER DEFAULT 1
);

CREATE TABLE nutricion.receta_momento (
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    id_momento INTEGER NOT NULL REFERENCES nutricion.momento_comida(id),
    PRIMARY KEY (id_receta, id_momento)
);

CREATE TABLE nutricion.receta_tipo_plato (
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    id_tipo_plato INTEGER NOT NULL REFERENCES nutricion.tipo_plato(id),
    PRIMARY KEY (id_receta, id_tipo_plato)
);

CREATE TABLE nutricion.receta_ingrediente (
    id BIGSERIAL PRIMARY KEY,
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    cantidad_visual DECIMAL(10,2),
    unidad_visual VARCHAR(50),
    peso_en_gramos DECIMAL(10,2) NOT NULL,
    es_principal BOOLEAN DEFAULT FALSE
);

CREATE TABLE nutricion.sustituto_ingrediente (
    id BIGSERIAL PRIMARY KEY,
    id_ingrediente_original INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    id_ingrediente_reemplazo INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    ratio_conversion DECIMAL(10,4) DEFAULT 1.0,
    mensaje_aviso TEXT,
    UNIQUE(id_ingrediente_original, id_ingrediente_reemplazo)
);

-- ahora sí reglas
CREATE TABLE heuristico.regla (
    id BIGSERIAL PRIMARY KEY,
    id_accion INTEGER NOT NULL REFERENCES heuristico.catalogo_accion(id),
    id_tipo_objetivo INTEGER NOT NULL REFERENCES heuristico.catalogo_objetivo_regla(id),
    id_ingrediente INTEGER REFERENCES nutricion.ingrediente(id),
    id_grupo_alimentario INTEGER REFERENCES nutricion.grupo_alimentario(id),
    id_etiqueta INTEGER REFERENCES nutricion.etiqueta_nutricional(id),
    mensaje_error TEXT,
    origen_regla VARCHAR(20) NOT NULL,
    created_by UUID REFERENCES usuarios.usuario(id),
    created_at TIMESTAMP DEFAULT NOW(),
    CHECK (
        (id_ingrediente IS NOT NULL)::int +
        (id_grupo_alimentario IS NOT NULL)::int +
        (id_etiqueta IS NOT NULL)::int = 1
    )
);

CREATE TABLE heuristico.condicion_regla (
    id BIGSERIAL PRIMARY KEY,
    id_condicion INTEGER NOT NULL REFERENCES heuristico.condicion(id),
    id_regla BIGINT NOT NULL REFERENCES heuristico.regla(id),
    UNIQUE(id_condicion, id_regla)
);

-- =====================================================
-- 6. CLINICO
-- =====================================================
CREATE TABLE clinico.diagnostico_paciente (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_condicion INTEGER NOT NULL REFERENCES heuristico.condicion(id),
    fecha_diagnostico DATE DEFAULT CURRENT_DATE,
    es_cronico BOOLEAN DEFAULT TRUE,
    activa BOOLEAN DEFAULT TRUE,
    UNIQUE(id_paciente, id_condicion, fecha_diagnostico)
);

CREATE TABLE clinico.control_paciente (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    fecha_control DATE NOT NULL DEFAULT CURRENT_DATE,
    peso_kg DECIMAL(6,2) NOT NULL,
    talla_cm DECIMAL(6,2) NOT NULL,
    edad_meses INTEGER NOT NULL,
    imc_calculado DECIMAL(8,4),
    id_condicion_nutricional_resultado INTEGER REFERENCES heuristico.condicion(id),
    diagnostico_oms_texto VARCHAR(150),
    nivel_dolor_eva INTEGER,
    nivel_inflamacion INTEGER,
    nivel_fatiga INTEGER,
    minutos_rigidez_matutina INTEGER,
    inflamacion_pcr DECIMAL(10,2),
    hay_brote_activo BOOLEAN,
    nota_evolucion TEXT
);

CREATE INDEX idx_control_paciente_fecha ON clinico.control_paciente(id_paciente, fecha_control DESC);

CREATE TABLE clinico.control_condicion_activa (
    id BIGSERIAL PRIMARY KEY,
    id_control BIGINT NOT NULL REFERENCES clinico.control_paciente(id),
    id_condicion INTEGER NOT NULL REFERENCES heuristico.condicion(id),
    UNIQUE(id_control, id_condicion)
);

CREATE TABLE clinico.alergia_paciente_ingrediente (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    fecha_registro DATE DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT TRUE,
    observacion TEXT,
    UNIQUE(id_paciente, id_ingrediente)
);

CREATE TABLE clinico.alergia_paciente_grupo (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_grupo_alimentario INTEGER NOT NULL REFERENCES nutricion.grupo_alimentario(id),
    fecha_registro DATE DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT TRUE,
    observacion TEXT,
    UNIQUE(id_paciente, id_grupo_alimentario)
);

-- =====================================================
-- 7. INTERACCION
-- =====================================================
CREATE TABLE interaccion.catalogo_estado_plan (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE interaccion.catalogo_tipo_plan (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE interaccion.catalogo_origen_plan (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE interaccion.plan_nutricional (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_tipo_plan INTEGER NOT NULL REFERENCES interaccion.catalogo_tipo_plan(id),
    id_origen_plan INTEGER NOT NULL REFERENCES interaccion.catalogo_origen_plan(id),
    id_estado_plan INTEGER NOT NULL REFERENCES interaccion.catalogo_estado_plan(id),
    es_plantilla BOOLEAN DEFAULT FALSE,
    comidas_por_dia INTEGER NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    creado_por UUID REFERENCES usuarios.usuario(id),
    vigente BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE interaccion.plan_item (
    id BIGSERIAL PRIMARY KEY,
    id_plan BIGINT NOT NULL REFERENCES interaccion.plan_nutricional(id),
    fecha_programada DATE NOT NULL,
    id_momento INTEGER NOT NULL REFERENCES nutricion.momento_comida(id),
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    energia_objetivo_kcal DECIMAL(12,2),
    proteina_objetivo_g DECIMAL(12,2)
);

CREATE TABLE interaccion.catalogo_estado_consumo (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE interaccion.seguimiento_plan_item (
    id BIGSERIAL PRIMARY KEY,
    id_plan_item BIGINT NOT NULL REFERENCES interaccion.plan_item(id),
    id_estado_consumo INTEGER NOT NULL REFERENCES interaccion.catalogo_estado_consumo(id),
    id_receta_reemplazo INTEGER REFERENCES nutricion.receta(id),
    fecha_consumo TIMESTAMP,
    observacion TEXT
);

CREATE TABLE interaccion.catalogo_motivo_rechazo (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE interaccion.recomendacion_puntual (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_momento INTEGER REFERENCES nutricion.momento_comida(id),
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    fecha_solicitud TIMESTAMP DEFAULT NOW(),
    resultado_consumo VARCHAR(20),
    calificacion_estrellas INTEGER,
    id_motivo_rechazo INTEGER REFERENCES interaccion.catalogo_motivo_rechazo(id)
);

CREATE TABLE interaccion.evaluacion_receta (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    estrellas INTEGER NOT NULL,
    comentario TEXT,
    id_motivo_rechazo INTEGER REFERENCES interaccion.catalogo_motivo_rechazo(id),
    origen_evaluacion VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE interaccion.preferencia_receta (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    puntaje_ajuste DECIMAL(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT NOW(),
    UNIQUE(id_paciente, id_receta)
);

CREATE TABLE interaccion.preferencia_ingrediente (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    puntaje_ajuste DECIMAL(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT NOW(),
    UNIQUE(id_paciente, id_ingrediente)
);