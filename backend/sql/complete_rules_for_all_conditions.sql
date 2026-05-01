-- =============================================
-- ANÁLISIS COMPLETO Y CREACIÓN DE REGLAS
-- PARA TODAS LAS CONDICIONES EXISTENTES
-- =============================================

-- =============================================
-- PASO 1: MOSTRAR TODAS LAS CONDICIONES ACTUALES
-- =============================================

SELECT '=== 1. TODAS LAS CONDICIONES CLÍNICAS ===' as info;

SELECT 
    c.id,
    c.nombre,
    c.indicador_codigo,
    c.descripcion
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'CLINICA' AND c.activa = true
ORDER BY c.id;

SELECT '=== 2. TODAS LAS CONDICIONES TEMPORALES ===' as info;

SELECT 
    c.id,
    c.nombre,
    c.indicador_codigo,
    c.descripcion
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'TEMPORAL' AND c.activa = true
ORDER BY c.id;

SELECT '=== 3. TODAS LAS CONDICIONES NUTRICIONALES (Z-SCORE) ===' as info;

SELECT 
    c.id,
    c.nombre,
    c.indicador_codigo,
    c.z_min,
    c.z_max,
    CASE 
        WHEN c.z_max < -2 THEN 'Desnutrición Severa'
        WHEN c.z_max >= -2 AND c.z_min < -1 THEN 'Desnutrición Leve'
        WHEN c.z_min >= -1 AND c.z_max <= 1 THEN 'Normal'
        WHEN c.z_min > 1 AND c.z_max <= 2 THEN 'Sobrepeso Leve'
        WHEN c.z_min > 2 THEN 'Sobrepeso/Obesidad'
        ELSE 'Rango Mixto'
    END as interpretacion
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'NUTRICIONAL' AND c.activa = true
ORDER BY c.z_min, c.z_max;

-- =============================================
-- PASO 2: CREAR ETIQUETAS SI NO EXISTEN
-- =============================================

INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo) VALUES
  ('ANTIINFLAMATORIO', 'Antiinflamatorio', 'Alimentos que reducen la inflamación', true),
  ('OMEGA3', 'Rico en Omega-3', 'Ácidos grasos antiinflamatorios', true),
  ('FRITOS_PROCESADOS', 'Fritos y Procesados', 'Alimentos pro-inflamatorios', true),
  ('ALTO_FIBRA', 'Alto en fibra', 'Más de 6g fibra por 100g', true),
  ('PROTEINA_ALTO_VALOR', 'Proteína alto valor', 'Proteína completa para crecimiento', true),
  ('ALERGIA_LACTOSA', 'Contiene lactosa', 'Ingredientes con lactosa', true),
  ('ALERGIA_GLUTEN', 'Contiene gluten', 'Ingredientes con gluten', true)
ON CONFLICT (codigo) DO UPDATE 
  SET activo = true;

-- =============================================
-- PASO 3: CREAR REGLAS PARA CADA CONDICIÓN CLÍNICA
-- =============================================

-- 3.1. AIJ (Artritis Idiopática Juvenil)
DO $$
DECLARE
    condicion_id INTEGER;
    accion_eliminar INTEGER := 1;
    accion_priorizar INTEGER := 3;
    objetivo_subgrupo INTEGER := 2;
    objetivo_etiqueta INTEGER := 4;
    subgrupo_fritos INTEGER;
    etiqueta_antiinf INTEGER;
    etiqueta_omega3 INTEGER;
