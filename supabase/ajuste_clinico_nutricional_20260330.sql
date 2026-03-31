-- Ajustes incrementales para modelo clinico-nutricional pediatrico
-- Restricciones respetadas:
-- 1) No modifica estructura del esquema referencia
-- 2) No modifica estructura de usuarios.catalogo_sexo

-- =====================================================
-- 1) HEURISTICO: acciones validas + contexto brote/vigencia
-- =====================================================

ALTER TABLE heuristico.catalogo_accion
    ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

DO $$
DECLARE
    v_id_reducir INTEGER;
    v_id_disminuir INTEGER;
BEGIN
    SELECT id INTO v_id_reducir
    FROM heuristico.catalogo_accion
    WHERE UPPER(codigo) = 'REDUCIR'
    ORDER BY id
    LIMIT 1;

    SELECT id INTO v_id_disminuir
    FROM heuristico.catalogo_accion
    WHERE UPPER(codigo) = 'DISMINUIR'
    ORDER BY id
    LIMIT 1;

    IF v_id_reducir IS NOT NULL AND v_id_disminuir IS NOT NULL AND v_id_reducir <> v_id_disminuir THEN
        UPDATE heuristico.regla
        SET id_accion = v_id_disminuir
        WHERE id_accion = v_id_reducir;

        DELETE FROM heuristico.catalogo_accion
        WHERE id = v_id_reducir;
    ELSIF v_id_reducir IS NOT NULL AND v_id_disminuir IS NULL THEN
        UPDATE heuristico.catalogo_accion
        SET codigo = 'DISMINUIR'
        WHERE id = v_id_reducir;
    END IF;
END $$;

INSERT INTO heuristico.catalogo_accion (codigo, peso_puntaje, activo)
VALUES
    ('ELIMINAR', -100, TRUE),
    ('DISMINUIR', -40, TRUE),
    ('PRIORIZAR', 50, TRUE)
ON CONFLICT (codigo) DO UPDATE
SET
    peso_puntaje = EXCLUDED.peso_puntaje,
    activo = TRUE;

UPDATE heuristico.catalogo_accion
SET activo = FALSE
WHERE UPPER(codigo) NOT IN ('ELIMINAR', 'DISMINUIR', 'PRIORIZAR');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_catalogo_accion_valida'
    ) THEN
        ALTER TABLE heuristico.catalogo_accion
        ADD CONSTRAINT ck_catalogo_accion_valida
        CHECK ((NOT activo) OR UPPER(codigo) IN ('ELIMINAR', 'DISMINUIR', 'PRIORIZAR')) NOT VALID;
    END IF;
END $$;

ALTER TABLE heuristico.regla
    ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE heuristico.regla
    ADD COLUMN IF NOT EXISTS aplica_brote VARCHAR(20) NOT NULL DEFAULT 'AMBOS';
ALTER TABLE heuristico.regla
    ADD COLUMN IF NOT EXISTS fecha_inicio_vigencia DATE;
ALTER TABLE heuristico.regla
    ADD COLUMN IF NOT EXISTS fecha_fin_vigencia DATE;
ALTER TABLE heuristico.regla
    ADD COLUMN IF NOT EXISTS prioridad_manual SMALLINT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_regla_aplica_brote') THEN
        ALTER TABLE heuristico.regla
        ADD CONSTRAINT ck_regla_aplica_brote
        CHECK (UPPER(aplica_brote) IN ('AMBOS', 'SOLO_BROTE', 'SOLO_ESTABLE')) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_regla_rango_fechas') THEN
        ALTER TABLE heuristico.regla
        ADD CONSTRAINT ck_regla_rango_fechas
        CHECK (
            fecha_fin_vigencia IS NULL
            OR fecha_inicio_vigencia IS NULL
            OR fecha_fin_vigencia >= fecha_inicio_vigencia
        ) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_regla_prioridad_manual') THEN
        ALTER TABLE heuristico.regla
        ADD CONSTRAINT ck_regla_prioridad_manual
        CHECK (prioridad_manual IS NULL OR prioridad_manual BETWEEN -100 AND 100) NOT VALID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_condicion_regla_condicion ON heuristico.condicion_regla(id_condicion);
CREATE INDEX IF NOT EXISTS idx_condicion_regla_regla ON heuristico.condicion_regla(id_regla);
CREATE INDEX IF NOT EXISTS idx_regla_activa_brote ON heuristico.regla(activo, aplica_brote);

