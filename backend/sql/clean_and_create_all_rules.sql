-- =============================================
-- REUMA-NUTRI: LIMPIEZA Y CREACIÓN DE REGLAS COHERENTES
-- Ejecutar este script en el SQL Editor de Supabase
-- =============================================

-- =============================================
-- PASO 1: VERIFICAR ESTADO INICIAL
-- =============================================

SELECT '=== ESTADO INICIAL ===' as info;
SELECT 'Reglas totales:', COUNT(*) FROM heuristico.regla;
SELECT 'Reglas sin objetivo:', COUNT(*) FROM heuristico.regla 
WHERE id_ingrediente IS NULL AND id_grupo_alimentario IS NULL 
  AND id_subgrupo_alimentario IS NULL AND id_etiqueta IS NULL AND id_receta IS NULL;
SELECT 'Condiciones activas:', COUNT(*) FROM heuristico.condicion WHERE activa = true;

-- =============================================
-- PASO 2: LIMPIEZA DE DATOS
-- =============================================

-- 2.1. Eliminar reglas sin objetivo (todos los IDs son NULL)
DELETE FROM heuristico.regla 
WHERE id_ingrediente IS NULL 
  AND id_grupo_alimentario IS NULL 
  AND id_subgrupo_alimentario IS NULL 
  AND id_etiqueta IS NULL 
  AND id_receta IS NULL;

-- 2.2. Eliminar reglas duplicadas (mantener la más reciente por ID mayor)
DELETE FROM heuristico.regla r1
WHERE r1.id < (
  SELECT MAX(r2.id)
  FROM heuristico.regla r2
  WHERE COALESCE(r1.id_accion, 0) = COALESCE(r2.id_accion, 0)
    AND COALESCE(r1.id_tipo_objetivo, 0) = COALESCE(r2.id_tipo_objetivo, 0)
    AND COALESCE(r1.id_ingrediente, 0) = COALESCE(r2.id_ingrediente, 0)
    AND COALESCE(r1.id_grupo_alimentario, 0) = COALESCE(r2.id_grupo_alimentario, 0)
    AND COALESCE(r1.id_subgrupo_alimentario, 0) = COALESCE(r2.id_subgrupo_alimentario, 0)
    AND COALESCE(r1.id_etiqueta, 0) = COALESCE(r2.id_etiqueta, 0)
    AND COALESCE(r1.id_receta, 0) = COALESCE(r2.id_receta, 0)
);

-- 2.3. Limpiar relaciones huérfanas en condicion_regla
DELETE FROM heuristico.condicion_regla cr
WHERE NOT EXISTS (
  SELECT 1 FROM heuristico.regla r WHERE r.id = cr.id_regla
);

-- 2.4. Limpiar etiquetas huérfanas
DELETE FROM nutricion.ingrediente_etiqueta ie
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.etiqueta_nutricional e WHERE e.id = ie.id_etiqueta
);

DELETE FROM nutricion.receta_etiqueta re
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.etiqueta_nutricional e WHERE e.id = re.id_etiqueta
);

SELECT '=== LIMPIEZA COMPLETADA ===' as info;
SELECT 'Reglas después de limpieza:', COUNT(*) FROM heuristico.regla;

-- =============================================
-- PASO 3: CREAR ETIQUETAS NECESARIAS
-- =============================================