BEGIN
    -- Buscar condición AIJ
    SELECT id INTO condicion_id FROM heuristico.condicion 
    WHERE nombre ILIKE '%AIJ%' OR nombre ILIKE '%artritis idiopática%' LIMIT 1;
    
    IF condicion_id IS NOT NULL THEN
        -- Obtener IDs de objetivos
        SELECT id INTO subgrupo_fritos FROM nutricion.subgrupo_alimentario 
        WHERE nombre ILIKE '%fritos%' OR nombre ILIKE '%procesados%' LIMIT 1;
        
        SELECT id INTO etiqueta_antiinf FROM nutricion.etiqueta_nutricional 
        WHERE codigo = 'ANTIINFLAMATORIO' LIMIT 1;
        
        SELECT id INTO etiqueta_omega3 FROM nutricion.etiqueta_nutricional 
        WHERE codigo = 'OMEGA3' LIMIT 1;
        
        -- Regla 1: ELIMINAR fritos (si existe el subgrupo)
        IF subgrupo_fritos IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_eliminar, objetivo_subgrupo, subgrupo_fritos,
                    'CLINICA',
                    '[ALERTA] Paciente con AIJ: Eliminar alimentos fritos y procesados que aumentan la inflamación articular',
                    false)
            RETURNING id INTO condicion_id;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, condicion_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%AIJ%' AND r.id_subgrupo_alimentario = subgrupo_fritos
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Regla 2: PRIORIZAR antiinflamatorios
        IF etiqueta_antiinf IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_antiinf,
                    'CLINICA',
                    '[ATENCIÓN] Paciente con AIJ: Priorizar alimentos antiinflamatorios (cúrcuma, ajo, vegetales verdes)',
                    false)
            RETURNING id INTO condicion_id;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, condicion_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%antiinflamatorios%' AND r.id_etiqueta = etiqueta_antiinf
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Regla 3: PRIORIZAR Omega-3
        IF etiqueta_omega3 IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_omega3,
                    'CLINICA',
                    '[ATENCIÓN] Paciente con AIJ: Aumentar ingesta de Omega-3 (pescado azul, nueces, chía) para reducir inflamación',
                    false)
            RETURNING id INTO condicion_id;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, condicion_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%Omega-3%' AND r.id_etiqueta = etiqueta_omega3
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
END $$;

-- =============================================
-- PASO 4: CREAR REGLAS PARA CONDICIONES TEMPORALES (ALERGIAS)
-- =============================================

-- 4.1. Alergia a la lactosa → ELIMINAR ingredientes lácteos
DO $$
DECLARE
    condicion_lactosa INTEGER;
    grupo_lacteos INTEGER;
    accion_eliminar INTEGER := 1;
    objetivo_grupo INTEGER := 3;
BEGIN
    -- Buscar condición de alergia a lactosa
    SELECT id INTO condicion_lactosa FROM heuristico.condicion 
    WHERE nombre ILIKE '%lactosa%' OR nombre ILIKE '%lácteos%' LIMIT 1;
    
    -- Buscar grupo lácteos
    SELECT id INTO grupo_lacteos FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%lácteos%' OR nombre ILIKE '%leche%' LIMIT 1;
    
    IF condicion_lactosa IS NOT NULL AND grupo_lacteos IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_eliminar, objetivo_grupo, grupo_lacteos,
                'ALERGIA',
                '[ALERTA] Alergia a la lactosa: Eliminar todos los productos lácteos de la dieta',
                true)  -- Es estricta porque es alergia
        RETURNING id INTO condicion_lactosa;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_lactosa
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%lactosa%' AND r.id_grupo_alimentario = grupo_lacteos
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 4.2. Enfermedad Celíaca / Alergia al gluten → ELIMINAR gluten
DO $$
DECLARE
    condicion_gluten INTEGER;
    etiqueta_gluten INTEGER;
    accion_eliminar INTEGER := 1;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    -- Buscar condición celíaca o alergia gluten
    SELECT id INTO condicion_gluten FROM heuristico.condicion 
    WHERE nombre ILIKE '%celíaca%' OR nombre ILIKE '%gluten%' OR nombre ILIKE '%celiaca%' LIMIT 1;
    
    -- Buscar etiqueta gluten
    SELECT id INTO etiqueta_gluten FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ALERGIA_GLUTEN' LIMIT 1;
    
    IF condicion_gluten IS NOT NULL AND etiqueta_gluten IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_eliminar, objetivo_etiqueta, etiqueta_gluten,
                'ALERGIA',
                '[ALERTA] Enfermedad Celíaca: Eliminar todos los alimentos con gluten (trigo, cebada, centeno)',
                true)
        RETURNING id INTO condicion_gluten;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_gluten
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Celíaca%' AND r.id_etiqueta = etiqueta_gluten
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- =============================================
-- PASO 5: CREAR REGLAS PARA CONDICIONES NUTRICIONALES (Z-SCORE)
-- =============================================

-- 5.1. Desnutrición Severa (Z < -2) → AUMENTAR proteínas
DO $$
DECLARE
    condicion_desnutricion INTEGER;
    grupo_proteinas INTEGER;
    accion_aumentar INTEGER := 4;
    objetivo_grupo INTEGER := 3;