-- =====================================================
-- 2) CLINICO: control principal con trazabilidad y checks
-- =====================================================

ALTER TABLE clinico.control_paciente
    ADD COLUMN IF NOT EXISTS id_usuario_registra UUID REFERENCES usuarios.usuario(id);
ALTER TABLE clinico.control_paciente
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT NOW();

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_peso_positivo') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_peso_positivo
        CHECK (peso_kg > 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_talla_positiva') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_talla_positiva
        CHECK (talla_cm > 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_edad_meses_rango') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_edad_meses_rango
        CHECK (edad_meses BETWEEN 0 AND 240) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_nivel_dolor') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_nivel_dolor
        CHECK (nivel_dolor_eva IS NULL OR nivel_dolor_eva BETWEEN 0 AND 10) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_nivel_inflamacion') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_nivel_inflamacion
        CHECK (nivel_inflamacion IS NULL OR nivel_inflamacion BETWEEN 0 AND 10) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_nivel_fatiga') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_nivel_fatiga
        CHECK (nivel_fatiga IS NULL OR nivel_fatiga BETWEEN 0 AND 10) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_rigidez_no_negativa') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_rigidez_no_negativa
        CHECK (minutos_rigidez_matutina IS NULL OR minutos_rigidez_matutina >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_control_pcr_no_negativa') THEN
        ALTER TABLE clinico.control_paciente
        ADD CONSTRAINT ck_control_pcr_no_negativa
        CHECK (inflamacion_pcr IS NULL OR inflamacion_pcr >= 0) NOT VALID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_control_paciente_brote_fecha
    ON clinico.control_paciente(id_paciente, hay_brote_activo, fecha_control DESC);
CREATE INDEX IF NOT EXISTS idx_control_paciente_condicion_nutricional
    ON clinico.control_paciente(id_condicion_nutricional_resultado);
CREATE INDEX IF NOT EXISTS idx_diagnostico_paciente_activo
    ON clinico.diagnostico_paciente(id_paciente, activa);
CREATE INDEX IF NOT EXISTS idx_alergia_ingrediente_paciente_activa
    ON clinico.alergia_paciente_ingrediente(id_paciente) WHERE activa = TRUE;
CREATE INDEX IF NOT EXISTS idx_alergia_grupo_paciente_activa
    ON clinico.alergia_paciente_grupo(id_paciente) WHERE activa = TRUE;

-- =====================================================
-- 3) NUTRICION: nutrientes, sinonimos, resumen de receta y costo
-- =====================================================

ALTER TABLE nutricion.nutriente
    ADD COLUMN IF NOT EXISTS categoria VARCHAR(20) NOT NULL DEFAULT 'OTRO';
ALTER TABLE nutricion.nutriente
    ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE nutricion.nutriente
    ADD COLUMN IF NOT EXISTS orden_reporte INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_nutriente_categoria') THEN
        ALTER TABLE nutricion.nutriente
        ADD CONSTRAINT ck_nutriente_categoria
        CHECK (UPPER(categoria) IN ('MACRO', 'MINERAL', 'VITAMINA', 'OTRO')) NOT VALID;
    END IF;
END $$;

INSERT INTO nutricion.nutriente (codigo, nombre, unidad_medida, categoria, orden_reporte)
VALUES
    ('CALORIAS', 'Calorias', 'kcal', 'MACRO', 1),
    ('PROTEINA', 'Proteina', 'g', 'MACRO', 2),
    ('CARBOHIDRATOS', 'Carbohidratos', 'g', 'MACRO', 3),
    ('GRASA_TOTAL', 'Grasa total', 'g', 'MACRO', 4),
    ('GRASA_SATURADA', 'Grasa saturada', 'g', 'MACRO', 5),
    ('GRASA_TRANS', 'Grasa trans', 'g', 'MACRO', 6),
    ('FIBRA', 'Fibra', 'g', 'MACRO', 7),
    ('AZUCAR_TOTAL', 'Azucar total', 'g', 'MACRO', 8),
    ('AZUCAR_ANADIDA', 'Azucar anadida', 'g', 'MACRO', 9),
    ('COLESTEROL', 'Colesterol', 'mg', 'OTRO', 10),
    ('SODIO', 'Sodio', 'mg', 'OTRO', 11),
    ('CALCIO', 'Calcio', 'mg', 'MINERAL', 12),
    ('HIERRO', 'Hierro', 'mg', 'MINERAL', 13),
    ('ZINC', 'Zinc', 'mg', 'MINERAL', 14),
    ('MAGNESIO', 'Magnesio', 'mg', 'MINERAL', 15),
    ('POTASIO', 'Potasio', 'mg', 'MINERAL', 16),
    ('FOSFORO', 'Fosforo', 'mg', 'MINERAL', 17),
    ('VITAMINA_A', 'Vitamina A', 'ug', 'VITAMINA', 18),
    ('VITAMINA_C', 'Vitamina C', 'mg', 'VITAMINA', 19),
    ('VITAMINA_D', 'Vitamina D', 'ug', 'VITAMINA', 20),
    ('VITAMINA_E', 'Vitamina E', 'mg', 'VITAMINA', 21),
    ('VITAMINA_K', 'Vitamina K', 'ug', 'VITAMINA', 22),
    ('VITAMINA_B1', 'Vitamina B1', 'mg', 'VITAMINA', 23),
    ('VITAMINA_B2', 'Vitamina B2', 'mg', 'VITAMINA', 24),
    ('VITAMINA_B3', 'Vitamina B3', 'mg', 'VITAMINA', 25),
    ('VITAMINA_B6', 'Vitamina B6', 'mg', 'VITAMINA', 26),
    ('VITAMINA_B9', 'Vitamina B9', 'ug', 'VITAMINA', 27),
    ('VITAMINA_B12', 'Vitamina B12', 'ug', 'VITAMINA', 28)
ON CONFLICT (codigo) DO UPDATE
SET
    nombre = EXCLUDED.nombre,
    unidad_medida = EXCLUDED.unidad_medida,
    categoria = EXCLUDED.categoria,
    orden_reporte = EXCLUDED.orden_reporte;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ingrediente_nutriente_valor') THEN
        ALTER TABLE nutricion.ingrediente_nutriente
        ADD CONSTRAINT ck_ingrediente_nutriente_valor
        CHECK (valor_por_100g >= 0) NOT VALID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ingrediente_nutriente_ingrediente
    ON nutricion.ingrediente_nutriente(id_ingrediente);
CREATE INDEX IF NOT EXISTS idx_ingrediente_nutriente_nutriente
    ON nutricion.ingrediente_nutriente(id_nutriente);
CREATE INDEX IF NOT EXISTS idx_receta_ingrediente_receta
    ON nutricion.receta_ingrediente(id_receta);
CREATE INDEX IF NOT EXISTS idx_receta_ingrediente_ingrediente
    ON nutricion.receta_ingrediente(id_ingrediente);

ALTER TABLE nutricion.ingrediente
    ADD COLUMN IF NOT EXISTS costo_estimado_por_100g NUMERIC(10,2);
ALTER TABLE nutricion.ingrediente
    ADD COLUMN IF NOT EXISTS moneda_costo VARCHAR(3) NOT NULL DEFAULT 'PEN';

ALTER TABLE nutricion.receta
    ADD COLUMN IF NOT EXISTS costo_estimado_total NUMERIC(10,2);
ALTER TABLE nutricion.receta
    ADD COLUMN IF NOT EXISTS agua_ml_por_porcion NUMERIC(10,2);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ingrediente_costo_positivo') THEN
        ALTER TABLE nutricion.ingrediente
        ADD CONSTRAINT ck_ingrediente_costo_positivo
        CHECK (costo_estimado_por_100g IS NULL OR costo_estimado_por_100g >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_ingrediente_moneda_formato') THEN
        ALTER TABLE nutricion.ingrediente
        ADD CONSTRAINT ck_ingrediente_moneda_formato
        CHECK (char_length(moneda_costo) = 3) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_receta_costo_positivo') THEN
        ALTER TABLE nutricion.receta
        ADD CONSTRAINT ck_receta_costo_positivo
        CHECK (costo_estimado_total IS NULL OR costo_estimado_total >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_receta_agua_positiva') THEN
        ALTER TABLE nutricion.receta
        ADD CONSTRAINT ck_receta_agua_positiva
        CHECK (agua_ml_por_porcion IS NULL OR agua_ml_por_porcion >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_receta_score_antiinflamatorio') THEN
        ALTER TABLE nutricion.receta
        ADD CONSTRAINT ck_receta_score_antiinflamatorio
        CHECK (score_antiinflamatorio IS NULL OR score_antiinflamatorio BETWEEN -100 AND 100) NOT VALID;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS nutricion.ingrediente_sinonimo (
    id BIGSERIAL PRIMARY KEY,
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id) ON DELETE CASCADE,
    nombre_sinonimo VARCHAR(150) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_ingrediente, nombre_sinonimo)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_ingrediente_sinonimo_nombre_activo
    ON nutricion.ingrediente_sinonimo ((LOWER(BTRIM(nombre_sinonimo))))
    WHERE activo = TRUE;

CREATE INDEX IF NOT EXISTS idx_ingrediente_sinonimo_ingrediente
    ON nutricion.ingrediente_sinonimo(id_ingrediente);

CREATE TABLE IF NOT EXISTS nutricion.receta_nutriente_resumen (
    id BIGSERIAL PRIMARY KEY,
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id) ON DELETE CASCADE,
    id_nutriente INTEGER NOT NULL REFERENCES nutricion.nutriente(id),
    valor_por_receta NUMERIC(12,4) NOT NULL,
    valor_por_porcion NUMERIC(12,4),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_receta, id_nutriente),
    CHECK (valor_por_receta >= 0),
    CHECK (valor_por_porcion IS NULL OR valor_por_porcion >= 0)
);

CREATE INDEX IF NOT EXISTS idx_receta_nutriente_resumen_receta
    ON nutricion.receta_nutriente_resumen(id_receta);
CREATE INDEX IF NOT EXISTS idx_receta_nutriente_resumen_nutriente
    ON nutricion.receta_nutriente_resumen(id_nutriente);

-- =====================================================
-- 4) OBJETIVO NUTRICIONAL DEL PACIENTE
-- =====================================================

CREATE TABLE IF NOT EXISTS clinico.objetivo_nutricional_paciente (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_control_base BIGINT NOT NULL REFERENCES clinico.control_paciente(id),
    origen_calculo VARCHAR(20) NOT NULL DEFAULT 'SISTEMA',
    estado VARCHAR(20) NOT NULL DEFAULT 'VIGENTE',
    validado_medico BOOLEAN NOT NULL DEFAULT FALSE,
    id_usuario_medico_valida UUID REFERENCES usuarios.usuario(id),
    fecha_validacion_medica TIMESTAMP,
    ajustado_nutricionista BOOLEAN NOT NULL DEFAULT FALSE,
    id_usuario_nutricionista_ajusta UUID REFERENCES usuarios.usuario(id),
    fecha_ajuste_nutricionista TIMESTAMP,
    observacion TEXT,
    vigente BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (UPPER(origen_calculo) IN ('SISTEMA', 'MEDICO', 'NUTRICIONISTA')),
    CHECK (UPPER(estado) IN ('BORRADOR', 'VIGENTE', 'CERRADO')),
    CHECK ((NOT validado_medico) OR id_usuario_medico_valida IS NOT NULL),
    CHECK ((NOT ajustado_nutricionista) OR id_usuario_nutricionista_ajusta IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_objetivo_nutricional_vigente_paciente
    ON clinico.objetivo_nutricional_paciente(id_paciente)
    WHERE vigente = TRUE;

CREATE INDEX IF NOT EXISTS idx_objetivo_nutricional_control_base
    ON clinico.objetivo_nutricional_paciente(id_control_base);

CREATE TABLE IF NOT EXISTS clinico.objetivo_nutricional_nutriente (
    id BIGSERIAL PRIMARY KEY,
    id_objetivo BIGINT NOT NULL REFERENCES clinico.objetivo_nutricional_paciente(id) ON DELETE CASCADE,
    id_nutriente INTEGER NOT NULL REFERENCES nutricion.nutriente(id),
    valor_minimo NUMERIC(12,4),
    valor_objetivo NUMERIC(12,4),
    valor_maximo NUMERIC(12,4),
    unidad_objetivo VARCHAR(20),
    obligatorio BOOLEAN NOT NULL DEFAULT FALSE,
    observacion TEXT,
    UNIQUE (id_objetivo, id_nutriente),
    CHECK (COALESCE(valor_minimo, valor_objetivo, valor_maximo) IS NOT NULL),
    CHECK (valor_minimo IS NULL OR valor_minimo >= 0),
    CHECK (valor_objetivo IS NULL OR valor_objetivo >= 0),
    CHECK (valor_maximo IS NULL OR valor_maximo >= 0),
    CHECK (valor_minimo IS NULL OR valor_maximo IS NULL OR valor_minimo <= valor_maximo),
    CHECK (valor_objetivo IS NULL OR valor_minimo IS NULL OR valor_objetivo >= valor_minimo),
    CHECK (valor_objetivo IS NULL OR valor_maximo IS NULL OR valor_objetivo <= valor_maximo)
);

CREATE INDEX IF NOT EXISTS idx_objetivo_nutricional_nutriente_objetivo
    ON clinico.objetivo_nutricional_nutriente(id_objetivo);

CREATE TABLE IF NOT EXISTS clinico.objetivo_nutricional_restriccion (
    id BIGSERIAL PRIMARY KEY,
    id_objetivo BIGINT NOT NULL REFERENCES clinico.objetivo_nutricional_paciente(id) ON DELETE CASCADE,
    tipo_accion VARCHAR(20) NOT NULL,
    id_ingrediente INTEGER REFERENCES nutricion.ingrediente(id),
    id_grupo_alimentario INTEGER REFERENCES nutricion.grupo_alimentario(id),
    id_etiqueta INTEGER REFERENCES nutricion.etiqueta_nutricional(id),
    fecha_inicio DATE,
    fecha_fin DATE,
    motivo TEXT,
    created_by UUID REFERENCES usuarios.usuario(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (UPPER(tipo_accion) IN ('ELIMINAR', 'DISMINUIR', 'PRIORIZAR')),
    CHECK (
        (id_ingrediente IS NOT NULL)::INT
      + (id_grupo_alimentario IS NOT NULL)::INT
      + (id_etiqueta IS NOT NULL)::INT = 1
    ),
    CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE INDEX IF NOT EXISTS idx_objetivo_restriccion_objetivo
    ON clinico.objetivo_nutricional_restriccion(id_objetivo);

-- =====================================================
-- 5) REEMPLAZO DE RECETA (receta->receta) con compatibilidad de momento
-- =====================================================

CREATE TABLE IF NOT EXISTS nutricion.momento_compatible (
    id_momento_origen INTEGER NOT NULL REFERENCES nutricion.momento_comida(id),
    id_momento_compatible INTEGER NOT NULL REFERENCES nutricion.momento_comida(id),
    PRIMARY KEY (id_momento_origen, id_momento_compatible),
    CHECK (id_momento_origen <> id_momento_compatible)
);

CREATE TABLE IF NOT EXISTS nutricion.receta_reemplazo_equivalente (
    id BIGSERIAL PRIMARY KEY,
    id_receta_origen INTEGER NOT NULL REFERENCES nutricion.receta(id) ON DELETE CASCADE,
    id_receta_reemplazo INTEGER NOT NULL REFERENCES nutricion.receta(id) ON DELETE CASCADE,
    id_momento_origen INTEGER NOT NULL REFERENCES nutricion.momento_comida(id),
    id_momento_reemplazo INTEGER NOT NULL REFERENCES nutricion.momento_comida(id),
    similitud_nutricional_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    variacion_kcal_pct NUMERIC(6,2),
    variacion_proteina_pct NUMERIC(6,2),
    prioridad SMALLINT NOT NULL DEFAULT 100,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    observacion TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (id_receta_origen <> id_receta_reemplazo),
    CHECK (similitud_nutricional_pct BETWEEN 0 AND 100),
    CHECK (variacion_kcal_pct IS NULL OR variacion_kcal_pct BETWEEN -100 AND 100),
    CHECK (variacion_proteina_pct IS NULL OR variacion_proteina_pct BETWEEN -100 AND 100),
    UNIQUE (id_receta_origen, id_receta_reemplazo, id_momento_origen, id_momento_reemplazo)
);

CREATE INDEX IF NOT EXISTS idx_receta_reemplazo_origen
    ON nutricion.receta_reemplazo_equivalente(id_receta_origen, id_momento_origen)
    WHERE activa = TRUE;

-- =====================================================
-- 6) ACTIVIDAD + HIDRATACION + NOTAS (variables de apoyo del tutor)
-- =====================================================

CREATE TABLE IF NOT EXISTS interaccion.catalogo_nivel_actividad (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    descripcion VARCHAR(120),
    CHECK (UPPER(codigo) IN ('MUY_BAJA', 'BAJA', 'MODERADA', 'ALTA'))
);

INSERT INTO interaccion.catalogo_nivel_actividad (codigo, descripcion)
VALUES
    ('MUY_BAJA', 'Movimiento minimo o reposo'),
    ('BAJA', 'Actividad ligera'),
    ('MODERADA', 'Actividad regular'),
    ('ALTA', 'Actividad frecuente')
ON CONFLICT (codigo) DO NOTHING;

CREATE TABLE IF NOT EXISTS interaccion.perfil_apoyo_tutor_paciente (
    id BIGSERIAL PRIMARY KEY,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    id_nivel_actividad_actual INTEGER NOT NULL REFERENCES interaccion.catalogo_nivel_actividad(id),
    meta_agua_diaria_ml INTEGER,
    notas TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_usuario_tutor, id_paciente),
    FOREIGN KEY (id_usuario_tutor, id_paciente)
        REFERENCES usuarios.tutor_paciente(id_usuario_tutor, id_paciente)
        ON DELETE CASCADE,
    CHECK (meta_agua_diaria_ml IS NULL OR meta_agua_diaria_ml BETWEEN 0 AND 12000)
);

CREATE TABLE IF NOT EXISTS interaccion.registro_apoyo_diario (
    id BIGSERIAL PRIMARY KEY,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    fecha_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    id_nivel_actividad INTEGER REFERENCES interaccion.catalogo_nivel_actividad(id),
    minutos_actividad INTEGER,
    agua_ml INTEGER,
    nota TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_usuario_tutor, id_paciente, fecha_registro),
    FOREIGN KEY (id_usuario_tutor, id_paciente)
        REFERENCES usuarios.tutor_paciente(id_usuario_tutor, id_paciente)
        ON DELETE CASCADE,
    CHECK (minutos_actividad IS NULL OR minutos_actividad >= 0),
    CHECK (agua_ml IS NULL OR agua_ml BETWEEN 0 AND 12000)
);

CREATE INDEX IF NOT EXISTS idx_registro_apoyo_paciente_fecha
    ON interaccion.registro_apoyo_diario(id_paciente, fecha_registro DESC);

CREATE TABLE IF NOT EXISTS interaccion.nota_tutor_paciente (
    id BIGSERIAL PRIMARY KEY,
    id_usuario_tutor UUID NOT NULL,
    id_paciente UUID NOT NULL,
    id_plan BIGINT REFERENCES interaccion.plan_nutricional(id),
    id_plan_item BIGINT REFERENCES interaccion.plan_item(id),
    nota TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (id_usuario_tutor, id_paciente)
        REFERENCES usuarios.tutor_paciente(id_usuario_tutor, id_paciente)
        ON DELETE CASCADE,
    CHECK (char_length(BTRIM(nota)) >= 2)
);

CREATE INDEX IF NOT EXISTS idx_nota_tutor_paciente_fecha
    ON interaccion.nota_tutor_paciente(id_paciente, created_at DESC);

-- =====================================================
-- 7) REPOSITORIO DE RECETAS PERMITIDAS POR PACIENTE
-- =====================================================

