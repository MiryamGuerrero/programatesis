-- =====================================================
-- REUMA NUTRI - ESQUEMA SINCRONIZADO DESDE SUPABASE
-- Generado automaticamente: 2026-03-30 23:37:39Z
-- Incluye: tablas, columnas, constraints e indices
-- =====================================================

-- =====================================================
-- EXTENSIONES
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ESQUEMAS
-- =====================================================
CREATE SCHEMA IF NOT EXISTS dom_auditoria_seguridad;
CREATE SCHEMA IF NOT EXISTS dom_clinica_alergias;
CREATE SCHEMA IF NOT EXISTS dom_clinica_controles;
CREATE SCHEMA IF NOT EXISTS dom_clinica_diagnosticos;
CREATE SCHEMA IF NOT EXISTS dom_clinica_objetivos;
CREATE SCHEMA IF NOT EXISTS dom_compras;
CREATE SCHEMA IF NOT EXISTS dom_experiencia_usuario;
CREATE SCHEMA IF NOT EXISTS dom_identidad_catalogos;
CREATE SCHEMA IF NOT EXISTS dom_identidad_usuarios;
CREATE SCHEMA IF NOT EXISTS dom_nutricion_catalogos;
CREATE SCHEMA IF NOT EXISTS dom_nutricion_ingrediente_rel;
CREATE SCHEMA IF NOT EXISTS dom_nutricion_ingredientes;
CREATE SCHEMA IF NOT EXISTS dom_planes_base;
CREATE SCHEMA IF NOT EXISTS dom_planes_catalogos_estado;
CREATE SCHEMA IF NOT EXISTS dom_planes_catalogos_tipo;
CREATE SCHEMA IF NOT EXISTS dom_planes_permitidos;
CREATE SCHEMA IF NOT EXISTS dom_planes_reemplazos;
CREATE SCHEMA IF NOT EXISTS dom_recetas_analitica;
CREATE SCHEMA IF NOT EXISTS dom_recetas_base;
CREATE SCHEMA IF NOT EXISTS dom_recetas_composicion;
CREATE SCHEMA IF NOT EXISTS dom_referencia_oms;
CREATE SCHEMA IF NOT EXISTS dom_reglas_catalogos;
CREATE SCHEMA IF NOT EXISTS dom_reglas_motor;
CREATE SCHEMA IF NOT EXISTS dom_territorio_catalogos;
CREATE SCHEMA IF NOT EXISTS dom_tutor_acompanamiento;

-- =====================================================
-- TABLAS
-- =====================================================
CREATE TABLE dom_auditoria_seguridad.log_auditoria (
    id BIGSERIAL NOT NULL,
    id_usuario UUID,
    accion VARCHAR(100) NOT NULL,
    esquema_afectado VARCHAR(100),
    tabla_afectada VARCHAR(100) NOT NULL,
    id_registro_afectado VARCHAR(100),
    detalle TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dom_auditoria_seguridad.log_error (
    id BIGSERIAL NOT NULL,
    modulo VARCHAR(100) NOT NULL,
    mensaje TEXT NOT NULL,
    stack_trace TEXT,
    payload JSONB,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dom_clinica_alergias.alergia_paciente_grupo (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_grupo_alimentario INTEGER NOT NULL,
    fecha_registro DATE DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT true,
    observacion TEXT
);

CREATE TABLE dom_clinica_alergias.alergia_paciente_ingrediente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    fecha_registro DATE DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT true,
    observacion TEXT
);

CREATE TABLE dom_clinica_controles.control_condicion_activa (
    id BIGSERIAL NOT NULL,
    id_control BIGINT NOT NULL,
    id_condicion INTEGER NOT NULL
);

CREATE TABLE dom_clinica_controles.control_paciente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    fecha_control DATE DEFAULT CURRENT_DATE NOT NULL,
    peso_kg NUMERIC(6,2) NOT NULL,
    talla_cm NUMERIC(6,2) NOT NULL,
    edad_meses INTEGER NOT NULL,
    imc_calculado NUMERIC(8,4),
    id_condicion_nutricional_resultado INTEGER,
    diagnostico_oms_texto VARCHAR(150),
    nivel_dolor_eva INTEGER,
    nivel_inflamacion INTEGER,
    nivel_fatiga INTEGER,
    minutos_rigidez_matutina INTEGER,
    inflamacion_pcr NUMERIC(10,2),
    hay_brote_activo BOOLEAN,
    nota_evolucion TEXT,
    id_usuario_registra UUID,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_clinica_diagnosticos.diagnostico_paciente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_condicion INTEGER NOT NULL,
    fecha_diagnostico DATE DEFAULT CURRENT_DATE,
    es_cronico BOOLEAN DEFAULT true,
    activa BOOLEAN DEFAULT true
);

CREATE TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente (
    id BIGSERIAL NOT NULL,
    id_objetivo BIGINT NOT NULL,
    id_nutriente INTEGER NOT NULL,
    valor_minimo NUMERIC(12,4),
    valor_objetivo NUMERIC(12,4),
    valor_maximo NUMERIC(12,4),
    unidad_objetivo VARCHAR(20),
    obligatorio BOOLEAN DEFAULT false NOT NULL,
    observacion TEXT
);