BEGIN
    -- Buscar condición de desnutrición severa
    SELECT id INTO condicion_desnutricion FROM heuristico.condicion 
    WHERE id_tipo_condicion = 3 AND z_max < -2 LIMIT 1;
    
    -- Buscar grupo proteínas
    SELECT id INTO grupo_proteinas FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%proteína%' OR nombre ILIKE '%carne%' OR nombre ILIKE '%huevo%' LIMIT 1;
    
    IF condicion_desnutricion IS NOT NULL AND grupo_proteinas IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_aumentar, objetivo_grupo, grupo_proteinas,
                'NUTRICIONAL',
                '[ALERTA] Desnutrición detectada (Z < -2): Aumentar ingesta de proteínas de alto valor biológico para recuperar peso',
                false)
        RETURNING id INTO condicion_desnutricion;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_desnutricion
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Desnutrición%' AND r.id_grupo_alimentario = grupo_proteinas
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 5.2. Sobrepeso/Obesidad (Z > 2) → DISMINUIR carbohidratos
DO $$
DECLARE
    condicion_sobrepeso INTEGER;
    grupo_carbohidratos INTEGER;
    accion_disminuir INTEGER := 2;
    objetivo_grupo INTEGER := 3;
BEGIN
    -- Buscar condición de sobrepeso
    SELECT id INTO condicion_sobrepeso FROM heuristico.condicion 
    WHERE id_tipo_condicion = 3 AND z_min > 2 LIMIT 1;
    
    -- Buscar grupo carbohidratos
    SELECT id INTO grupo_carbohidratos FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%carbohidrato%' OR nombre ILIKE '%cereal%' LIMIT 1;
    
    IF condicion_sobrepeso IS NOT NULL AND grupo_carbohidratos IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_disminuir, objetivo_grupo, grupo_carbohidratos,
                'NUTRICIONAL',
                '[ALERTA] Sobrepeso detectado (Z > 2): Disminuir carbohidratos refinados, aumentar vegetales y fibra',
                false)
        RETURNING id INTO condicion_sobrepeso;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_sobrepeso
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Sobrepeso%' AND r.id_grupo_alimentario = grupo_carbohidratos
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 5.3. Normalidad (Z -1 a 1) → PRIORIZAR fibra
DO $$
DECLARE
    condicion_normal INTEGER;
    etiqueta_fibra INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    -- Buscar condición de normalidad
    SELECT id INTO condicion_normal FROM heuristico.condicion 
    WHERE id_tipo_condicion = 3 AND z_min >= -1 AND z_max <= 1 LIMIT 1;
    
    -- Buscar etiqueta fibra
    SELECT id INTO etiqueta_fibra FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ALTO_FIBRA' LIMIT 1;
    
    IF condicion_normal IS NOT NULL AND etiqueta_fibra IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_fibra,
                'NUTRICIONAL',
                '[NORMAL] Estado nutricional óptimo: Priorizar alimentos altos en fibra para mantener salud digestiva',
                false)
        RETURNING id INTO condicion_normal;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_normal
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%nutricional óptimo%' AND r.id_etiqueta = etiqueta_fibra
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- =============================================
-- PASO 6: VERIFICACIÓN FINAL
-- =============================================

SELECT '=== VERIFICACIÓN FINAL: TODAS LAS REGLAS ===' as info;

SELECT 
    r.id,
    a.codigo as accion,
    t.codigo as tipo_objetivo,
    CASE 
        WHEN r.id_ingrediente IS NOT NULL THEN 'Ingrediente'
        WHEN r.id_grupo_alimentario IS NOT NULL THEN 'Grupo'
        WHEN r.id_subgrupo_alimentario IS NOT NULL THEN 'Subgrupo'
        WHEN r.id_etiqueta IS NOT NULL THEN 'Etiqueta'
        WHEN r.id_receta IS NOT NULL THEN 'Receta'
        ELSE 'SIN OBJETIVO'
    END as tipo_obj,
    COALESCE(
        (SELECT nombre FROM nutricion.ingrediente WHERE id = r.id_ingrediente),
        (SELECT nombre FROM nutricion.grupo_alimentario WHERE id = r.id_grupo_alimentario),
        (SELECT nombre FROM nutricion.subgrupo_alimentario WHERE id = r.id_subgrupo_alimentario),
        (SELECT nombre_visible FROM nutricion.etiqueta_nutricional WHERE id = r.id_etiqueta),
        'N/A'
    ) as objetivo_nombre,
    r.origen_regla,
    r.mensaje_error,
    c.nombre as condicion
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
ORDER BY r.origen_regla, r.id;