-- Etiquetas para AIJ (Antiinflamatorias)
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo) VALUES
  ('ANTIINFLAMATORIO', 'Antiinflamatorio', 'Alimentos que reducen la inflamación sistémica', true),
  ('OMEGA3', 'Rico en Omega-3', 'Ácidos grasos esenciales antiinflamatorios EPA y DHA', true),
  ('CURCUMA', 'Cúrcuma/Turmeric', 'Especia con curcumina, potente antiinflamatorio', true),
  ('FRITOS_PROCESADOS', 'Fritos y Procesados', 'Alimentos que aumentan la inflamación', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, 
      descripcion = EXCLUDED.descripcion,
      activo = EXCLUDED.activo;

-- Etiquetas para control nutricional
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo) VALUES
  ('ALTO_FIBRA', 'Alto en fibra', 'Ayuda en saciedad y control de peso', true),
  ('BAJO_GLUCEMICO', 'Bajo índice glucémico', 'Evita picos de insulina y acumulación de grasa', true),
  ('PROTEINA_ALTO_VALOR', 'Proteína de alto valor', 'Esencial para crecimiento y recuperación', true),
  ('ALTO_PROTEINA', 'Alto en proteína', 'Más de 10g de proteína por 100g', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, 
      descripcion = EXCLUDED.descripcion,
      activo = EXCLUDED.activo;

-- Etiquetas para alergias
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo) VALUES
  ('ALERGIA_LACTOSA', 'Contiene lactosa', 'Ingredientes que contienen lactosa', true),
  ('SIN_LACTOSA', 'Sin lactosa', 'Ingredientes libres de lactosa', true),
  ('ALERGIA_GLUTEN', 'Contiene gluten', 'Ingredientes con gluten (trigo, cebada, centeno)', true),
  ('SIN_GLUTEN', 'Sin gluten', 'Ingredientes libres de gluten', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, 
      descripcion = EXCLUDED.descripcion,
      activo = EXCLUDED.activo;

SELECT '=== ETIQUETAS CREADAS ===' as info;
SELECT * FROM nutricion.etiqueta_nutricional WHERE activo = true ORDER BY codigo;

-- =============================================
-- PASO 4: ASIGNAR ETIQUETAS A INGREDIENTES
-- =============================================

-- 4.1. OMEGA-3 → Pescados azules y frutos secos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE e.codigo = 'OMEGA3'
  AND (i.nombre ILIKE '%salmón%' OR i.nombre ILIKE '%salmon%' OR i.nombre ILIKE '%atún%' 
       OR i.nombre ILIKE '%trucha%' OR i.nombre ILIKE '%sardina%' OR i.nombre ILIKE '%nuez%' 
       OR i.nombre ILIKE '%chía%' OR i.nombre ILIKE '%linaza%')
  AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- 4.2. ANTIINFLAMATORIO → Especias y vegetales
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE e.codigo = 'ANTIINFLAMATORIO'
  AND (i.nombre ILIKE '%cúrcuma%' OR i.nombre ILIKE '%curcuma%' OR i.nombre ILIKE '%jengibre%' 
       OR i.nombre ILIKE '%ajo%' OR i.nombre ILIKE '%cebolla%' OR i.nombre ILIKE '%brócoli%'
       OR i.nombre ILIKE '%espinaca%' OR i.nombre ILIKE '%baya%' OR i.nombre ILIKE '%arándano%')
  AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- 4.3. ALERGIA_LACTOSA → Ingredientes lácteos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
JOIN nutricion.subgrupo_alimentario s ON i.id_subgrupo_alimentario = s.id
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE e.codigo = 'ALERGIA_LACTOSA'
  AND (s.nombre ILIKE '%lácteos%' OR s.nombre ILIKE '%leche%' OR s.nombre ILIKE '%queso%' 
       OR s.nombre ILIKE '%mantequilla%' OR s.nombre ILIKE '%yogur%')
  AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

SELECT '=== ETIQUETAS ASIGNADAS ===' as info;
SELECT e.codigo, COUNT(ie.id_ingrediente) as total_ingredientes
FROM nutricion.etiqueta_nutricional e
LEFT JOIN nutricion.ingrediente_etiqueta ie ON ie.id_etiqueta = e.id
WHERE e.activo = true
GROUP BY e.codigo ORDER BY e.codigo;

-- =============================================
-- PASO 5: CREAR REGLAS PARA CONDICIONES REUMATOLÓGICAS (AIJ)
-- =============================================

-- 5.1. AIJ → ELIMINAR fritos y procesados (SUBGRUPO)
DO $$
DECLARE
    condicion_aIJ INTEGER;
    subgrupo_fritos INTEGER;
    accion_eliminar INTEGER := 1;
    objetivo_subgrupo INTEGER := 2;
    regla_id INTEGER;
BEGIN
    -- Buscar condición AIJ
    SELECT id INTO condicion_aIJ FROM heuristico.condicion 
    WHERE nombre ILIKE '%AIJ%' OR nombre ILIKE '%artritis idiopática%' LIMIT 1;
    
    -- Buscar subgrupo "Fritos y Procesados"
    SELECT id INTO subgrupo_fritos FROM nutricion.subgrupo_alimentario 
    WHERE nombre ILIKE '%fritos%' OR nombre ILIKE '%procesados%' LIMIT 1;
    
    IF condicion_aIJ IS NOT NULL AND subgrupo_fritos IS NOT NULL THEN
        -- Crear regla
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_eliminar, objetivo_subgrupo, subgrupo_fritos,
                'CLINICA',
                '[ALERTA] Paciente con AIJ: Eliminar alimentos fritos y ultraprocesados que aumentan la inflamación',
                false)
        RETURNING id INTO regla_id;
        
        -- Vincular con condición
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        VALUES (regla_id, condicion_aIJ)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 5.2. AIJ → PRIORIZAR antiinflamatorios (ETIQUETA)
DO $$
DECLARE
    condicion_aIJ INTEGER;
    etiqueta_antiinf INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
    regla_id INTEGER;