CREATE TABLE IF NOT EXISTS interaccion.receta_permitida_contexto (
    id BIGSERIAL PRIMARY KEY,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_control_base BIGINT REFERENCES clinico.control_paciente(id),
    id_objetivo_nutricional BIGINT REFERENCES clinico.objetivo_nutricional_paciente(id),
    id_nivel_actividad INTEGER REFERENCES interaccion.catalogo_nivel_actividad(id),
    agua_ml_referencia INTEGER,
    hay_brote_activo BOOLEAN,
    origen VARCHAR(20) NOT NULL DEFAULT 'SISTEMA',
    vigente BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES usuarios.usuario(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (UPPER(origen) IN ('SISTEMA', 'MEDICO', 'NUTRICIONISTA')),
    CHECK (agua_ml_referencia IS NULL OR agua_ml_referencia BETWEEN 0 AND 12000)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_receta_permitida_contexto_vigente
    ON interaccion.receta_permitida_contexto(id_paciente)
    WHERE vigente = TRUE;

CREATE TABLE IF NOT EXISTS interaccion.receta_permitida_item (
    id BIGSERIAL PRIMARY KEY,
    id_contexto BIGINT NOT NULL REFERENCES interaccion.receta_permitida_contexto(id) ON DELETE CASCADE,
    id_receta INTEGER NOT NULL REFERENCES nutricion.receta(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'PERMITIDA',
    puntaje_prioridad NUMERIC(10,4) NOT NULL DEFAULT 0,
    motivo JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_contexto, id_receta),
    CHECK (UPPER(estado) IN ('PERMITIDA', 'DISMINUIDA', 'BLOQUEADA'))
);

CREATE INDEX IF NOT EXISTS idx_receta_permitida_item_contexto
    ON interaccion.receta_permitida_item(id_contexto, estado, puntaje_prioridad DESC);

-- =====================================================
-- 8) PLANES Y RECOMENDACIONES enlazados a objetivo/contexto
-- =====================================================

ALTER TABLE interaccion.plan_nutricional
    ADD COLUMN IF NOT EXISTS id_objetivo_nutricional BIGINT;
ALTER TABLE interaccion.plan_nutricional
    ADD COLUMN IF NOT EXISTS id_contexto_recetas BIGINT;
ALTER TABLE interaccion.plan_nutricional
    ADD COLUMN IF NOT EXISTS nota_plan TEXT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_plan_objetivo_nutricional') THEN
        ALTER TABLE interaccion.plan_nutricional
        ADD CONSTRAINT fk_plan_objetivo_nutricional
        FOREIGN KEY (id_objetivo_nutricional)
        REFERENCES clinico.objetivo_nutricional_paciente(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_plan_contexto_recetas') THEN
        ALTER TABLE interaccion.plan_nutricional
        ADD CONSTRAINT fk_plan_contexto_recetas
        FOREIGN KEY (id_contexto_recetas)
        REFERENCES interaccion.receta_permitida_contexto(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_plan_fechas_validas') THEN
        ALTER TABLE interaccion.plan_nutricional
        ADD CONSTRAINT ck_plan_fechas_validas
        CHECK (fecha_fin >= fecha_inicio) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_plan_comidas_por_dia') THEN
        ALTER TABLE interaccion.plan_nutricional
        ADD CONSTRAINT ck_plan_comidas_por_dia
        CHECK (comidas_por_dia BETWEEN 1 AND 8) NOT VALID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_plan_nutricional_objetivo
    ON interaccion.plan_nutricional(id_objetivo_nutricional);
CREATE INDEX IF NOT EXISTS idx_plan_nutricional_contexto
    ON interaccion.plan_nutricional(id_contexto_recetas);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_plan_item_energia') THEN
        ALTER TABLE interaccion.plan_item
        ADD CONSTRAINT ck_plan_item_energia
        CHECK (energia_objetivo_kcal IS NULL OR energia_objetivo_kcal >= 0) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_plan_item_proteina') THEN
        ALTER TABLE interaccion.plan_item
        ADD CONSTRAINT ck_plan_item_proteina
        CHECK (proteina_objetivo_g IS NULL OR proteina_objetivo_g >= 0) NOT VALID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_plan_item_plan_fecha
    ON interaccion.plan_item(id_plan, fecha_programada);
CREATE INDEX IF NOT EXISTS idx_plan_item_receta
    ON interaccion.plan_item(id_receta);

ALTER TABLE interaccion.recomendacion_puntual
    ADD COLUMN IF NOT EXISTS id_objetivo_nutricional BIGINT;
ALTER TABLE interaccion.recomendacion_puntual
    ADD COLUMN IF NOT EXISTS id_contexto_recetas BIGINT;
ALTER TABLE interaccion.recomendacion_puntual
    ADD COLUMN IF NOT EXISTS id_control_base BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_recomendacion_objetivo') THEN
        ALTER TABLE interaccion.recomendacion_puntual
        ADD CONSTRAINT fk_recomendacion_objetivo
        FOREIGN KEY (id_objetivo_nutricional)
        REFERENCES clinico.objetivo_nutricional_paciente(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_recomendacion_contexto') THEN
        ALTER TABLE interaccion.recomendacion_puntual
        ADD CONSTRAINT fk_recomendacion_contexto
        FOREIGN KEY (id_contexto_recetas)
        REFERENCES interaccion.receta_permitida_contexto(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_recomendacion_control_base') THEN
        ALTER TABLE interaccion.recomendacion_puntual
        ADD CONSTRAINT fk_recomendacion_control_base
        FOREIGN KEY (id_control_base)
        REFERENCES clinico.control_paciente(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_recomendacion_calificacion') THEN
        ALTER TABLE interaccion.recomendacion_puntual
        ADD CONSTRAINT ck_recomendacion_calificacion
        CHECK (calificacion_estrellas IS NULL OR calificacion_estrellas BETWEEN 1 AND 5) NOT VALID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_recomendacion_puntual_paciente_fecha
    ON interaccion.recomendacion_puntual(id_paciente, fecha_solicitud DESC);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_evaluacion_estrellas_rango') THEN
        ALTER TABLE interaccion.evaluacion_receta
        ADD CONSTRAINT ck_evaluacion_estrellas_rango
        CHECK (estrellas BETWEEN 1 AND 5) NOT VALID;
    END IF;
END $$;

-- =====================================================
-- 9) HISTORIAL DE REEMPLAZO REAL POR PLAN_ITEM
-- =====================================================

CREATE TABLE IF NOT EXISTS interaccion.plan_item_reemplazo (
    id BIGSERIAL PRIMARY KEY,
    id_plan_item BIGINT NOT NULL REFERENCES interaccion.plan_item(id) ON DELETE CASCADE,
    id_receta_original INTEGER NOT NULL REFERENCES nutricion.receta(id),
    id_receta_reemplazo INTEGER NOT NULL REFERENCES nutricion.receta(id),
    id_usuario_tutor UUID NOT NULL REFERENCES usuarios.usuario(id),
    id_regla_equivalencia BIGINT REFERENCES nutricion.receta_reemplazo_equivalente(id),
    motivo TEXT,
    vigente BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_reemplazo TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (id_receta_original <> id_receta_reemplazo)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_plan_item_reemplazo_vigente
    ON interaccion.plan_item_reemplazo(id_plan_item)
    WHERE vigente = TRUE;

ALTER TABLE interaccion.seguimiento_plan_item
    ADD COLUMN IF NOT EXISTS id_usuario_registra UUID REFERENCES usuarios.usuario(id);
ALTER TABLE interaccion.seguimiento_plan_item
    ADD COLUMN IF NOT EXISTS id_plan_item_reemplazo BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_seguimiento_plan_item_reemplazo') THEN
        ALTER TABLE interaccion.seguimiento_plan_item
        ADD CONSTRAINT fk_seguimiento_plan_item_reemplazo
        FOREIGN KEY (id_plan_item_reemplazo)
        REFERENCES interaccion.plan_item_reemplazo(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_seguimiento_plan_item
    ON interaccion.seguimiento_plan_item(id_plan_item);

-- =====================================================
-- 10) LISTA DE COMPRAS SIMPLE POR PLAN
-- =====================================================

CREATE TABLE IF NOT EXISTS interaccion.lista_compra (
    id BIGSERIAL PRIMARY KEY,
    id_plan BIGINT NOT NULL REFERENCES interaccion.plan_nutricional(id) ON DELETE CASCADE,
    id_paciente UUID NOT NULL REFERENCES usuarios.paciente(id),
    id_usuario_genera UUID REFERENCES usuarios.usuario(id),
    estado VARCHAR(20) NOT NULL DEFAULT 'ABIERTA',
    costo_total_estimado NUMERIC(10,2),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (id_plan),
    CHECK (UPPER(estado) IN ('ABIERTA', 'CERRADA')),
    CHECK (costo_total_estimado IS NULL OR costo_total_estimado >= 0)
);

CREATE TABLE IF NOT EXISTS interaccion.lista_compra_item (
    id BIGSERIAL PRIMARY KEY,
    id_lista_compra BIGINT NOT NULL REFERENCES interaccion.lista_compra(id) ON DELETE CASCADE,
    id_ingrediente INTEGER NOT NULL REFERENCES nutricion.ingrediente(id),
    cantidad_total_g NUMERIC(12,2) NOT NULL,
    unidad_visual VARCHAR(50),
    comprado BOOLEAN NOT NULL DEFAULT FALSE,
    cantidad_comprada_g NUMERIC(12,2),
    fecha_marcado TIMESTAMP,
    id_usuario_marca UUID REFERENCES usuarios.usuario(id),
    costo_estimado NUMERIC(10,2),
    observacion TEXT,
    UNIQUE (id_lista_compra, id_ingrediente),
    CHECK (cantidad_total_g >= 0),
    CHECK (cantidad_comprada_g IS NULL OR cantidad_comprada_g >= 0),
    CHECK (costo_estimado IS NULL OR costo_estimado >= 0)
);

CREATE INDEX IF NOT EXISTS idx_lista_compra_paciente
    ON interaccion.lista_compra(id_paciente, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lista_compra_item_estado
    ON interaccion.lista_compra_item(id_lista_compra, comprado);