CREATE TABLE dom_clinica_objetivos.objetivo_nutricional_paciente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_control_base BIGINT NOT NULL,
    origen_calculo VARCHAR(20) DEFAULT 'SISTEMA'::character varying NOT NULL,
    estado VARCHAR(20) DEFAULT 'VIGENTE'::character varying NOT NULL,
    validado_medico BOOLEAN DEFAULT false NOT NULL,
    id_usuario_medico_valida UUID,
    fecha_validacion_medica TIMESTAMP,
    ajustado_nutricionista BOOLEAN DEFAULT false NOT NULL,
    id_usuario_nutricionista_ajusta UUID,
    fecha_ajuste_nutricionista TIMESTAMP,
    observacion TEXT,
    vigente BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion (
    id BIGSERIAL NOT NULL,
    id_objetivo BIGINT NOT NULL,
    tipo_accion VARCHAR(20) NOT NULL,
    id_ingrediente INTEGER,
    id_grupo_alimentario INTEGER,
    id_etiqueta INTEGER,
    fecha_inicio DATE,
    fecha_fin DATE,
    motivo TEXT,
    created_by UUID,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_compras.lista_compra (
    id BIGSERIAL NOT NULL,
    id_plan BIGINT NOT NULL,
    id_paciente UUID NOT NULL,
    id_usuario_genera UUID,
    estado VARCHAR(20) DEFAULT 'ABIERTA'::character varying NOT NULL,
    costo_total_estimado NUMERIC(10,2),
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_compras.lista_compra_item (
    id BIGSERIAL NOT NULL,
    id_lista_compra BIGINT NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    cantidad_total_g NUMERIC(12,2) NOT NULL,
    unidad_visual VARCHAR(50),
    comprado BOOLEAN DEFAULT false NOT NULL,
    cantidad_comprada_g NUMERIC(12,2),
    fecha_marcado TIMESTAMP,
    id_usuario_marca UUID,
    costo_estimado NUMERIC(10,2),
    observacion TEXT
);

CREATE TABLE dom_experiencia_usuario.evaluacion_receta (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_receta INTEGER NOT NULL,
    estrellas INTEGER NOT NULL,
    comentario TEXT,
    id_motivo_rechazo INTEGER,
    origen_evaluacion VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE dom_experiencia_usuario.preferencia_ingrediente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    puntaje_ajuste NUMERIC(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT now()
);

CREATE TABLE dom_experiencia_usuario.preferencia_receta (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_receta INTEGER NOT NULL,
    puntaje_ajuste NUMERIC(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT now()
);

CREATE TABLE dom_identidad_catalogos.catalogo_sexo (
    id SERIAL NOT NULL,
    codigo VARCHAR(5) NOT NULL,
    descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE dom_identidad_catalogos.parentesco (
    id SERIAL NOT NULL,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE dom_identidad_catalogos.rol (
    id SERIAL NOT NULL,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE dom_identidad_usuarios.paciente (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    id_sexo INTEGER NOT NULL,
    id_provincia INTEGER,
    fecha_ultimo_control DATE,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE dom_identidad_usuarios.tutor_paciente (
    id BIGSERIAL NOT NULL,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    id_parentesco INTEGER,
    es_principal BOOLEAN DEFAULT false
);

CREATE TABLE dom_identidad_usuarios.usuario (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    id_rol INTEGER NOT NULL,
    email VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    telefono VARCHAR(30),
    direccion TEXT,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE dom_nutricion_catalogos.etiqueta_nutricional (
    id SERIAL NOT NULL,
    codigo VARCHAR(60) NOT NULL,
    nombre_visible VARCHAR(120) NOT NULL
);

CREATE TABLE dom_nutricion_catalogos.grupo_alimentario (
    id SERIAL NOT NULL,
    nombre VARCHAR(120) NOT NULL
);

CREATE TABLE dom_nutricion_catalogos.momento_comida (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    orden INTEGER
);

CREATE TABLE dom_nutricion_catalogos.nutriente (
    id SERIAL NOT NULL,
    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    unidad_medida VARCHAR(20) NOT NULL,
    categoria VARCHAR(20) DEFAULT 'OTRO'::character varying NOT NULL,
    activo BOOLEAN DEFAULT true NOT NULL,
    orden_reporte INTEGER
);

CREATE TABLE dom_nutricion_catalogos.tipo_plato (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE dom_nutricion_ingrediente_rel.ingrediente_etiqueta (
    id_ingrediente INTEGER NOT NULL,
    id_etiqueta INTEGER NOT NULL
);

CREATE TABLE dom_nutricion_ingrediente_rel.ingrediente_nutriente (
    id BIGSERIAL NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    id_nutriente INTEGER NOT NULL,
    valor_por_100g NUMERIC(12,4) NOT NULL
);

CREATE TABLE dom_nutricion_ingredientes.ingrediente (
    id SERIAL NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    id_grupo_alimentario INTEGER,
    imagen_url TEXT,
    id_region INTEGER,
    es_basico BOOLEAN DEFAULT false,
    activo BOOLEAN DEFAULT true,
    costo_estimado_por_100g NUMERIC(10,2),
    moneda_costo VARCHAR(3) DEFAULT 'PEN'::character varying NOT NULL
);

CREATE TABLE dom_nutricion_ingredientes.ingrediente_sinonimo (
    id BIGSERIAL NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    nombre_sinonimo VARCHAR(150) NOT NULL,
    activo BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_planes_base.plan_item (
    id BIGSERIAL NOT NULL,
    id_plan BIGINT NOT NULL,
    fecha_programada DATE NOT NULL,
    id_momento INTEGER NOT NULL,
    id_receta INTEGER NOT NULL,
    energia_objetivo_kcal NUMERIC(12,2),
    proteina_objetivo_g NUMERIC(12,2)
);

CREATE TABLE dom_planes_base.plan_nutricional (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_tipo_plan INTEGER NOT NULL,
    id_origen_plan INTEGER NOT NULL,
    id_estado_plan INTEGER NOT NULL,
    es_plantilla BOOLEAN DEFAULT false,
    comidas_por_dia INTEGER NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    creado_por UUID,
    vigente BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now(),
    id_objetivo_nutricional BIGINT,
    id_contexto_recetas BIGINT,
    nota_plan TEXT
);

CREATE TABLE dom_planes_base.recomendacion_puntual (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_momento INTEGER,
    id_receta INTEGER NOT NULL,
    fecha_solicitud TIMESTAMP DEFAULT now(),
    resultado_consumo VARCHAR(20),
    calificacion_estrellas INTEGER,
    id_motivo_rechazo INTEGER,
    id_objetivo_nutricional BIGINT,
    id_contexto_recetas BIGINT,
    id_control_base BIGINT
);

CREATE TABLE dom_planes_base.seguimiento_plan_item (
    id BIGSERIAL NOT NULL,
    id_plan_item BIGINT NOT NULL,
    id_estado_consumo INTEGER NOT NULL,
    id_receta_reemplazo INTEGER,
    fecha_consumo TIMESTAMP,
    observacion TEXT,
    id_usuario_registra UUID,
    id_plan_item_reemplazo BIGINT
);

CREATE TABLE dom_planes_catalogos_estado.catalogo_estado_consumo (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE dom_planes_catalogos_estado.catalogo_estado_plan (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE dom_planes_catalogos_estado.catalogo_motivo_rechazo (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE dom_planes_catalogos_tipo.catalogo_nivel_actividad (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    descripcion VARCHAR(120)
);

CREATE TABLE dom_planes_catalogos_tipo.catalogo_origen_plan (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE dom_planes_catalogos_tipo.catalogo_tipo_plan (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE dom_planes_permitidos.receta_permitida_contexto (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_control_base BIGINT,
    id_objetivo_nutricional BIGINT,
    id_nivel_actividad INTEGER,
    agua_ml_referencia INTEGER,
    hay_brote_activo BOOLEAN,
    origen VARCHAR(20) DEFAULT 'SISTEMA'::character varying NOT NULL,
    vigente BOOLEAN DEFAULT true NOT NULL,
    created_by UUID,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_planes_permitidos.receta_permitida_item (
    id BIGSERIAL NOT NULL,
    id_contexto BIGINT NOT NULL,
    id_receta INTEGER NOT NULL,
    estado VARCHAR(20) DEFAULT 'PERMITIDA'::character varying NOT NULL,
    puntaje_prioridad NUMERIC(10,4) DEFAULT 0 NOT NULL,
    motivo JSONB,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_planes_reemplazos.plan_item_reemplazo (
    id BIGSERIAL NOT NULL,
    id_plan_item BIGINT NOT NULL,
    id_receta_original INTEGER NOT NULL,
    id_receta_reemplazo INTEGER NOT NULL,
    id_usuario_tutor UUID NOT NULL,
    id_regla_equivalencia BIGINT,
    motivo TEXT,
    vigente BOOLEAN DEFAULT true NOT NULL,
    fecha_reemplazo TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_recetas_analitica.receta_nutriente_resumen (
    id BIGSERIAL NOT NULL,
    id_receta INTEGER NOT NULL,
    id_nutriente INTEGER NOT NULL,
    valor_por_receta NUMERIC(12,4) NOT NULL,
    valor_por_porcion NUMERIC(12,4),
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_recetas_analitica.receta_reemplazo_equivalente (
    id BIGSERIAL NOT NULL,
    id_receta_origen INTEGER NOT NULL,
    id_receta_reemplazo INTEGER NOT NULL,
    id_momento_origen INTEGER NOT NULL,
    id_momento_reemplazo INTEGER NOT NULL,
    similitud_nutricional_pct NUMERIC(5,2) DEFAULT 0 NOT NULL,
    variacion_kcal_pct NUMERIC(6,2),
    variacion_proteina_pct NUMERIC(6,2),
    prioridad SMALLINT DEFAULT 100 NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL,
    observacion TEXT,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_recetas_base.receta (
    id SERIAL NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    instrucciones_preparacion TEXT,
    porciones INTEGER DEFAULT 1,
    calorias_totales NUMERIC(12,2),
    score_antiinflamatorio INTEGER,
    id_provincia_origen INTEGER,
    activa BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now(),
    costo_estimado_total NUMERIC(10,2),
    agua_ml_por_porcion NUMERIC(10,2)
);

CREATE TABLE dom_recetas_base.receta_imagen (
    id BIGSERIAL NOT NULL,
    id_receta INTEGER NOT NULL,
    imagen_url TEXT NOT NULL,
    orden INTEGER DEFAULT 1
);

CREATE TABLE dom_recetas_composicion.momento_compatible (
    id_momento_origen INTEGER NOT NULL,
    id_momento_compatible INTEGER NOT NULL
);

CREATE TABLE dom_recetas_composicion.receta_ingrediente (
    id BIGSERIAL NOT NULL,
    id_receta INTEGER NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    cantidad_visual NUMERIC(10,2),
    unidad_visual VARCHAR(50),
    peso_en_gramos NUMERIC(10,2) NOT NULL,
    es_principal BOOLEAN DEFAULT false
);

CREATE TABLE dom_recetas_composicion.receta_momento (
    id_receta INTEGER NOT NULL,
    id_momento INTEGER NOT NULL
);

CREATE TABLE dom_recetas_composicion.receta_tipo_plato (
    id_receta INTEGER NOT NULL,
    id_tipo_plato INTEGER NOT NULL
);

CREATE TABLE dom_recetas_composicion.sustituto_ingrediente (
    id BIGSERIAL NOT NULL,
    id_ingrediente_original INTEGER NOT NULL,
    id_ingrediente_reemplazo INTEGER NOT NULL,
    ratio_conversion NUMERIC(10,4) DEFAULT 1.0,
    mensaje_aviso TEXT
);

CREATE TABLE dom_referencia_oms.indicador_antropometrico (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE dom_referencia_oms.oms_referencia_percentil (
    id BIGSERIAL NOT NULL,
    id_indicador INTEGER NOT NULL,
    id_sexo INTEGER NOT NULL,
    edad_meses INTEGER NOT NULL,
    l NUMERIC(12,6) NOT NULL,
    m NUMERIC(12,6) NOT NULL,
    s NUMERIC(12,6) NOT NULL,
    stdev NUMERIC(12,6),
    p01 NUMERIC(12,6) NOT NULL,
    p1 NUMERIC(12,6) NOT NULL,
    p3 NUMERIC(12,6) NOT NULL,
    p5 NUMERIC(12,6) NOT NULL,
    p10 NUMERIC(12,6) NOT NULL,
    p15 NUMERIC(12,6) NOT NULL,
    p25 NUMERIC(12,6) NOT NULL,
    p50 NUMERIC(12,6) NOT NULL,
    p75 NUMERIC(12,6) NOT NULL,
    p85 NUMERIC(12,6) NOT NULL,
    p90 NUMERIC(12,6) NOT NULL,
    p95 NUMERIC(12,6) NOT NULL,
    p97 NUMERIC(12,6) NOT NULL,
    p99 NUMERIC(12,6) NOT NULL,
    p999 NUMERIC(12,6) NOT NULL
);

CREATE TABLE dom_referencia_oms.oms_referencia_zscore (
    id BIGSERIAL NOT NULL,
    id_indicador INTEGER NOT NULL,
    id_sexo INTEGER NOT NULL,
    edad_meses INTEGER NOT NULL,
    l NUMERIC(12,6) NOT NULL,
    m NUMERIC(12,6) NOT NULL,
    s NUMERIC(12,6) NOT NULL,
    sd4neg NUMERIC(12,6) NOT NULL,
    sd3neg NUMERIC(12,6) NOT NULL,
    sd2neg NUMERIC(12,6) NOT NULL,
    sd1neg NUMERIC(12,6) NOT NULL,
    sd0 NUMERIC(12,6) NOT NULL,
    sd1 NUMERIC(12,6) NOT NULL,
    sd2 NUMERIC(12,6) NOT NULL,
    sd3 NUMERIC(12,6) NOT NULL,
    sd4 NUMERIC(12,6) NOT NULL
);

CREATE TABLE dom_reglas_catalogos.catalogo_accion (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    peso_puntaje INTEGER,
    activo BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE dom_reglas_catalogos.catalogo_objetivo_regla (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE dom_reglas_catalogos.catalogo_tipo_condicion (
    id SERIAL NOT NULL,
    nombre VARCHAR(60) NOT NULL
);

CREATE TABLE dom_reglas_motor.condicion (
    id SERIAL NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    id_tipo_condicion INTEGER NOT NULL,
    descripcion TEXT,
    activa BOOLEAN DEFAULT true
);

CREATE TABLE dom_reglas_motor.condicion_regla (
    id BIGSERIAL NOT NULL,
    id_condicion INTEGER NOT NULL,
    id_regla BIGINT NOT NULL
);

CREATE TABLE dom_reglas_motor.regla (
    id BIGSERIAL NOT NULL,
    id_accion INTEGER NOT NULL,
    id_tipo_objetivo INTEGER NOT NULL,
    id_ingrediente INTEGER,
    id_grupo_alimentario INTEGER,
    id_etiqueta INTEGER,
    mensaje_error TEXT,
    origen_regla VARCHAR(20) NOT NULL,
    created_by UUID,
    created_at TIMESTAMP DEFAULT now(),
    activo BOOLEAN DEFAULT true NOT NULL,
    aplica_brote VARCHAR(20) DEFAULT 'AMBOS'::character varying NOT NULL,
    fecha_inicio_vigencia DATE,
    fecha_fin_vigencia DATE,
    prioridad_manual SMALLINT
);

CREATE TABLE dom_territorio_catalogos.provincia (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    id_region INTEGER
);

CREATE TABLE dom_territorio_catalogos.region_natural (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE dom_tutor_acompanamiento.nota_tutor_paciente (
    id BIGSERIAL NOT NULL,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    id_plan BIGINT,
    id_plan_item BIGINT,
    nota TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_tutor_acompanamiento.perfil_apoyo_tutor_paciente (
    id BIGSERIAL NOT NULL,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    id_nivel_actividad_actual INTEGER NOT NULL,
    meta_agua_diaria_ml INTEGER,
    notas TEXT,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE dom_tutor_acompanamiento.registro_apoyo_diario (
    id BIGSERIAL NOT NULL,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    fecha_registro DATE DEFAULT CURRENT_DATE NOT NULL,
    id_nivel_actividad INTEGER,
    minutos_actividad INTEGER,
    agua_ml INTEGER,
    nota TEXT,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

-- =====================================================
-- VISTAS
-- =====================================================
-- =====================================================
-- CONSTRAINTS
-- =====================================================
ALTER TABLE dom_auditoria_seguridad.log_auditoria
    ADD CONSTRAINT log_auditoria_pkey PRIMARY KEY (id);

ALTER TABLE dom_auditoria_seguridad.log_error
    ADD CONSTRAINT log_error_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_alergias.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_alergias.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_id_paciente_id_grupo_alimentario_key UNIQUE (id_paciente, id_grupo_alimentario);

ALTER TABLE dom_clinica_alergias.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES dom_nutricion_catalogos.grupo_alimentario(id);

ALTER TABLE dom_clinica_alergias.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_clinica_alergias.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_alergias.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_id_paciente_id_ingrediente_key UNIQUE (id_paciente, id_ingrediente);

ALTER TABLE dom_clinica_alergias.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_clinica_alergias.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_clinica_controles.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_controles.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_id_control_id_condicion_key UNIQUE (id_control, id_condicion);

ALTER TABLE dom_clinica_controles.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_id_condicion_fkey FOREIGN KEY (id_condicion) REFERENCES dom_reglas_motor.condicion(id);

ALTER TABLE dom_clinica_controles.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_id_control_fkey FOREIGN KEY (id_control) REFERENCES dom_clinica_controles.control_paciente(id);

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT control_paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_edad_meses_rango CHECK (edad_meses >= 0 AND edad_meses <= 240) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_nivel_dolor CHECK (nivel_dolor_eva IS NULL OR nivel_dolor_eva >= 0 AND nivel_dolor_eva <= 10) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_nivel_fatiga CHECK (nivel_fatiga IS NULL OR nivel_fatiga >= 0 AND nivel_fatiga <= 10) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_nivel_inflamacion CHECK (nivel_inflamacion IS NULL OR nivel_inflamacion >= 0 AND nivel_inflamacion <= 10) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_pcr_no_negativa CHECK (inflamacion_pcr IS NULL OR inflamacion_pcr >= 0::numeric) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_peso_positivo CHECK (peso_kg > 0::numeric) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_rigidez_no_negativa CHECK (minutos_rigidez_matutina IS NULL OR minutos_rigidez_matutina >= 0) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT ck_control_talla_positiva CHECK (talla_cm > 0::numeric) NOT VALID;

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT control_paciente_id_condicion_nutricional_resultado_fkey FOREIGN KEY (id_condicion_nutricional_resultado) REFERENCES dom_reglas_motor.condicion(id);

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT control_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_clinica_controles.control_paciente
    ADD CONSTRAINT control_paciente_id_usuario_registra_fkey FOREIGN KEY (id_usuario_registra) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_clinica_diagnosticos.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_diagnosticos.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_id_paciente_id_condicion_fecha_diagnos_key UNIQUE (id_paciente, id_condicion, fecha_diagnostico);

ALTER TABLE dom_clinica_diagnosticos.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_id_condicion_fkey FOREIGN KEY (id_condicion) REFERENCES dom_reglas_motor.condicion(id);

ALTER TABLE dom_clinica_diagnosticos.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_id_objetivo_id_nutriente_key UNIQUE (id_objetivo, id_nutriente);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_check CHECK (COALESCE(valor_minimo, valor_objetivo, valor_maximo) IS NOT NULL);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_check1 CHECK (valor_minimo IS NULL OR valor_maximo IS NULL OR valor_minimo <= valor_maximo);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_check2 CHECK (valor_objetivo IS NULL OR valor_minimo IS NULL OR valor_objetivo >= valor_minimo);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_check3 CHECK (valor_objetivo IS NULL OR valor_maximo IS NULL OR valor_objetivo <= valor_maximo);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_valor_maximo_check CHECK (valor_maximo IS NULL OR valor_maximo >= 0::numeric);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_valor_minimo_check CHECK (valor_minimo IS NULL OR valor_minimo >= 0::numeric);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_valor_objetivo_check CHECK (valor_objetivo IS NULL OR valor_objetivo >= 0::numeric);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_id_nutriente_fkey FOREIGN KEY (id_nutriente) REFERENCES dom_nutricion_catalogos.nutriente(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_nutriente
    ADD CONSTRAINT objetivo_nutricional_nutriente_id_objetivo_fkey FOREIGN KEY (id_objetivo) REFERENCES dom_clinica_objetivos.objetivo_nutricional_paciente(id) ON DELETE CASCADE;

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_check CHECK (NOT validado_medico OR id_usuario_medico_valida IS NOT NULL);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_check1 CHECK (NOT ajustado_nutricionista OR id_usuario_nutricionista_ajusta IS NOT NULL);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_estado_check CHECK (upper(estado::text) = ANY (ARRAY['BORRADOR'::text, 'VIGENTE'::text, 'CERRADO'::text]));

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_origen_calculo_check CHECK (upper(origen_calculo::text) = ANY (ARRAY['SISTEMA'::text, 'MEDICO'::text, 'NUTRICIONISTA'::text]));

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_id_control_base_fkey FOREIGN KEY (id_control_base) REFERENCES dom_clinica_controles.control_paciente(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_id_usuario_medico_valida_fkey FOREIGN KEY (id_usuario_medico_valida) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_paciente
    ADD CONSTRAINT objetivo_nutricional_paciente_id_usuario_nutricionista_aju_fkey FOREIGN KEY (id_usuario_nutricionista_ajusta) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_pkey PRIMARY KEY (id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_check CHECK (((id_ingrediente IS NOT NULL)::integer + (id_grupo_alimentario IS NOT NULL)::integer + (id_etiqueta IS NOT NULL)::integer) = 1);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_check1 CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_tipo_accion_check CHECK (upper(tipo_accion::text) = ANY (ARRAY['ELIMINAR'::text, 'DISMINUIR'::text, 'PRIORIZAR'::text]));

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_created_by_fkey FOREIGN KEY (created_by) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES dom_nutricion_catalogos.etiqueta_nutricional(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES dom_nutricion_catalogos.grupo_alimentario(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_clinica_objetivos.objetivo_nutricional_restriccion
    ADD CONSTRAINT objetivo_nutricional_restriccion_id_objetivo_fkey FOREIGN KEY (id_objetivo) REFERENCES dom_clinica_objetivos.objetivo_nutricional_paciente(id) ON DELETE CASCADE;

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_pkey PRIMARY KEY (id);

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_id_plan_key UNIQUE (id_plan);

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_costo_total_estimado_check CHECK (costo_total_estimado IS NULL OR costo_total_estimado >= 0::numeric);

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_estado_check CHECK (upper(estado::text) = ANY (ARRAY['ABIERTA'::text, 'CERRADA'::text]));

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_id_plan_fkey FOREIGN KEY (id_plan) REFERENCES dom_planes_base.plan_nutricional(id) ON DELETE CASCADE;

ALTER TABLE dom_compras.lista_compra
    ADD CONSTRAINT lista_compra_id_usuario_genera_fkey FOREIGN KEY (id_usuario_genera) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_pkey PRIMARY KEY (id);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_id_lista_compra_id_ingrediente_key UNIQUE (id_lista_compra, id_ingrediente);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_cantidad_comprada_g_check CHECK (cantidad_comprada_g IS NULL OR cantidad_comprada_g >= 0::numeric);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_cantidad_total_g_check CHECK (cantidad_total_g >= 0::numeric);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_costo_estimado_check CHECK (costo_estimado IS NULL OR costo_estimado >= 0::numeric);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_id_lista_compra_fkey FOREIGN KEY (id_lista_compra) REFERENCES dom_compras.lista_compra(id) ON DELETE CASCADE;

ALTER TABLE dom_compras.lista_compra_item
    ADD CONSTRAINT lista_compra_item_id_usuario_marca_fkey FOREIGN KEY (id_usuario_marca) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_experiencia_usuario.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_pkey PRIMARY KEY (id);

ALTER TABLE dom_experiencia_usuario.evaluacion_receta
    ADD CONSTRAINT ck_evaluacion_estrellas_rango CHECK (estrellas >= 1 AND estrellas <= 5) NOT VALID;

ALTER TABLE dom_experiencia_usuario.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_id_motivo_rechazo_fkey FOREIGN KEY (id_motivo_rechazo) REFERENCES dom_planes_catalogos_estado.catalogo_motivo_rechazo(id);

ALTER TABLE dom_experiencia_usuario.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_experiencia_usuario.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_experiencia_usuario.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE dom_experiencia_usuario.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_id_paciente_id_ingrediente_key UNIQUE (id_paciente, id_ingrediente);

ALTER TABLE dom_experiencia_usuario.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_experiencia_usuario.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_experiencia_usuario.preferencia_receta
    ADD CONSTRAINT preferencia_receta_pkey PRIMARY KEY (id);

ALTER TABLE dom_experiencia_usuario.preferencia_receta
    ADD CONSTRAINT preferencia_receta_id_paciente_id_receta_key UNIQUE (id_paciente, id_receta);

ALTER TABLE dom_experiencia_usuario.preferencia_receta
    ADD CONSTRAINT preferencia_receta_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_experiencia_usuario.preferencia_receta
    ADD CONSTRAINT preferencia_receta_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_identidad_catalogos.catalogo_sexo
    ADD CONSTRAINT catalogo_sexo_pkey PRIMARY KEY (id);

ALTER TABLE dom_identidad_catalogos.catalogo_sexo
    ADD CONSTRAINT catalogo_sexo_codigo_key UNIQUE (codigo);

ALTER TABLE dom_identidad_catalogos.parentesco
    ADD CONSTRAINT parentesco_pkey PRIMARY KEY (id);

ALTER TABLE dom_identidad_catalogos.parentesco
    ADD CONSTRAINT parentesco_nombre_key UNIQUE (nombre);

ALTER TABLE dom_identidad_catalogos.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id);

ALTER TABLE dom_identidad_catalogos.rol
    ADD CONSTRAINT rol_nombre_key UNIQUE (nombre);

ALTER TABLE dom_identidad_usuarios.paciente
    ADD CONSTRAINT paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_identidad_usuarios.paciente
    ADD CONSTRAINT paciente_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES dom_territorio_catalogos.provincia(id);

ALTER TABLE dom_identidad_usuarios.paciente
    ADD CONSTRAINT paciente_id_sexo_fkey FOREIGN KEY (id_sexo) REFERENCES dom_identidad_catalogos.catalogo_sexo(id);

ALTER TABLE dom_identidad_usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_identidad_usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_usuario_tutor_id_paciente_key UNIQUE (id_usuario_tutor, id_paciente);

ALTER TABLE dom_identidad_usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_identidad_usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_parentesco_fkey FOREIGN KEY (id_parentesco) REFERENCES dom_identidad_catalogos.parentesco(id);

ALTER TABLE dom_identidad_usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_usuario_tutor_fkey FOREIGN KEY (id_usuario_tutor) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_identidad_usuarios.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);

ALTER TABLE dom_identidad_usuarios.usuario
    ADD CONSTRAINT usuario_email_key UNIQUE (email);

ALTER TABLE dom_identidad_usuarios.usuario
    ADD CONSTRAINT usuario_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES dom_identidad_catalogos.rol(id);

ALTER TABLE dom_nutricion_catalogos.etiqueta_nutricional
    ADD CONSTRAINT etiqueta_nutricional_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_catalogos.etiqueta_nutricional
    ADD CONSTRAINT etiqueta_nutricional_codigo_key UNIQUE (codigo);

ALTER TABLE dom_nutricion_catalogos.grupo_alimentario
    ADD CONSTRAINT grupo_alimentario_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_catalogos.grupo_alimentario
    ADD CONSTRAINT grupo_alimentario_nombre_key UNIQUE (nombre);

ALTER TABLE dom_nutricion_catalogos.momento_comida
    ADD CONSTRAINT momento_comida_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_catalogos.momento_comida
    ADD CONSTRAINT momento_comida_nombre_key UNIQUE (nombre);

ALTER TABLE dom_nutricion_catalogos.nutriente
    ADD CONSTRAINT nutriente_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_catalogos.nutriente
    ADD CONSTRAINT nutriente_codigo_key UNIQUE (codigo);

ALTER TABLE dom_nutricion_catalogos.nutriente
    ADD CONSTRAINT ck_nutriente_categoria CHECK (upper(categoria::text) = ANY (ARRAY['MACRO'::text, 'MINERAL'::text, 'VITAMINA'::text, 'OTRO'::text])) NOT VALID;

ALTER TABLE dom_nutricion_catalogos.tipo_plato
    ADD CONSTRAINT tipo_plato_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_catalogos.tipo_plato
    ADD CONSTRAINT tipo_plato_nombre_key UNIQUE (nombre);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_etiqueta
    ADD CONSTRAINT ingrediente_etiqueta_pkey PRIMARY KEY (id_ingrediente, id_etiqueta);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_etiqueta
    ADD CONSTRAINT ingrediente_etiqueta_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES dom_nutricion_catalogos.etiqueta_nutricional(id);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_etiqueta
    ADD CONSTRAINT ingrediente_etiqueta_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_id_ingrediente_id_nutriente_key UNIQUE (id_ingrediente, id_nutriente);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_nutriente
    ADD CONSTRAINT ck_ingrediente_nutriente_valor CHECK (valor_por_100g >= 0::numeric) NOT VALID;

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_nutricion_ingrediente_rel.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_id_nutriente_fkey FOREIGN KEY (id_nutriente) REFERENCES dom_nutricion_catalogos.nutriente(id);

ALTER TABLE dom_nutricion_ingredientes.ingrediente
    ADD CONSTRAINT ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_ingredientes.ingrediente
    ADD CONSTRAINT ingrediente_nombre_key UNIQUE (nombre);

ALTER TABLE dom_nutricion_ingredientes.ingrediente
    ADD CONSTRAINT ck_ingrediente_costo_positivo CHECK (costo_estimado_por_100g IS NULL OR costo_estimado_por_100g >= 0::numeric) NOT VALID;

ALTER TABLE dom_nutricion_ingredientes.ingrediente
    ADD CONSTRAINT ck_ingrediente_moneda_formato CHECK (char_length(moneda_costo::text) = 3) NOT VALID;

ALTER TABLE dom_nutricion_ingredientes.ingrediente
    ADD CONSTRAINT ingrediente_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES dom_nutricion_catalogos.grupo_alimentario(id);

ALTER TABLE dom_nutricion_ingredientes.ingrediente
    ADD CONSTRAINT ingrediente_id_region_fkey FOREIGN KEY (id_region) REFERENCES dom_territorio_catalogos.region_natural(id);

ALTER TABLE dom_nutricion_ingredientes.ingrediente_sinonimo
    ADD CONSTRAINT ingrediente_sinonimo_pkey PRIMARY KEY (id);

ALTER TABLE dom_nutricion_ingredientes.ingrediente_sinonimo
    ADD CONSTRAINT ingrediente_sinonimo_id_ingrediente_nombre_sinonimo_key UNIQUE (id_ingrediente, nombre_sinonimo);

ALTER TABLE dom_nutricion_ingredientes.ingrediente_sinonimo
    ADD CONSTRAINT ingrediente_sinonimo_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id) ON DELETE CASCADE;

ALTER TABLE dom_planes_base.plan_item
    ADD CONSTRAINT plan_item_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_base.plan_item
    ADD CONSTRAINT ck_plan_item_energia CHECK (energia_objetivo_kcal IS NULL OR energia_objetivo_kcal >= 0::numeric) NOT VALID;

ALTER TABLE dom_planes_base.plan_item
    ADD CONSTRAINT ck_plan_item_proteina CHECK (proteina_objetivo_g IS NULL OR proteina_objetivo_g >= 0::numeric) NOT VALID;

ALTER TABLE dom_planes_base.plan_item
    ADD CONSTRAINT plan_item_id_momento_fkey FOREIGN KEY (id_momento) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_planes_base.plan_item
    ADD CONSTRAINT plan_item_id_plan_fkey FOREIGN KEY (id_plan) REFERENCES dom_planes_base.plan_nutricional(id);

ALTER TABLE dom_planes_base.plan_item
    ADD CONSTRAINT plan_item_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT plan_nutricional_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT ck_plan_comidas_por_dia CHECK (comidas_por_dia >= 1 AND comidas_por_dia <= 8) NOT VALID;

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT ck_plan_fechas_validas CHECK (fecha_fin >= fecha_inicio) NOT VALID;

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT fk_plan_contexto_recetas FOREIGN KEY (id_contexto_recetas) REFERENCES dom_planes_permitidos.receta_permitida_contexto(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT fk_plan_objetivo_nutricional FOREIGN KEY (id_objetivo_nutricional) REFERENCES dom_clinica_objetivos.objetivo_nutricional_paciente(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT plan_nutricional_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_estado_plan_fkey FOREIGN KEY (id_estado_plan) REFERENCES dom_planes_catalogos_estado.catalogo_estado_plan(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_origen_plan_fkey FOREIGN KEY (id_origen_plan) REFERENCES dom_planes_catalogos_tipo.catalogo_origen_plan(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_planes_base.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_tipo_plan_fkey FOREIGN KEY (id_tipo_plan) REFERENCES dom_planes_catalogos_tipo.catalogo_tipo_plan(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT ck_recomendacion_calificacion CHECK (calificacion_estrellas IS NULL OR calificacion_estrellas >= 1 AND calificacion_estrellas <= 5) NOT VALID;

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT fk_recomendacion_contexto FOREIGN KEY (id_contexto_recetas) REFERENCES dom_planes_permitidos.receta_permitida_contexto(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT fk_recomendacion_control_base FOREIGN KEY (id_control_base) REFERENCES dom_clinica_controles.control_paciente(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT fk_recomendacion_objetivo FOREIGN KEY (id_objetivo_nutricional) REFERENCES dom_clinica_objetivos.objetivo_nutricional_paciente(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_momento_fkey FOREIGN KEY (id_momento) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_motivo_rechazo_fkey FOREIGN KEY (id_motivo_rechazo) REFERENCES dom_planes_catalogos_estado.catalogo_motivo_rechazo(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_planes_base.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_planes_base.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_base.seguimiento_plan_item
    ADD CONSTRAINT fk_seguimiento_plan_item_reemplazo FOREIGN KEY (id_plan_item_reemplazo) REFERENCES dom_planes_reemplazos.plan_item_reemplazo(id);

ALTER TABLE dom_planes_base.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_estado_consumo_fkey FOREIGN KEY (id_estado_consumo) REFERENCES dom_planes_catalogos_estado.catalogo_estado_consumo(id);

ALTER TABLE dom_planes_base.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_plan_item_fkey FOREIGN KEY (id_plan_item) REFERENCES dom_planes_base.plan_item(id);

ALTER TABLE dom_planes_base.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_receta_reemplazo_fkey FOREIGN KEY (id_receta_reemplazo) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_planes_base.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_usuario_registra_fkey FOREIGN KEY (id_usuario_registra) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_planes_catalogos_estado.catalogo_estado_consumo
    ADD CONSTRAINT catalogo_estado_consumo_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_catalogos_estado.catalogo_estado_consumo
    ADD CONSTRAINT catalogo_estado_consumo_codigo_key UNIQUE (codigo);

ALTER TABLE dom_planes_catalogos_estado.catalogo_estado_plan
    ADD CONSTRAINT catalogo_estado_plan_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_catalogos_estado.catalogo_estado_plan
    ADD CONSTRAINT catalogo_estado_plan_codigo_key UNIQUE (codigo);

ALTER TABLE dom_planes_catalogos_estado.catalogo_motivo_rechazo
    ADD CONSTRAINT catalogo_motivo_rechazo_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_catalogos_estado.catalogo_motivo_rechazo
    ADD CONSTRAINT catalogo_motivo_rechazo_nombre_key UNIQUE (nombre);

ALTER TABLE dom_planes_catalogos_tipo.catalogo_nivel_actividad
    ADD CONSTRAINT catalogo_nivel_actividad_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_catalogos_tipo.catalogo_nivel_actividad
    ADD CONSTRAINT catalogo_nivel_actividad_codigo_key UNIQUE (codigo);

ALTER TABLE dom_planes_catalogos_tipo.catalogo_nivel_actividad
    ADD CONSTRAINT catalogo_nivel_actividad_codigo_check CHECK (upper(codigo::text) = ANY (ARRAY['MUY_BAJA'::text, 'BAJA'::text, 'MODERADA'::text, 'ALTA'::text]));

ALTER TABLE dom_planes_catalogos_tipo.catalogo_origen_plan
    ADD CONSTRAINT catalogo_origen_plan_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_catalogos_tipo.catalogo_origen_plan
    ADD CONSTRAINT catalogo_origen_plan_codigo_key UNIQUE (codigo);

ALTER TABLE dom_planes_catalogos_tipo.catalogo_tipo_plan
    ADD CONSTRAINT catalogo_tipo_plan_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_catalogos_tipo.catalogo_tipo_plan
    ADD CONSTRAINT catalogo_tipo_plan_codigo_key UNIQUE (codigo);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_agua_ml_referencia_check CHECK (agua_ml_referencia IS NULL OR agua_ml_referencia >= 0 AND agua_ml_referencia <= 12000);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_origen_check CHECK (upper(origen::text) = ANY (ARRAY['SISTEMA'::text, 'MEDICO'::text, 'NUTRICIONISTA'::text]));

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_created_by_fkey FOREIGN KEY (created_by) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_id_control_base_fkey FOREIGN KEY (id_control_base) REFERENCES dom_clinica_controles.control_paciente(id);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_id_nivel_actividad_fkey FOREIGN KEY (id_nivel_actividad) REFERENCES dom_planes_catalogos_tipo.catalogo_nivel_actividad(id);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_id_objetivo_nutricional_fkey FOREIGN KEY (id_objetivo_nutricional) REFERENCES dom_clinica_objetivos.objetivo_nutricional_paciente(id);

ALTER TABLE dom_planes_permitidos.receta_permitida_contexto
    ADD CONSTRAINT receta_permitida_contexto_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES dom_identidad_usuarios.paciente(id);

ALTER TABLE dom_planes_permitidos.receta_permitida_item
    ADD CONSTRAINT receta_permitida_item_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_permitidos.receta_permitida_item
    ADD CONSTRAINT receta_permitida_item_id_contexto_id_receta_key UNIQUE (id_contexto, id_receta);

ALTER TABLE dom_planes_permitidos.receta_permitida_item
    ADD CONSTRAINT receta_permitida_item_estado_check CHECK (upper(estado::text) = ANY (ARRAY['PERMITIDA'::text, 'DISMINUIDA'::text, 'BLOQUEADA'::text]));

ALTER TABLE dom_planes_permitidos.receta_permitida_item
    ADD CONSTRAINT receta_permitida_item_id_contexto_fkey FOREIGN KEY (id_contexto) REFERENCES dom_planes_permitidos.receta_permitida_contexto(id) ON DELETE CASCADE;

ALTER TABLE dom_planes_permitidos.receta_permitida_item
    ADD CONSTRAINT receta_permitida_item_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_pkey PRIMARY KEY (id);

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_check CHECK (id_receta_original <> id_receta_reemplazo);

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_id_plan_item_fkey FOREIGN KEY (id_plan_item) REFERENCES dom_planes_base.plan_item(id) ON DELETE CASCADE;

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_id_receta_original_fkey FOREIGN KEY (id_receta_original) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_id_receta_reemplazo_fkey FOREIGN KEY (id_receta_reemplazo) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_id_regla_equivalencia_fkey FOREIGN KEY (id_regla_equivalencia) REFERENCES dom_recetas_analitica.receta_reemplazo_equivalente(id);

ALTER TABLE dom_planes_reemplazos.plan_item_reemplazo
    ADD CONSTRAINT plan_item_reemplazo_id_usuario_tutor_fkey FOREIGN KEY (id_usuario_tutor) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_recetas_analitica.receta_nutriente_resumen
    ADD CONSTRAINT receta_nutriente_resumen_pkey PRIMARY KEY (id);

ALTER TABLE dom_recetas_analitica.receta_nutriente_resumen
    ADD CONSTRAINT receta_nutriente_resumen_id_receta_id_nutriente_key UNIQUE (id_receta, id_nutriente);

ALTER TABLE dom_recetas_analitica.receta_nutriente_resumen
    ADD CONSTRAINT receta_nutriente_resumen_valor_por_porcion_check CHECK (valor_por_porcion IS NULL OR valor_por_porcion >= 0::numeric);

ALTER TABLE dom_recetas_analitica.receta_nutriente_resumen
    ADD CONSTRAINT receta_nutriente_resumen_valor_por_receta_check CHECK (valor_por_receta >= 0::numeric);

ALTER TABLE dom_recetas_analitica.receta_nutriente_resumen
    ADD CONSTRAINT receta_nutriente_resumen_id_nutriente_fkey FOREIGN KEY (id_nutriente) REFERENCES dom_nutricion_catalogos.nutriente(id);

ALTER TABLE dom_recetas_analitica.receta_nutriente_resumen
    ADD CONSTRAINT receta_nutriente_resumen_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id) ON DELETE CASCADE;

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_pkey PRIMARY KEY (id);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_id_receta_origen_id_receta_ree_key UNIQUE (id_receta_origen, id_receta_reemplazo, id_momento_origen, id_momento_reemplazo);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_check CHECK (id_receta_origen <> id_receta_reemplazo);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_similitud_nutricional_pct_check CHECK (similitud_nutricional_pct >= 0::numeric AND similitud_nutricional_pct <= 100::numeric);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_variacion_kcal_pct_check CHECK (variacion_kcal_pct IS NULL OR variacion_kcal_pct >= '-100'::integer::numeric AND variacion_kcal_pct <= 100::numeric);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_variacion_proteina_pct_check CHECK (variacion_proteina_pct IS NULL OR variacion_proteina_pct >= '-100'::integer::numeric AND variacion_proteina_pct <= 100::numeric);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_id_momento_origen_fkey FOREIGN KEY (id_momento_origen) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_id_momento_reemplazo_fkey FOREIGN KEY (id_momento_reemplazo) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_id_receta_origen_fkey FOREIGN KEY (id_receta_origen) REFERENCES dom_recetas_base.receta(id) ON DELETE CASCADE;

ALTER TABLE dom_recetas_analitica.receta_reemplazo_equivalente
    ADD CONSTRAINT receta_reemplazo_equivalente_id_receta_reemplazo_fkey FOREIGN KEY (id_receta_reemplazo) REFERENCES dom_recetas_base.receta(id) ON DELETE CASCADE;

ALTER TABLE dom_recetas_base.receta
    ADD CONSTRAINT receta_pkey PRIMARY KEY (id);

ALTER TABLE dom_recetas_base.receta
    ADD CONSTRAINT ck_receta_agua_positiva CHECK (agua_ml_por_porcion IS NULL OR agua_ml_por_porcion >= 0::numeric) NOT VALID;

ALTER TABLE dom_recetas_base.receta
    ADD CONSTRAINT ck_receta_costo_positivo CHECK (costo_estimado_total IS NULL OR costo_estimado_total >= 0::numeric) NOT VALID;

ALTER TABLE dom_recetas_base.receta
    ADD CONSTRAINT ck_receta_score_antiinflamatorio CHECK (score_antiinflamatorio IS NULL OR score_antiinflamatorio >= '-100'::integer AND score_antiinflamatorio <= 100) NOT VALID;

ALTER TABLE dom_recetas_base.receta
    ADD CONSTRAINT receta_id_provincia_origen_fkey FOREIGN KEY (id_provincia_origen) REFERENCES dom_territorio_catalogos.provincia(id);

ALTER TABLE dom_recetas_base.receta_imagen
    ADD CONSTRAINT receta_imagen_pkey PRIMARY KEY (id);

ALTER TABLE dom_recetas_base.receta_imagen
    ADD CONSTRAINT receta_imagen_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_recetas_composicion.momento_compatible
    ADD CONSTRAINT momento_compatible_pkey PRIMARY KEY (id_momento_origen, id_momento_compatible);

ALTER TABLE dom_recetas_composicion.momento_compatible
    ADD CONSTRAINT momento_compatible_check CHECK (id_momento_origen <> id_momento_compatible);

ALTER TABLE dom_recetas_composicion.momento_compatible
    ADD CONSTRAINT momento_compatible_id_momento_compatible_fkey FOREIGN KEY (id_momento_compatible) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_recetas_composicion.momento_compatible
    ADD CONSTRAINT momento_compatible_id_momento_origen_fkey FOREIGN KEY (id_momento_origen) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_recetas_composicion.receta_ingrediente
    ADD CONSTRAINT receta_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE dom_recetas_composicion.receta_ingrediente
    ADD CONSTRAINT receta_ingrediente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_recetas_composicion.receta_ingrediente
    ADD CONSTRAINT receta_ingrediente_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_recetas_composicion.receta_momento
    ADD CONSTRAINT receta_momento_pkey PRIMARY KEY (id_receta, id_momento);

ALTER TABLE dom_recetas_composicion.receta_momento
    ADD CONSTRAINT receta_momento_id_momento_fkey FOREIGN KEY (id_momento) REFERENCES dom_nutricion_catalogos.momento_comida(id);

ALTER TABLE dom_recetas_composicion.receta_momento
    ADD CONSTRAINT receta_momento_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_recetas_composicion.receta_tipo_plato
    ADD CONSTRAINT receta_tipo_plato_pkey PRIMARY KEY (id_receta, id_tipo_plato);

ALTER TABLE dom_recetas_composicion.receta_tipo_plato
    ADD CONSTRAINT receta_tipo_plato_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES dom_recetas_base.receta(id);

ALTER TABLE dom_recetas_composicion.receta_tipo_plato
    ADD CONSTRAINT receta_tipo_plato_id_tipo_plato_fkey FOREIGN KEY (id_tipo_plato) REFERENCES dom_nutricion_catalogos.tipo_plato(id);

ALTER TABLE dom_recetas_composicion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE dom_recetas_composicion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_id_ingrediente_original_id_ingredient_key UNIQUE (id_ingrediente_original, id_ingrediente_reemplazo);

ALTER TABLE dom_recetas_composicion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_id_ingrediente_original_fkey FOREIGN KEY (id_ingrediente_original) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_recetas_composicion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_id_ingrediente_reemplazo_fkey FOREIGN KEY (id_ingrediente_reemplazo) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_referencia_oms.indicador_antropometrico
    ADD CONSTRAINT indicador_antropometrico_pkey PRIMARY KEY (id);

ALTER TABLE dom_referencia_oms.indicador_antropometrico
    ADD CONSTRAINT indicador_antropometrico_codigo_key UNIQUE (codigo);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_pkey PRIMARY KEY (id);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_id_indicador_id_sexo_edad_meses_key UNIQUE (id_indicador, id_sexo, edad_meses);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_check CHECK (p01 <= p1 AND p1 <= p3 AND p3 <= p5 AND p5 <= p10 AND p10 <= p15 AND p15 <= p25 AND p25 <= p50 AND p50 <= p75 AND p75 <= p85 AND p85 <= p90 AND p90 <= p95 AND p95 <= p97 AND p97 <= p99 AND p99 <= p999);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_edad_meses_check CHECK (edad_meses >= 0 AND edad_meses <= 240);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_m_check CHECK (m > 0::numeric);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_s_check CHECK (s > 0::numeric);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_id_indicador_fkey FOREIGN KEY (id_indicador) REFERENCES dom_referencia_oms.indicador_antropometrico(id);

ALTER TABLE dom_referencia_oms.oms_referencia_percentil
    ADD CONSTRAINT oms_referencia_percentil_id_sexo_fkey FOREIGN KEY (id_sexo) REFERENCES dom_identidad_catalogos.catalogo_sexo(id);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_pkey PRIMARY KEY (id);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_id_indicador_id_sexo_edad_meses_key UNIQUE (id_indicador, id_sexo, edad_meses);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_check1 CHECK (sd4neg <= sd3neg AND sd3neg <= sd2neg AND sd2neg <= sd1neg AND sd1neg <= sd0 AND sd0 <= sd1 AND sd1 <= sd2 AND sd2 <= sd3 AND sd3 <= sd4);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_edad_meses_check CHECK (edad_meses >= 0 AND edad_meses <= 240);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_m_check CHECK (m > 0::numeric);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_s_check CHECK (s > 0::numeric);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_id_indicador_fkey FOREIGN KEY (id_indicador) REFERENCES dom_referencia_oms.indicador_antropometrico(id);

ALTER TABLE dom_referencia_oms.oms_referencia_zscore
    ADD CONSTRAINT oms_referencia_zscore_id_sexo_fkey FOREIGN KEY (id_sexo) REFERENCES dom_identidad_catalogos.catalogo_sexo(id);

ALTER TABLE dom_reglas_catalogos.catalogo_accion
    ADD CONSTRAINT catalogo_accion_pkey PRIMARY KEY (id);

ALTER TABLE dom_reglas_catalogos.catalogo_accion
    ADD CONSTRAINT catalogo_accion_codigo_key UNIQUE (codigo);

ALTER TABLE dom_reglas_catalogos.catalogo_accion
    ADD CONSTRAINT ck_catalogo_accion_valida CHECK (NOT activo OR (upper(codigo::text) = ANY (ARRAY['ELIMINAR'::text, 'DISMINUIR'::text, 'PRIORIZAR'::text]))) NOT VALID;

ALTER TABLE dom_reglas_catalogos.catalogo_objetivo_regla
    ADD CONSTRAINT catalogo_objetivo_regla_pkey PRIMARY KEY (id);

ALTER TABLE dom_reglas_catalogos.catalogo_objetivo_regla
    ADD CONSTRAINT catalogo_objetivo_regla_codigo_key UNIQUE (codigo);

ALTER TABLE dom_reglas_catalogos.catalogo_tipo_condicion
    ADD CONSTRAINT catalogo_tipo_condicion_pkey PRIMARY KEY (id);

ALTER TABLE dom_reglas_catalogos.catalogo_tipo_condicion
    ADD CONSTRAINT catalogo_tipo_condicion_nombre_key UNIQUE (nombre);

ALTER TABLE dom_reglas_motor.condicion
    ADD CONSTRAINT condicion_pkey PRIMARY KEY (id);

ALTER TABLE dom_reglas_motor.condicion
    ADD CONSTRAINT condicion_nombre_id_tipo_condicion_key UNIQUE (nombre, id_tipo_condicion);

ALTER TABLE dom_reglas_motor.condicion
    ADD CONSTRAINT condicion_id_tipo_condicion_fkey FOREIGN KEY (id_tipo_condicion) REFERENCES dom_reglas_catalogos.catalogo_tipo_condicion(id);

ALTER TABLE dom_reglas_motor.condicion_regla
    ADD CONSTRAINT condicion_regla_pkey PRIMARY KEY (id);

ALTER TABLE dom_reglas_motor.condicion_regla
    ADD CONSTRAINT condicion_regla_id_condicion_id_regla_key UNIQUE (id_condicion, id_regla);

ALTER TABLE dom_reglas_motor.condicion_regla
    ADD CONSTRAINT condicion_regla_id_condicion_fkey FOREIGN KEY (id_condicion) REFERENCES dom_reglas_motor.condicion(id);

ALTER TABLE dom_reglas_motor.condicion_regla
    ADD CONSTRAINT condicion_regla_id_regla_fkey FOREIGN KEY (id_regla) REFERENCES dom_reglas_motor.regla(id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_pkey PRIMARY KEY (id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT ck_regla_aplica_brote CHECK (upper(aplica_brote::text) = ANY (ARRAY['AMBOS'::text, 'SOLO_BROTE'::text, 'SOLO_ESTABLE'::text])) NOT VALID;

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT ck_regla_prioridad_manual CHECK (prioridad_manual IS NULL OR prioridad_manual >= '-100'::integer AND prioridad_manual <= 100) NOT VALID;

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT ck_regla_rango_fechas CHECK (fecha_fin_vigencia IS NULL OR fecha_inicio_vigencia IS NULL OR fecha_fin_vigencia >= fecha_inicio_vigencia) NOT VALID;

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_check CHECK (((id_ingrediente IS NOT NULL)::integer + (id_grupo_alimentario IS NOT NULL)::integer + (id_etiqueta IS NOT NULL)::integer) = 1);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_created_by_fkey FOREIGN KEY (created_by) REFERENCES dom_identidad_usuarios.usuario(id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_id_accion_fkey FOREIGN KEY (id_accion) REFERENCES dom_reglas_catalogos.catalogo_accion(id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES dom_nutricion_catalogos.etiqueta_nutricional(id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES dom_nutricion_catalogos.grupo_alimentario(id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES dom_nutricion_ingredientes.ingrediente(id);

ALTER TABLE dom_reglas_motor.regla
    ADD CONSTRAINT regla_id_tipo_objetivo_fkey FOREIGN KEY (id_tipo_objetivo) REFERENCES dom_reglas_catalogos.catalogo_objetivo_regla(id);

ALTER TABLE dom_territorio_catalogos.provincia
    ADD CONSTRAINT provincia_pkey PRIMARY KEY (id);

ALTER TABLE dom_territorio_catalogos.provincia
    ADD CONSTRAINT provincia_id_region_fkey FOREIGN KEY (id_region) REFERENCES dom_territorio_catalogos.region_natural(id);

ALTER TABLE dom_territorio_catalogos.region_natural
    ADD CONSTRAINT region_natural_pkey PRIMARY KEY (id);

ALTER TABLE dom_territorio_catalogos.region_natural
    ADD CONSTRAINT region_natural_nombre_key UNIQUE (nombre);

ALTER TABLE dom_tutor_acompanamiento.nota_tutor_paciente
    ADD CONSTRAINT nota_tutor_paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_tutor_acompanamiento.nota_tutor_paciente
    ADD CONSTRAINT nota_tutor_paciente_nota_check CHECK (char_length(btrim(nota)) >= 2);

ALTER TABLE dom_tutor_acompanamiento.nota_tutor_paciente
    ADD CONSTRAINT nota_tutor_paciente_id_plan_fkey FOREIGN KEY (id_plan) REFERENCES dom_planes_base.plan_nutricional(id);

ALTER TABLE dom_tutor_acompanamiento.nota_tutor_paciente
    ADD CONSTRAINT nota_tutor_paciente_id_plan_item_fkey FOREIGN KEY (id_plan_item) REFERENCES dom_planes_base.plan_item(id);

ALTER TABLE dom_tutor_acompanamiento.nota_tutor_paciente
    ADD CONSTRAINT nota_tutor_paciente_id_usuario_tutor_id_paciente_fkey FOREIGN KEY (id_usuario_tutor, id_paciente) REFERENCES dom_identidad_usuarios.tutor_paciente(id_usuario_tutor, id_paciente) ON DELETE CASCADE;

ALTER TABLE dom_tutor_acompanamiento.perfil_apoyo_tutor_paciente
    ADD CONSTRAINT perfil_apoyo_tutor_paciente_pkey PRIMARY KEY (id);

ALTER TABLE dom_tutor_acompanamiento.perfil_apoyo_tutor_paciente
    ADD CONSTRAINT perfil_apoyo_tutor_paciente_id_usuario_tutor_id_paciente_key UNIQUE (id_usuario_tutor, id_paciente);

ALTER TABLE dom_tutor_acompanamiento.perfil_apoyo_tutor_paciente
    ADD CONSTRAINT perfil_apoyo_tutor_paciente_meta_agua_diaria_ml_check CHECK (meta_agua_diaria_ml IS NULL OR meta_agua_diaria_ml >= 0 AND meta_agua_diaria_ml <= 12000);

ALTER TABLE dom_tutor_acompanamiento.perfil_apoyo_tutor_paciente
    ADD CONSTRAINT perfil_apoyo_tutor_paciente_id_nivel_actividad_actual_fkey FOREIGN KEY (id_nivel_actividad_actual) REFERENCES dom_planes_catalogos_tipo.catalogo_nivel_actividad(id);

ALTER TABLE dom_tutor_acompanamiento.perfil_apoyo_tutor_paciente
    ADD CONSTRAINT perfil_apoyo_tutor_paciente_id_usuario_tutor_id_paciente_fkey FOREIGN KEY (id_usuario_tutor, id_paciente) REFERENCES dom_identidad_usuarios.tutor_paciente(id_usuario_tutor, id_paciente) ON DELETE CASCADE;

ALTER TABLE dom_tutor_acompanamiento.registro_apoyo_diario
    ADD CONSTRAINT registro_apoyo_diario_pkey PRIMARY KEY (id);

ALTER TABLE dom_tutor_acompanamiento.registro_apoyo_diario
    ADD CONSTRAINT registro_apoyo_diario_id_usuario_tutor_id_paciente_fecha_re_key UNIQUE (id_usuario_tutor, id_paciente, fecha_registro);

ALTER TABLE dom_tutor_acompanamiento.registro_apoyo_diario
    ADD CONSTRAINT registro_apoyo_diario_agua_ml_check CHECK (agua_ml IS NULL OR agua_ml >= 0 AND agua_ml <= 12000);

ALTER TABLE dom_tutor_acompanamiento.registro_apoyo_diario
    ADD CONSTRAINT registro_apoyo_diario_minutos_actividad_check CHECK (minutos_actividad IS NULL OR minutos_actividad >= 0);

ALTER TABLE dom_tutor_acompanamiento.registro_apoyo_diario
    ADD CONSTRAINT registro_apoyo_diario_id_nivel_actividad_fkey FOREIGN KEY (id_nivel_actividad) REFERENCES dom_planes_catalogos_tipo.catalogo_nivel_actividad(id);

ALTER TABLE dom_tutor_acompanamiento.registro_apoyo_diario
    ADD CONSTRAINT registro_apoyo_diario_id_usuario_tutor_id_paciente_fkey FOREIGN KEY (id_usuario_tutor, id_paciente) REFERENCES dom_identidad_usuarios.tutor_paciente(id_usuario_tutor, id_paciente) ON DELETE CASCADE;

-- =====================================================
-- INDICES
-- =====================================================
CREATE INDEX idx_alergia_grupo_paciente_activa ON dom_clinica_alergias.alergia_paciente_grupo USING btree (id_paciente) WHERE (activa = true);
CREATE INDEX idx_alergia_ingrediente_paciente_activa ON dom_clinica_alergias.alergia_paciente_ingrediente USING btree (id_paciente) WHERE (activa = true);
CREATE INDEX idx_control_paciente_brote_fecha ON dom_clinica_controles.control_paciente USING btree (id_paciente, hay_brote_activo, fecha_control DESC);
CREATE INDEX idx_control_paciente_condicion_nutricional ON dom_clinica_controles.control_paciente USING btree (id_condicion_nutricional_resultado);
CREATE INDEX idx_control_paciente_fecha ON dom_clinica_controles.control_paciente USING btree (id_paciente, fecha_control DESC);
CREATE INDEX idx_diagnostico_paciente_activo ON dom_clinica_diagnosticos.diagnostico_paciente USING btree (id_paciente, activa);
CREATE INDEX idx_objetivo_nutricional_nutriente_objetivo ON dom_clinica_objetivos.objetivo_nutricional_nutriente USING btree (id_objetivo);
CREATE INDEX idx_objetivo_nutricional_control_base ON dom_clinica_objetivos.objetivo_nutricional_paciente USING btree (id_control_base);
CREATE UNIQUE INDEX ux_objetivo_nutricional_vigente_paciente ON dom_clinica_objetivos.objetivo_nutricional_paciente USING btree (id_paciente) WHERE (vigente = true);
CREATE INDEX idx_objetivo_restriccion_objetivo ON dom_clinica_objetivos.objetivo_nutricional_restriccion USING btree (id_objetivo);
CREATE INDEX idx_lista_compra_paciente ON dom_compras.lista_compra USING btree (id_paciente, created_at DESC);
CREATE INDEX idx_lista_compra_item_estado ON dom_compras.lista_compra_item USING btree (id_lista_compra, comprado);
CREATE INDEX idx_tutor_paciente_paciente ON dom_identidad_usuarios.tutor_paciente USING btree (id_paciente);
CREATE INDEX idx_tutor_paciente_tutor ON dom_identidad_usuarios.tutor_paciente USING btree (id_usuario_tutor);
CREATE INDEX idx_ingrediente_nutriente_ingrediente ON dom_nutricion_ingrediente_rel.ingrediente_nutriente USING btree (id_ingrediente);
CREATE INDEX idx_ingrediente_nutriente_nutriente ON dom_nutricion_ingrediente_rel.ingrediente_nutriente USING btree (id_nutriente);
CREATE INDEX idx_ingrediente_sinonimo_ingrediente ON dom_nutricion_ingredientes.ingrediente_sinonimo USING btree (id_ingrediente);
CREATE UNIQUE INDEX ux_ingrediente_sinonimo_nombre_activo ON dom_nutricion_ingredientes.ingrediente_sinonimo USING btree (lower(btrim((nombre_sinonimo)::text))) WHERE (activo = true);
CREATE INDEX idx_plan_item_plan_fecha ON dom_planes_base.plan_item USING btree (id_plan, fecha_programada);
CREATE INDEX idx_plan_item_receta ON dom_planes_base.plan_item USING btree (id_receta);
CREATE INDEX idx_plan_nutricional_contexto ON dom_planes_base.plan_nutricional USING btree (id_contexto_recetas);
CREATE INDEX idx_plan_nutricional_objetivo ON dom_planes_base.plan_nutricional USING btree (id_objetivo_nutricional);
CREATE INDEX idx_recomendacion_puntual_paciente_fecha ON dom_planes_base.recomendacion_puntual USING btree (id_paciente, fecha_solicitud DESC);
CREATE INDEX idx_seguimiento_plan_item ON dom_planes_base.seguimiento_plan_item USING btree (id_plan_item);
CREATE UNIQUE INDEX ux_receta_permitida_contexto_vigente ON dom_planes_permitidos.receta_permitida_contexto USING btree (id_paciente) WHERE (vigente = true);
CREATE INDEX idx_receta_permitida_item_contexto ON dom_planes_permitidos.receta_permitida_item USING btree (id_contexto, estado, puntaje_prioridad DESC);
CREATE UNIQUE INDEX ux_plan_item_reemplazo_vigente ON dom_planes_reemplazos.plan_item_reemplazo USING btree (id_plan_item) WHERE (vigente = true);
CREATE INDEX idx_receta_nutriente_resumen_nutriente ON dom_recetas_analitica.receta_nutriente_resumen USING btree (id_nutriente);
CREATE INDEX idx_receta_nutriente_resumen_receta ON dom_recetas_analitica.receta_nutriente_resumen USING btree (id_receta);
CREATE INDEX idx_receta_reemplazo_origen ON dom_recetas_analitica.receta_reemplazo_equivalente USING btree (id_receta_origen, id_momento_origen) WHERE (activa = true);
CREATE INDEX idx_receta_ingrediente_ingrediente ON dom_recetas_composicion.receta_ingrediente USING btree (id_ingrediente);
CREATE INDEX idx_receta_ingrediente_receta ON dom_recetas_composicion.receta_ingrediente USING btree (id_receta);
CREATE INDEX idx_oms_referencia_percentil_sexo_edad ON dom_referencia_oms.oms_referencia_percentil USING btree (id_sexo, edad_meses);
CREATE INDEX idx_oms_referencia_zscore_sexo_edad ON dom_referencia_oms.oms_referencia_zscore USING btree (id_sexo, edad_meses);
CREATE INDEX idx_condicion_regla_condicion ON dom_reglas_motor.condicion_regla USING btree (id_condicion);
CREATE INDEX idx_condicion_regla_regla ON dom_reglas_motor.condicion_regla USING btree (id_regla);
CREATE INDEX idx_regla_activa_brote ON dom_reglas_motor.regla USING btree (activo, aplica_brote);
CREATE INDEX idx_nota_tutor_paciente_fecha ON dom_tutor_acompanamiento.nota_tutor_paciente USING btree (id_paciente, created_at DESC);
CREATE INDEX idx_registro_apoyo_paciente_fecha ON dom_tutor_acompanamiento.registro_apoyo_diario USING btree (id_paciente, fecha_registro DESC);