BEGIN
    SELECT id INTO condicion_aIJ FROM heuristico.condicion 
    WHERE nombre ILIKE '%AIJ%' OR nombre ILIKE '%artritis%' LIMIT 1;
    
    SELECT id INTO etiqueta_antiinf FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ANTIINFLAMATORIO' LIMIT 1;
    
    IF condicion_aIJ IS NOT NULL AND etiqueta_antiinf IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_antiinf,
                'CLINICA',
                '[ATENCIÓN] Paciente con AIJ: Priorizar alimentos antiinflamatorios (Omega-3, cúrcuma, vegetales verdes)',
                false)
        RETURNING id INTO regla_id;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        VALUES (regla_id, condicion_aIJ)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 5.3. AIJ → PRIORIZAR Omega-3 (ETIQUETA)
DO $$
DECLARE
    condicion_aIJ INTEGER;
    etiqueta_omega3 INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
    regla_id INTEGER;
BEGIN
    SELECT id INTO condicion_aIJ FROM heuristico.condicion 
    WHERE nombre ILIKE '%AIJ%' OR nombre ILIKE '%artritis%' LIMIT 1;
    
    SELECT id INTO etiqueta_omega3 FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'OMEGA3' LIMIT 1;
    
    IF condicion_aIJ IS NOT NULL AND etiqueta_omega3 IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_omega3,
                'CLINICA',
                '[ATENCIÓN] Paciente con AIJ: Aumentar ingesta de Omega-3 (pescado azul, frutos secos, chía)',
                false)
        RETURNING id INTO regla_id;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        VALUES (regla_id, condicion_aIJ)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

SELECT '=== REGLAS AIJ CREADAS ===' as info;

-- =============================================
-- PASO 6: CREAR REGLAS NUTRICIONALES (Z-SCORE)
-- =============================================

-- 6.1. Sobrepeso (Z > 2) → DISMINUIR carbohidratos (GRUPO)
DO $$
DECLARE
    condicion_sobrepeso INTEGER;
    grupo_carbohidratos INTEGER;
    accion_disminuir INTEGER := 2;
    objetivo_grupo INTEGER := 3;
    regla_id INTEGER;
BEGIN
    -- Buscar condición de sobrepeso (Z-Score > 2)
    SELECT id INTO condicion_sobrepeso FROM heuristico.condicion 
    WHERE id_tipo_condicion = 3 AND z_max > 2 LIMIT 1;
    
    -- Buscar grupo carbohidratos
    SELECT id INTO grupo_carbohidratos FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%carbohidrato%' OR nombre ILIKE '%cereal%' LIMIT 1;
    
    IF condicion_sobrepeso IS NOT NULL AND grupo_carbohidratos IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_disminuir, objetivo_grupo, grupo_carbohidratos,
                'NUTRICIONAL',
                '[ALERTA] Sobrepeso detectado (Z-Score > 2): Disminuir carbohidratos refinados, priorizar fibra',
                false)
        RETURNING id INTO regla_id;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        VALUES (regla_id, condicion_sobrepeso)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 6.2. Desnutrición (Z < -2) → AUMENTAR proteínas (GRUPO)
