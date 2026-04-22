-- =====================================================
-- REUMA NUTRI - ESQUEMA SINCRONIZADO DESDE SUPABASE
-- Generado automaticamente: 2026-04-12 13:07:14Z
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
CREATE SCHEMA IF NOT EXISTS seguridad;
CREATE SCHEMA IF NOT EXISTS usuarios;
CREATE SCHEMA IF NOT EXISTS clinico;
CREATE SCHEMA IF NOT EXISTS nutricion;
CREATE SCHEMA IF NOT EXISTS heuristico;
CREATE SCHEMA IF NOT EXISTS interaccion;
CREATE SCHEMA IF NOT EXISTS referencia;

-- =====================================================
-- TABLAS
-- =====================================================
CREATE TABLE seguridad.log_auditoria (
    id BIGSERIAL NOT NULL,
    id_usuario UUID,
    accion VARCHAR(100) NOT NULL,
    esquema_afectado VARCHAR(100),
    tabla_afectada VARCHAR(100) NOT NULL,
    id_registro_afectado VARCHAR(150),
    detalle TEXT,
    payload_anterior JSONB,
    payload_nuevo JSONB,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE seguridad.log_error (
    id BIGSERIAL NOT NULL,
    modulo VARCHAR(100) NOT NULL,
    mensaje TEXT NOT NULL,
    stack_trace TEXT,
    payload JSONB,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE usuarios.catalogo_sexo (
    id SERIAL NOT NULL,
    codigo VARCHAR(10) NOT NULL,
    descripcion VARCHAR(50) NOT NULL
);

CREATE TABLE usuarios.paciente (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    id_sexo INTEGER NOT NULL,
    id_provincia INTEGER,
    fecha_ultimo_control DATE,
    activo BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE usuarios.parentesco (
    id SERIAL NOT NULL,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE usuarios.provincia (
    id SERIAL NOT NULL,
    nombre TEXT NOT NULL
);

CREATE TABLE usuarios.rol (
    id SERIAL NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE usuarios.tutor_paciente (
    id BIGSERIAL NOT NULL,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    id_parentesco INTEGER,
    es_principal BOOLEAN DEFAULT false NOT NULL,
    activo BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE usuarios.usuario (
    id UUID DEFAULT gen_random_uuid() NOT NULL,
    auth_user_id UUID,
    id_rol INTEGER NOT NULL,
    cedula VARCHAR(20),
    username VARCHAR(80),
    email VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    telefono VARCHAR(30),
    direccion TEXT,
    requiere_cambio_password BOOLEAN DEFAULT false NOT NULL,
    activo BOOLEAN DEFAULT true NOT NULL,
    ultimo_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL,
    created_by UUID,
    updated_by UUID,
    deactivated_at TIMESTAMP,
    deactivated_by UUID,
    deactivated_reason TEXT,
    cedula_enc BYTEA
);

CREATE TABLE clinico.alergia_paciente_grupo (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_grupo_alimentario INTEGER NOT NULL,
    fecha_registro DATE DEFAULT CURRENT_DATE NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL,
    observacion TEXT
);

CREATE TABLE clinico.alergia_paciente_ingrediente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    fecha_registro DATE DEFAULT CURRENT_DATE NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL,
    observacion TEXT
);

CREATE TABLE clinico.control_condicion_activa (
    id BIGSERIAL NOT NULL,
    id_control BIGINT NOT NULL,
    id_condicion INTEGER NOT NULL
);

CREATE TABLE clinico.control_paciente (
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
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE clinico.diagnostico_paciente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_condicion INTEGER NOT NULL,
    fecha_diagnostico DATE DEFAULT CURRENT_DATE NOT NULL,
    es_cronico BOOLEAN DEFAULT true NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL,
    observacion TEXT
);

CREATE TABLE nutricion.clasificacion_nutriente (
    id SERIAL NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE nutricion.etiqueta_nutricional (
    id SERIAL NOT NULL,
    codigo VARCHAR(80) NOT NULL,
    nombre_visible VARCHAR(160) NOT NULL
);

CREATE TABLE nutricion.grupo_alimentario (
    id SERIAL NOT NULL,
    nombre VARCHAR(120) NOT NULL
);

CREATE TABLE nutricion.ingrediente (
    id SERIAL NOT NULL,
    id_grupo_alimentario INTEGER NOT NULL,
    id_subgrupo_alimentario INTEGER NOT NULL,
    nombre VARCHAR(180) NOT NULL,
    precio_libra NUMERIC NOT NULL,
    factor_parte_comestible NUMERIC(12,2) NOT NULL,
    activo BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE nutricion.ingrediente_composicion (
    id_ingrediente INTEGER NOT NULL,
    energia_kcal NUMERIC(18,3) NOT NULL,
    agua_g NUMERIC(18,3) NOT NULL,
    alcohol_g NUMERIC(18,3) NOT NULL,
    proteinas_g NUMERIC(18,3) NOT NULL,
    hidratos_carbono_g NUMERIC(18,8) NOT NULL,
    almidon_g NUMERIC(18,8) NOT NULL,
    azucares_sencillos_g NUMERIC(18,3) NOT NULL,
    azucares_libres_g NUMERIC(18,3) NOT NULL,
    fibra_vegetal_g NUMERIC(18,3) NOT NULL,
    grasa_total_g NUMERIC(18,3) NOT NULL,
    ags_g NUMERIC(18,3) NOT NULL,
    agm_g NUMERIC(18,3) NOT NULL,
    agp_g NUMERIC(18,3) NOT NULL,
    colesterol_mg NUMERIC(18,3) NOT NULL,
    vitamina_a_eq_retinol_ug NUMERIC(18,3) NOT NULL,
    retinol_ug NUMERIC(18,3) NOT NULL,
    carotenoides_eq_beta_caroteno_ug NUMERIC(18,8) NOT NULL,
    vit_d_ug NUMERIC(18,3) NOT NULL,
    vit_e_eq_alpha_tocoferol_mg NUMERIC(18,3) NOT NULL,
    vit_k_ug NUMERIC(18,3) NOT NULL,
    vitamina_b1_mg NUMERIC(18,3) NOT NULL,
    vitamina_b2_mg NUMERIC(18,3) NOT NULL,
    eq_niacina_mg NUMERIC(18,3) NOT NULL,
    vit_b6_mg NUMERIC(18,3) NOT NULL,
    eq_folato_dietetico_ug NUMERIC(18,3) NOT NULL,
    vit_b12_ug NUMERIC(18,3) NOT NULL,
    pantotenico_mg NUMERIC(18,3) NOT NULL,
    biotina_ug NUMERIC(18,3) NOT NULL,
    vit_c_mg NUMERIC(18,3) NOT NULL,
    calcio_mg NUMERIC(18,3) NOT NULL,
    fosforo_mg NUMERIC(18,3) NOT NULL,
    hierro_mg NUMERIC(18,3) NOT NULL,
    iodo_ug NUMERIC(18,3) NOT NULL,
    cinc_mg NUMERIC(18,3) NOT NULL,
    magnesio_mg NUMERIC(18,3) NOT NULL,
    sodio_mg NUMERIC(18,3) NOT NULL,
    potasio_mg NUMERIC(18,3) NOT NULL,
    manganeso_mg NUMERIC(18,3) NOT NULL,
    cobre_mg NUMERIC(18,3) NOT NULL,
    selenio_ug NUMERIC(18,3) NOT NULL,
    omega3_g NUMERIC(18,3) NOT NULL,
    tipo_omega3 VARCHAR(255) NOT NULL,
    grasas_trans_g NUMERIC(18,3) NOT NULL,
    polifenoles_mg NUMERIC(18,3) NOT NULL,
    probioticos_billones_ufc NUMERIC(18,3) NOT NULL
);

CREATE TABLE nutricion.ingrediente_etiqueta (
    id_ingrediente INTEGER NOT NULL,
    id_etiqueta INTEGER NOT NULL
);

CREATE TABLE nutricion.ingrediente_metrica (
    id BIGSERIAL NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    id_metrica INTEGER NOT NULL,
    valor_numerico NUMERIC(18,8) NOT NULL
);

CREATE TABLE nutricion.ingrediente_nutriente (
    id BIGSERIAL NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    id_nutriente INTEGER NOT NULL,
    valor_por_100g NUMERIC(18,8) NOT NULL
);

CREATE TABLE nutricion.ingrediente_sinonimo (
    id BIGSERIAL NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    sinonimo VARCHAR(255) NOT NULL
);

CREATE TABLE nutricion.metrica_def (
    id SERIAL NOT NULL,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    formula_referencia TEXT NOT NULL,
    unidad_medida VARCHAR(30) NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE nutricion.momento_comida (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    orden INTEGER
);

CREATE TABLE nutricion.nutriente (
    id SERIAL NOT NULL,
    codigo VARCHAR(80) NOT NULL,
    nombre VARCHAR(140) NOT NULL,
    unidad_medida VARCHAR(30) NOT NULL,
    id_clasificacion INTEGER,
    activo BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE nutricion.receta (
    id SERIAL NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    instrucciones_preparacion TEXT,
    porciones INTEGER DEFAULT 1 NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL,
    updated_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE nutricion.receta_imagen (
    id BIGSERIAL NOT NULL,
    id_receta INTEGER NOT NULL,
    imagen_url TEXT NOT NULL,
    orden INTEGER DEFAULT 1 NOT NULL
);

CREATE TABLE nutricion.receta_ingrediente (
    id BIGSERIAL NOT NULL,
    id_receta INTEGER NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    cantidad_visual NUMERIC(10,2),
    unidad_visual VARCHAR(50),
    peso_en_gramos NUMERIC(12,4) NOT NULL,
    es_principal BOOLEAN DEFAULT false NOT NULL
);

CREATE TABLE nutricion.receta_momento (
    id_receta INTEGER NOT NULL,
    id_momento INTEGER NOT NULL
);

CREATE TABLE nutricion.receta_nutriente_calculado (
    id BIGSERIAL NOT NULL,
    id_receta INTEGER NOT NULL,
    id_nutriente INTEGER NOT NULL,
    valor_total NUMERIC(18,8) NOT NULL,
    valor_por_porcion NUMERIC(18,8) NOT NULL
);

CREATE TABLE nutricion.receta_tipo_plato (
    id_receta INTEGER NOT NULL,
    id_tipo_plato INTEGER NOT NULL
);

CREATE TABLE nutricion.subgrupo_alimentario (
    id SERIAL NOT NULL,
    id_grupo_alimentario INTEGER NOT NULL,
    nombre VARCHAR(120) NOT NULL
);

CREATE TABLE nutricion.sustituto_ingrediente (
    id BIGSERIAL NOT NULL,
    id_ingrediente_original INTEGER NOT NULL,
    id_ingrediente_reemplazo INTEGER NOT NULL,
    ratio_conversion NUMERIC(10,4) DEFAULT 1.0 NOT NULL,
    mensaje_aviso TEXT,
    activo BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE nutricion.tipo_plato (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE heuristico.catalogo_accion (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    peso_puntaje INTEGER
);

CREATE TABLE heuristico.catalogo_objetivo_regla (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(80) NOT NULL
);

CREATE TABLE heuristico.catalogo_tipo_condicion (
    id SERIAL NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(60) NOT NULL
);

CREATE TABLE heuristico.condicion (
    id SERIAL NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    id_tipo_condicion INTEGER NOT NULL,
    descripcion TEXT,
    activa BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE heuristico.condicion_regla (
    id BIGSERIAL NOT NULL,
    id_condicion INTEGER NOT NULL,
    id_regla BIGINT NOT NULL
);

CREATE TABLE heuristico.regla (
    id BIGSERIAL NOT NULL,
    id_accion INTEGER NOT NULL,
    id_tipo_objetivo INTEGER NOT NULL,
    id_ingrediente INTEGER,
    id_grupo_alimentario INTEGER,
    id_etiqueta INTEGER,
    mensaje_error TEXT,
    origen_regla VARCHAR(20) NOT NULL,
    created_by UUID,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE interaccion.catalogo_estado_consumo (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE interaccion.catalogo_estado_plan (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE interaccion.catalogo_motivo_rechazo (
    id SERIAL NOT NULL,
    nombre VARCHAR(100) NOT NULL
);

CREATE TABLE interaccion.catalogo_origen_plan (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE interaccion.catalogo_tipo_plan (
    id SERIAL NOT NULL,
    codigo VARCHAR(20) NOT NULL
);

CREATE TABLE interaccion.config_analisis_rechazo (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_plan BIGINT,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    activa BOOLEAN DEFAULT true NOT NULL,
    creado_por UUID,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE interaccion.evaluacion_receta (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_receta INTEGER NOT NULL,
    estrellas INTEGER NOT NULL,
    comentario TEXT,
    id_motivo_rechazo INTEGER,
    origen_evaluacion VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE interaccion.plan_item (
    id BIGSERIAL NOT NULL,
    id_plan BIGINT NOT NULL,
    fecha_programada DATE NOT NULL,
    id_momento INTEGER NOT NULL,
    id_receta INTEGER NOT NULL,
    energia_objetivo_kcal NUMERIC(12,2),
    proteina_objetivo_g NUMERIC(12,2)
);

CREATE TABLE interaccion.plan_nutricional (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_tipo_plan INTEGER NOT NULL,
    id_origen_plan INTEGER NOT NULL,
    id_estado_plan INTEGER NOT NULL,
    es_plantilla BOOLEAN DEFAULT false NOT NULL,
    comidas_por_dia INTEGER NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    creado_por UUID,
    vigente BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE interaccion.preferencia_ingrediente (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_ingrediente INTEGER NOT NULL,
    puntaje_ajuste NUMERIC(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE interaccion.preferencia_receta (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_receta INTEGER NOT NULL,
    puntaje_ajuste NUMERIC(10,2) NOT NULL,
    ultima_actualizacion TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TABLE interaccion.recomendacion_puntual (
    id BIGSERIAL NOT NULL,
    id_paciente UUID NOT NULL,
    id_momento INTEGER,
    id_receta INTEGER NOT NULL,
    fecha_solicitud TIMESTAMP DEFAULT now() NOT NULL,
    resultado_consumo VARCHAR(20),
    calificacion_estrellas INTEGER,
    id_motivo_rechazo INTEGER
);

CREATE TABLE interaccion.seguimiento_plan_item (
    id BIGSERIAL NOT NULL,
    id_plan_item BIGINT NOT NULL,
    id_estado_consumo INTEGER NOT NULL,
    id_receta_reemplazo INTEGER,
    fecha_consumo TIMESTAMP,
    observacion TEXT
);

CREATE TABLE referencia.indicador_antropometrico (
    id SERIAL NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion TEXT
);

CREATE TABLE referencia.oms_curva (
    id BIGSERIAL NOT NULL,
    codigo VARCHAR(50) NOT NULL,
    id_indicador INTEGER NOT NULL,
    id_sexo INTEGER NOT NULL,
    tipo_curva VARCHAR(20) NOT NULL,
    unidad_edad VARCHAR(20) DEFAULT 'MESES'::character varying NOT NULL,
    fuente_archivo VARCHAR(255) NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT true NOT NULL
);

CREATE TABLE referencia.oms_curva_percentil (
    id BIGSERIAL NOT NULL,
    id_curva BIGINT NOT NULL,
    edad_valor INTEGER NOT NULL,
    percentil_codigo VARCHAR(20) NOT NULL,
    valor NUMERIC(12,6) NOT NULL
);

CREATE TABLE referencia.oms_curva_punto (
    id BIGSERIAL NOT NULL,
    id_curva BIGINT NOT NULL,
    edad_valor INTEGER NOT NULL,
    l NUMERIC(12,6),
    m NUMERIC(12,6),
    s NUMERIC(12,6),
    sd5neg NUMERIC(12,6),
    sd4neg NUMERIC(12,6),
    sd3neg NUMERIC(12,6),
    sd2neg NUMERIC(12,6),
    sd1neg NUMERIC(12,6),
    sd0 NUMERIC(12,6),
    sd1 NUMERIC(12,6),
    sd2 NUMERIC(12,6),
    sd3 NUMERIC(12,6),
    sd4 NUMERIC(12,6),
    sd5 NUMERIC(12,6)
);

-- =====================================================
-- VISTAS
-- =====================================================
-- =====================================================
-- CONSTRAINTS
-- =====================================================
ALTER TABLE seguridad.log_auditoria
    ADD CONSTRAINT log_auditoria_pkey PRIMARY KEY (id);

ALTER TABLE seguridad.log_error
    ADD CONSTRAINT log_error_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.catalogo_sexo
    ADD CONSTRAINT catalogo_sexo_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.catalogo_sexo
    ADD CONSTRAINT catalogo_sexo_codigo_key UNIQUE (codigo);

ALTER TABLE usuarios.paciente
    ADD CONSTRAINT paciente_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.paciente
    ADD CONSTRAINT paciente_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES usuarios.provincia(id);

ALTER TABLE usuarios.paciente
    ADD CONSTRAINT paciente_id_sexo_fkey FOREIGN KEY (id_sexo) REFERENCES usuarios.catalogo_sexo(id);

ALTER TABLE usuarios.parentesco
    ADD CONSTRAINT parentesco_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.parentesco
    ADD CONSTRAINT parentesco_nombre_key UNIQUE (nombre);

ALTER TABLE usuarios.provincia
    ADD CONSTRAINT provincia_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.provincia
    ADD CONSTRAINT provincia_nombre_key UNIQUE (nombre);

ALTER TABLE usuarios.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.rol
    ADD CONSTRAINT rol_codigo_key UNIQUE (codigo);

ALTER TABLE usuarios.rol
    ADD CONSTRAINT rol_nombre_key UNIQUE (nombre);

ALTER TABLE usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_usuario_tutor_id_paciente_key UNIQUE (id_usuario_tutor, id_paciente);

ALTER TABLE usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_parentesco_fkey FOREIGN KEY (id_parentesco) REFERENCES usuarios.parentesco(id);

ALTER TABLE usuarios.tutor_paciente
    ADD CONSTRAINT tutor_paciente_id_usuario_tutor_fkey FOREIGN KEY (id_usuario_tutor) REFERENCES usuarios.usuario(id);

ALTER TABLE usuarios.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);

ALTER TABLE usuarios.usuario
    ADD CONSTRAINT usuario_auth_user_id_key UNIQUE (auth_user_id);

ALTER TABLE usuarios.usuario
    ADD CONSTRAINT usuario_cedula_key UNIQUE (cedula);

ALTER TABLE usuarios.usuario
    ADD CONSTRAINT usuario_email_key UNIQUE (email);

ALTER TABLE usuarios.usuario
    ADD CONSTRAINT usuario_username_key UNIQUE (username);

ALTER TABLE usuarios.usuario
    ADD CONSTRAINT usuario_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES usuarios.rol(id);

ALTER TABLE clinico.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_pkey PRIMARY KEY (id);

ALTER TABLE clinico.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_id_paciente_id_grupo_alimentario_key UNIQUE (id_paciente, id_grupo_alimentario);

ALTER TABLE clinico.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES nutricion.grupo_alimentario(id);

ALTER TABLE clinico.alergia_paciente_grupo
    ADD CONSTRAINT alergia_paciente_grupo_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE clinico.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE clinico.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_id_paciente_id_ingrediente_key UNIQUE (id_paciente, id_ingrediente);

ALTER TABLE clinico.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id);

ALTER TABLE clinico.alergia_paciente_ingrediente
    ADD CONSTRAINT alergia_paciente_ingrediente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE clinico.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_pkey PRIMARY KEY (id);

ALTER TABLE clinico.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_id_control_id_condicion_key UNIQUE (id_control, id_condicion);

ALTER TABLE clinico.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_id_condicion_fkey FOREIGN KEY (id_condicion) REFERENCES heuristico.condicion(id);

ALTER TABLE clinico.control_condicion_activa
    ADD CONSTRAINT control_condicion_activa_id_control_fkey FOREIGN KEY (id_control) REFERENCES clinico.control_paciente(id) ON DELETE CASCADE;

ALTER TABLE clinico.control_paciente
    ADD CONSTRAINT control_paciente_pkey PRIMARY KEY (id);

ALTER TABLE clinico.control_paciente
    ADD CONSTRAINT control_paciente_id_condicion_nutricional_resultado_fkey FOREIGN KEY (id_condicion_nutricional_resultado) REFERENCES heuristico.condicion(id);

ALTER TABLE clinico.control_paciente
    ADD CONSTRAINT control_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE clinico.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_pkey PRIMARY KEY (id);

ALTER TABLE clinico.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_id_paciente_id_condicion_fecha_diagnos_key UNIQUE (id_paciente, id_condicion, fecha_diagnostico);

ALTER TABLE clinico.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_id_condicion_fkey FOREIGN KEY (id_condicion) REFERENCES heuristico.condicion(id);

ALTER TABLE clinico.diagnostico_paciente
    ADD CONSTRAINT diagnostico_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE nutricion.clasificacion_nutriente
    ADD CONSTRAINT clasificacion_nutriente_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.clasificacion_nutriente
    ADD CONSTRAINT clasificacion_nutriente_codigo_key UNIQUE (codigo);

ALTER TABLE nutricion.etiqueta_nutricional
    ADD CONSTRAINT etiqueta_nutricional_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.etiqueta_nutricional
    ADD CONSTRAINT etiqueta_nutricional_codigo_key UNIQUE (codigo);

ALTER TABLE nutricion.grupo_alimentario
    ADD CONSTRAINT grupo_alimentario_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.grupo_alimentario
    ADD CONSTRAINT grupo_alimentario_nombre_key UNIQUE (nombre);

ALTER TABLE nutricion.ingrediente
    ADD CONSTRAINT ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.ingrediente
    ADD CONSTRAINT ingrediente_nombre_key UNIQUE (nombre);

ALTER TABLE nutricion.ingrediente
    ADD CONSTRAINT ingrediente_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES nutricion.grupo_alimentario(id);

ALTER TABLE nutricion.ingrediente
    ADD CONSTRAINT ingrediente_id_subgrupo_alimentario_fkey FOREIGN KEY (id_subgrupo_alimentario) REFERENCES nutricion.subgrupo_alimentario(id);

ALTER TABLE nutricion.ingrediente_composicion
    ADD CONSTRAINT ingrediente_composicion_pkey PRIMARY KEY (id_ingrediente);

ALTER TABLE nutricion.ingrediente_composicion
    ADD CONSTRAINT ingrediente_composicion_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id) ON DELETE CASCADE;

ALTER TABLE nutricion.ingrediente_etiqueta
    ADD CONSTRAINT ingrediente_etiqueta_pkey PRIMARY KEY (id_ingrediente, id_etiqueta);

ALTER TABLE nutricion.ingrediente_etiqueta
    ADD CONSTRAINT ingrediente_etiqueta_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES nutricion.etiqueta_nutricional(id) ON DELETE CASCADE;

ALTER TABLE nutricion.ingrediente_etiqueta
    ADD CONSTRAINT ingrediente_etiqueta_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id) ON DELETE CASCADE;

ALTER TABLE nutricion.ingrediente_metrica
    ADD CONSTRAINT ingrediente_metrica_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.ingrediente_metrica
    ADD CONSTRAINT ingrediente_metrica_id_ingrediente_id_metrica_key UNIQUE (id_ingrediente, id_metrica);

ALTER TABLE nutricion.ingrediente_metrica
    ADD CONSTRAINT ingrediente_metrica_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id) ON DELETE CASCADE;

ALTER TABLE nutricion.ingrediente_metrica
    ADD CONSTRAINT ingrediente_metrica_id_metrica_fkey FOREIGN KEY (id_metrica) REFERENCES nutricion.metrica_def(id) ON DELETE CASCADE;

ALTER TABLE nutricion.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_id_ingrediente_id_nutriente_key UNIQUE (id_ingrediente, id_nutriente);

ALTER TABLE nutricion.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id) ON DELETE CASCADE;

ALTER TABLE nutricion.ingrediente_nutriente
    ADD CONSTRAINT ingrediente_nutriente_id_nutriente_fkey FOREIGN KEY (id_nutriente) REFERENCES nutricion.nutriente(id);

ALTER TABLE nutricion.ingrediente_sinonimo
    ADD CONSTRAINT ingrediente_sinonimo_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.ingrediente_sinonimo
    ADD CONSTRAINT ingrediente_sinonimo_id_ingrediente_sinonimo_key UNIQUE (id_ingrediente, sinonimo);

ALTER TABLE nutricion.ingrediente_sinonimo
    ADD CONSTRAINT ingrediente_sinonimo_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id) ON DELETE CASCADE;

ALTER TABLE nutricion.metrica_def
    ADD CONSTRAINT metrica_def_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.metrica_def
    ADD CONSTRAINT metrica_def_codigo_key UNIQUE (codigo);

ALTER TABLE nutricion.metrica_def
    ADD CONSTRAINT metrica_def_nombre_key UNIQUE (nombre);

ALTER TABLE nutricion.momento_comida
    ADD CONSTRAINT momento_comida_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.momento_comida
    ADD CONSTRAINT momento_comida_nombre_key UNIQUE (nombre);

ALTER TABLE nutricion.nutriente
    ADD CONSTRAINT nutriente_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.nutriente
    ADD CONSTRAINT nutriente_codigo_key UNIQUE (codigo);

ALTER TABLE nutricion.nutriente
    ADD CONSTRAINT nutriente_nombre_key UNIQUE (nombre);

ALTER TABLE nutricion.nutriente
    ADD CONSTRAINT nutriente_id_clasificacion_fkey FOREIGN KEY (id_clasificacion) REFERENCES nutricion.clasificacion_nutriente(id);

ALTER TABLE nutricion.receta
    ADD CONSTRAINT receta_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.receta_imagen
    ADD CONSTRAINT receta_imagen_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.receta_imagen
    ADD CONSTRAINT receta_imagen_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id) ON DELETE CASCADE;

ALTER TABLE nutricion.receta_ingrediente
    ADD CONSTRAINT receta_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.receta_ingrediente
    ADD CONSTRAINT receta_ingrediente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id);

ALTER TABLE nutricion.receta_ingrediente
    ADD CONSTRAINT receta_ingrediente_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id) ON DELETE CASCADE;

ALTER TABLE nutricion.receta_momento
    ADD CONSTRAINT receta_momento_pkey PRIMARY KEY (id_receta, id_momento);

ALTER TABLE nutricion.receta_momento
    ADD CONSTRAINT receta_momento_id_momento_fkey FOREIGN KEY (id_momento) REFERENCES nutricion.momento_comida(id);

ALTER TABLE nutricion.receta_momento
    ADD CONSTRAINT receta_momento_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id) ON DELETE CASCADE;

ALTER TABLE nutricion.receta_nutriente_calculado
    ADD CONSTRAINT receta_nutriente_calculado_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.receta_nutriente_calculado
    ADD CONSTRAINT receta_nutriente_calculado_id_receta_id_nutriente_key UNIQUE (id_receta, id_nutriente);

ALTER TABLE nutricion.receta_nutriente_calculado
    ADD CONSTRAINT receta_nutriente_calculado_id_nutriente_fkey FOREIGN KEY (id_nutriente) REFERENCES nutricion.nutriente(id);

ALTER TABLE nutricion.receta_nutriente_calculado
    ADD CONSTRAINT receta_nutriente_calculado_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id) ON DELETE CASCADE;

ALTER TABLE nutricion.receta_tipo_plato
    ADD CONSTRAINT receta_tipo_plato_pkey PRIMARY KEY (id_receta, id_tipo_plato);

ALTER TABLE nutricion.receta_tipo_plato
    ADD CONSTRAINT receta_tipo_plato_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id) ON DELETE CASCADE;

ALTER TABLE nutricion.receta_tipo_plato
    ADD CONSTRAINT receta_tipo_plato_id_tipo_plato_fkey FOREIGN KEY (id_tipo_plato) REFERENCES nutricion.tipo_plato(id);

ALTER TABLE nutricion.subgrupo_alimentario
    ADD CONSTRAINT subgrupo_alimentario_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.subgrupo_alimentario
    ADD CONSTRAINT subgrupo_alimentario_id_grupo_alimentario_nombre_key UNIQUE (id_grupo_alimentario, nombre);

ALTER TABLE nutricion.subgrupo_alimentario
    ADD CONSTRAINT subgrupo_alimentario_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES nutricion.grupo_alimentario(id);

ALTER TABLE nutricion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_id_ingrediente_original_id_ingredient_key UNIQUE (id_ingrediente_original, id_ingrediente_reemplazo);

ALTER TABLE nutricion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_id_ingrediente_original_fkey FOREIGN KEY (id_ingrediente_original) REFERENCES nutricion.ingrediente(id);

ALTER TABLE nutricion.sustituto_ingrediente
    ADD CONSTRAINT sustituto_ingrediente_id_ingrediente_reemplazo_fkey FOREIGN KEY (id_ingrediente_reemplazo) REFERENCES nutricion.ingrediente(id);

ALTER TABLE nutricion.tipo_plato
    ADD CONSTRAINT tipo_plato_pkey PRIMARY KEY (id);

ALTER TABLE nutricion.tipo_plato
    ADD CONSTRAINT tipo_plato_nombre_key UNIQUE (nombre);

ALTER TABLE heuristico.catalogo_accion
    ADD CONSTRAINT catalogo_accion_pkey PRIMARY KEY (id);

ALTER TABLE heuristico.catalogo_accion
    ADD CONSTRAINT catalogo_accion_codigo_key UNIQUE (codigo);

ALTER TABLE heuristico.catalogo_objetivo_regla
    ADD CONSTRAINT catalogo_objetivo_regla_pkey PRIMARY KEY (id);

ALTER TABLE heuristico.catalogo_objetivo_regla
    ADD CONSTRAINT catalogo_objetivo_regla_codigo_key UNIQUE (codigo);

ALTER TABLE heuristico.catalogo_tipo_condicion
    ADD CONSTRAINT catalogo_tipo_condicion_pkey PRIMARY KEY (id);

ALTER TABLE heuristico.catalogo_tipo_condicion
    ADD CONSTRAINT catalogo_tipo_condicion_codigo_key UNIQUE (codigo);

ALTER TABLE heuristico.catalogo_tipo_condicion
    ADD CONSTRAINT catalogo_tipo_condicion_nombre_key UNIQUE (nombre);

ALTER TABLE heuristico.condicion
    ADD CONSTRAINT condicion_pkey PRIMARY KEY (id);

ALTER TABLE heuristico.condicion
    ADD CONSTRAINT condicion_nombre_id_tipo_condicion_key UNIQUE (nombre, id_tipo_condicion);

ALTER TABLE heuristico.condicion
    ADD CONSTRAINT condicion_id_tipo_condicion_fkey FOREIGN KEY (id_tipo_condicion) REFERENCES heuristico.catalogo_tipo_condicion(id);

ALTER TABLE heuristico.condicion_regla
    ADD CONSTRAINT condicion_regla_pkey PRIMARY KEY (id);

ALTER TABLE heuristico.condicion_regla
    ADD CONSTRAINT condicion_regla_id_condicion_id_regla_key UNIQUE (id_condicion, id_regla);

ALTER TABLE heuristico.condicion_regla
    ADD CONSTRAINT condicion_regla_id_condicion_fkey FOREIGN KEY (id_condicion) REFERENCES heuristico.condicion(id);

ALTER TABLE heuristico.condicion_regla
    ADD CONSTRAINT condicion_regla_id_regla_fkey FOREIGN KEY (id_regla) REFERENCES heuristico.regla(id) ON DELETE CASCADE;

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_pkey PRIMARY KEY (id);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_check CHECK ((
CASE
    WHEN id_ingrediente IS NOT NULL THEN 1
    ELSE 0
END +
CASE
    WHEN id_grupo_alimentario IS NOT NULL THEN 1
    ELSE 0
END +
CASE
    WHEN id_etiqueta IS NOT NULL THEN 1
    ELSE 0
END) = 1);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_created_by_fkey FOREIGN KEY (created_by) REFERENCES usuarios.usuario(id);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_id_accion_fkey FOREIGN KEY (id_accion) REFERENCES heuristico.catalogo_accion(id);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES nutricion.etiqueta_nutricional(id);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_id_grupo_alimentario_fkey FOREIGN KEY (id_grupo_alimentario) REFERENCES nutricion.grupo_alimentario(id);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id);

ALTER TABLE heuristico.regla
    ADD CONSTRAINT regla_id_tipo_objetivo_fkey FOREIGN KEY (id_tipo_objetivo) REFERENCES heuristico.catalogo_objetivo_regla(id);

ALTER TABLE interaccion.catalogo_estado_consumo
    ADD CONSTRAINT catalogo_estado_consumo_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.catalogo_estado_consumo
    ADD CONSTRAINT catalogo_estado_consumo_codigo_key UNIQUE (codigo);

ALTER TABLE interaccion.catalogo_estado_plan
    ADD CONSTRAINT catalogo_estado_plan_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.catalogo_estado_plan
    ADD CONSTRAINT catalogo_estado_plan_codigo_key UNIQUE (codigo);

ALTER TABLE interaccion.catalogo_motivo_rechazo
    ADD CONSTRAINT catalogo_motivo_rechazo_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.catalogo_motivo_rechazo
    ADD CONSTRAINT catalogo_motivo_rechazo_nombre_key UNIQUE (nombre);

ALTER TABLE interaccion.catalogo_origen_plan
    ADD CONSTRAINT catalogo_origen_plan_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.catalogo_origen_plan
    ADD CONSTRAINT catalogo_origen_plan_codigo_key UNIQUE (codigo);

ALTER TABLE interaccion.catalogo_tipo_plan
    ADD CONSTRAINT catalogo_tipo_plan_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.catalogo_tipo_plan
    ADD CONSTRAINT catalogo_tipo_plan_codigo_key UNIQUE (codigo);

ALTER TABLE interaccion.config_analisis_rechazo
    ADD CONSTRAINT config_analisis_rechazo_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.config_analisis_rechazo
    ADD CONSTRAINT config_analisis_rechazo_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES usuarios.usuario(id);

ALTER TABLE interaccion.config_analisis_rechazo
    ADD CONSTRAINT config_analisis_rechazo_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id) ON DELETE CASCADE;

ALTER TABLE interaccion.config_analisis_rechazo
    ADD CONSTRAINT config_analisis_rechazo_id_plan_fkey FOREIGN KEY (id_plan) REFERENCES interaccion.plan_nutricional(id) ON DELETE CASCADE;

ALTER TABLE interaccion.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_estrellas_check CHECK (estrellas >= 1 AND estrellas <= 5);

ALTER TABLE interaccion.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_id_motivo_rechazo_fkey FOREIGN KEY (id_motivo_rechazo) REFERENCES interaccion.catalogo_motivo_rechazo(id);

ALTER TABLE interaccion.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE interaccion.evaluacion_receta
    ADD CONSTRAINT evaluacion_receta_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id);

ALTER TABLE interaccion.plan_item
    ADD CONSTRAINT plan_item_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.plan_item
    ADD CONSTRAINT plan_item_id_momento_fkey FOREIGN KEY (id_momento) REFERENCES nutricion.momento_comida(id);

ALTER TABLE interaccion.plan_item
    ADD CONSTRAINT plan_item_id_plan_fkey FOREIGN KEY (id_plan) REFERENCES interaccion.plan_nutricional(id) ON DELETE CASCADE;

ALTER TABLE interaccion.plan_item
    ADD CONSTRAINT plan_item_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id);

ALTER TABLE interaccion.plan_nutricional
    ADD CONSTRAINT plan_nutricional_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.plan_nutricional
    ADD CONSTRAINT plan_nutricional_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES usuarios.usuario(id);

ALTER TABLE interaccion.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_estado_plan_fkey FOREIGN KEY (id_estado_plan) REFERENCES interaccion.catalogo_estado_plan(id);

ALTER TABLE interaccion.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_origen_plan_fkey FOREIGN KEY (id_origen_plan) REFERENCES interaccion.catalogo_origen_plan(id);

ALTER TABLE interaccion.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE interaccion.plan_nutricional
    ADD CONSTRAINT plan_nutricional_id_tipo_plan_fkey FOREIGN KEY (id_tipo_plan) REFERENCES interaccion.catalogo_tipo_plan(id);

ALTER TABLE interaccion.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_id_paciente_id_ingrediente_key UNIQUE (id_paciente, id_ingrediente);

ALTER TABLE interaccion.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_id_ingrediente_fkey FOREIGN KEY (id_ingrediente) REFERENCES nutricion.ingrediente(id);

ALTER TABLE interaccion.preferencia_ingrediente
    ADD CONSTRAINT preferencia_ingrediente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE interaccion.preferencia_receta
    ADD CONSTRAINT preferencia_receta_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.preferencia_receta
    ADD CONSTRAINT preferencia_receta_id_paciente_id_receta_key UNIQUE (id_paciente, id_receta);

ALTER TABLE interaccion.preferencia_receta
    ADD CONSTRAINT preferencia_receta_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE interaccion.preferencia_receta
    ADD CONSTRAINT preferencia_receta_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id);

ALTER TABLE interaccion.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_momento_fkey FOREIGN KEY (id_momento) REFERENCES nutricion.momento_comida(id);

ALTER TABLE interaccion.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_motivo_rechazo_fkey FOREIGN KEY (id_motivo_rechazo) REFERENCES interaccion.catalogo_motivo_rechazo(id);

ALTER TABLE interaccion.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES usuarios.paciente(id);

ALTER TABLE interaccion.recomendacion_puntual
    ADD CONSTRAINT recomendacion_puntual_id_receta_fkey FOREIGN KEY (id_receta) REFERENCES nutricion.receta(id);

ALTER TABLE interaccion.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_pkey PRIMARY KEY (id);

ALTER TABLE interaccion.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_estado_consumo_fkey FOREIGN KEY (id_estado_consumo) REFERENCES interaccion.catalogo_estado_consumo(id);

ALTER TABLE interaccion.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_plan_item_fkey FOREIGN KEY (id_plan_item) REFERENCES interaccion.plan_item(id) ON DELETE CASCADE;

ALTER TABLE interaccion.seguimiento_plan_item
    ADD CONSTRAINT seguimiento_plan_item_id_receta_reemplazo_fkey FOREIGN KEY (id_receta_reemplazo) REFERENCES nutricion.receta(id);

ALTER TABLE referencia.indicador_antropometrico
    ADD CONSTRAINT indicador_antropometrico_pkey PRIMARY KEY (id);

ALTER TABLE referencia.indicador_antropometrico
    ADD CONSTRAINT indicador_antropometrico_codigo_key UNIQUE (codigo);

ALTER TABLE referencia.oms_curva
    ADD CONSTRAINT oms_curva_pkey PRIMARY KEY (id);

ALTER TABLE referencia.oms_curva
    ADD CONSTRAINT oms_curva_codigo_key UNIQUE (codigo);

ALTER TABLE referencia.oms_curva
    ADD CONSTRAINT oms_curva_tipo_curva_check CHECK (tipo_curva::text = ANY (ARRAY['ZSCORE'::character varying, 'PERCENTIL'::character varying]::text[]));

ALTER TABLE referencia.oms_curva
    ADD CONSTRAINT oms_curva_id_indicador_fkey FOREIGN KEY (id_indicador) REFERENCES referencia.indicador_antropometrico(id);

ALTER TABLE referencia.oms_curva
    ADD CONSTRAINT oms_curva_id_sexo_fkey FOREIGN KEY (id_sexo) REFERENCES usuarios.catalogo_sexo(id);

ALTER TABLE referencia.oms_curva_percentil
    ADD CONSTRAINT oms_curva_percentil_pkey PRIMARY KEY (id);

ALTER TABLE referencia.oms_curva_percentil
    ADD CONSTRAINT oms_curva_percentil_id_curva_edad_valor_percentil_codigo_key UNIQUE (id_curva, edad_valor, percentil_codigo);

ALTER TABLE referencia.oms_curva_percentil
    ADD CONSTRAINT oms_curva_percentil_id_curva_fkey FOREIGN KEY (id_curva) REFERENCES referencia.oms_curva(id) ON DELETE CASCADE;

ALTER TABLE referencia.oms_curva_punto
    ADD CONSTRAINT oms_curva_punto_pkey PRIMARY KEY (id);

ALTER TABLE referencia.oms_curva_punto
    ADD CONSTRAINT oms_curva_punto_id_curva_edad_valor_key UNIQUE (id_curva, edad_valor);

ALTER TABLE referencia.oms_curva_punto
    ADD CONSTRAINT oms_curva_punto_id_curva_fkey FOREIGN KEY (id_curva) REFERENCES referencia.oms_curva(id) ON DELETE CASCADE;

-- =====================================================
-- INDICES
-- =====================================================
CREATE INDEX idx_ingrediente_nombre_trgm ON nutricion.ingrediente USING gin (nombre gin_trgm_ops);
CREATE INDEX idx_ingrediente_sinonimo_trgm ON nutricion.ingrediente_sinonimo USING gin (sinonimo gin_trgm_ops);