DO $$
DECLARE
    condicion_desnutricion INTEGER;
    grupo_proteinas INTEGER;
    accion_aumentar INTEGER := 4;
    objetivo_grupo INTEGER := 3;
    regla_id INTEGER;
BEGIN
    -- Buscar condición de desnutrición (Z-Score < -2)
    SELECT id INTO condicion_desnutricion FROM heuristico.condicion 
    WHERE id_tipo_condicion = 3 AND z_min < -2 LIMIT 1;
    
    -- Buscar grupo proteínas
    SELECT id INTO grupo_proteinas FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%proteína%' OR nombre ILIKE '%carne%' OR nombre ILIKE '%huevo%' LIMIT 1;
    
    IF condicion_desnutricion IS NOT NULL AND grupo_proteinas IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_aumentar, objetivo_grupo, grupo_proteinas,
                'NUTRICIONAL',
                '[ALERTA] Desnutrición detectada (Z-Score < -2): Aumentar ingesta de proteínas de alto valor biológico',
                false)
        RETURNING id INTO regla_id;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        VALUES (regla_id, condicion_desnutricion)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 6.3. Normalidad nutricional (Z entre -1 y 1) → PRIORIZAR fibra (ETIQUETA)
DO $$
DECLARE
    condicion_normal INTEGER;
    etiqueta_fibra INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
    regla_id INTEGER;
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
        RETURNING id INTO regla_id;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        VALUES (regla_id, condicion_normal)
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

SELECT '=== REGLAS NUTRICIONALES CREADAS ===' as info;

-- =============================================
-- PASO 7: VERIFICACIÓN FINAL
-- =============================================

SELECT '=== VERIFICACIÓN FINAL ===' as info;

-- Mostrar TODAS las reglas con sus objetivos y condiciones
SELECT 
    r.id,
    a.codigo as accion,
    t.codigo as tipo_objetivo,
    CASE 
        WHEN r.id_ingrediente IS NOT NULL THEN 'Ingrediente: ' || (SELECT nombre FROM nutricion.ingrediente WHERE id = r.id_ingrediente)
        WHEN r.id_grupo_alimentario IS NOT NULL THEN 'Grupo: ' || (SELECT nombre FROM nutricion.grupo_alimentario WHERE id = r.id_grupo_alimentario)
        WHEN r.id_subgrupo_alimentario IS NOT NULL THEN 'Subgrupo: ' || (SELECT nombre FROM nutricion.subgrupo_alimentario WHERE id = r.id_subgrupo_alimentario)
        WHEN r.id_etiqueta IS NOT NULL THEN 'Etiqueta: ' || (SELECT nombre_visible FROM nutricion.etiqueta_nutricional WHERE id = r.id_etiqueta)
        WHEN r.id_receta IS NOT NULL THEN 'Receta: ' || (SELECT nombre FROM nutricion.receta WHERE id = r.id_receta)
        ELSE 'SIN OBJETIVO'
    END as objetivo,
    r.origen_regla,
    r.mensaje_error,
    array_agg(DISTINCT c.nombre ORDER BY c.nombre) as condiciones
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
GROUP BY r.id, a.codigo, t.codigo, r.origen_regla, r.mensaje_error
ORDER BY r.id;

-- Resumen final
SELECT '=== RESUMEN ===' as info;
SELECT 'Total reglas:' as concepto, COUNT(*) as valor FROM heuristico.regla
UNION ALL
SELECT 'Reglas clínicas (AIJ):', COUNT(*) FROM heuristico.regla WHERE origen_regla = 'CLINICA'
UNION ALL
SELECT 'Reglas nutricionales (Z-Score):', COUNT(*) FROM heuristico.regla WHERE origen_regla = 'NUTRICIONAL'
UNION ALL
SELECT 'Reglas con condición:', COUNT(DISTINCT cr.id_regla) FROM heuristico.condicion_regla cr;
