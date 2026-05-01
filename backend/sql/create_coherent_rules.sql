-- =============================================
-- CREAR REGLAS COHERENTES PARA CONDICIONES EXISTENTES
-- =============================================

-- =============================================
-- PASO 1: VERIFICAR CONDICIONES EXISTENTES
-- =============================================

-- Mostrar condiciones actuales por tipo
SELECT 
    c.id, 
    c.nombre, 
    tc.nombre as tipo,
    c.indicador_codigo,
    c.z_min, c.z_max
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE c.activa = true
ORDER BY c.id_tipo_condicion, c.id;

-- =============================================
-- PASO 2: CREAR ETIQUETAS NECESARIAS SI NO EXISTEN
-- =============================================

-- 2.1. Etiquetas antiinflamatorias para AIJ
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo)
VALUES 
    ('ANTIINFLAMATORIO', 'Antiinflamatorio', 'Alimentos que reducen la inflamación sistémica', true),
    ('OMEGA3', 'Rico en Omega-3', 'Ácidos grasos esenciales antiinflamatorios', true),
    ('CURCUMA', 'Cúrcuma/Turmeric', 'Especia con propiedades antiinflamatorias', true),
    ('FRITOS_PROCESADOS', 'Fritos y Procesados', 'Alimentos que aumentan la inflamación', true)
ON CONFLICT (codigo) DO UPDATE 
SET nombre_visible = EXCLUDED.nombre_visible, 
    descripcion = EXCLUDED.descripcion;

-- 2.2. Etiquetas para control de peso
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo)
VALUES 
    ('ALTO_FIBRA', 'Alto en fibra', 'Ayuda en saciedad y control de peso', true),
    ('BAJO_GLUCEMICO', 'Bajo índice glucémico', 'Evita picos de insulina', true),
    ('PROTEINA_ALTO_VALOR', 'Proteína de alto valor', 'Esencial para crecimiento y recuperación', true)
ON CONFLICT (codigo) DO UPDATE 
SET nombre_visible = EXCLUDED.nombre_visible, 
    descripcion = EXCLUDED.descripcion;

-- =============================================
-- PASO 3: ASIGNAR ETIQUETAS A INGREDIENTES
-- =============================================

-- 3.1. Asignar OMEGA-3 a pescados y frutos secos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'OMEGA3'
WHERE i.nombre ILIKE '%salmón%' OR i.nombre ILIKE '%atún%' OR i.nombre ILIKE '%nuez%' OR i.nombre ILIKE '%chía%'
AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- 3.2. Asignar ANTEINFLAMATORIO a especias
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'ANTIINFLAMATORIO'
WHERE i.nombre ILIKE '%cúrcuma%' OR i.nombre ILIKE '%jengibre%' OR i.nombre ILIKE '%ajo%' OR i.nombre ILIKE '%cebolla%'
AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- 3.3. Asignar FRITOS_PROCESADOS a subgrupos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
JOIN nutricion.subgrupo_alimentario s ON i.id_subgrupo_alimentario = s.id
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'FRITOS_PROCESADOS'
WHERE s.nombre ILIKE '%fritos%' OR s.nombre ILIKE '%procesados%' OR s.nombre ILIKE '%embutidos%'
AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- =============================================
-- PASO 4: CREAR REGLAS PARA AIJ (REUMATOLOGÍA)
-- =============================================

-- 4.1. AIJ → ELIMINAR fritos y procesados (SUBGRUPO)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
    1, -- ELIMINAR
    2, -- SUBGRUPO
    s.id,
    'CLINICA',
    'Paciente con AIJ: Eliminar alimentos fritos y ultraprocesados que aumentan la inflamación',
    false
FROM heuristico.condicion c
JOIN nutricion.subgrupo_alimentario s ON s.nombre ILIKE '%fritos%' OR s.nombre ILIKE '%procesados%'
WHERE c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 2 AND r.id_subgrupo_alimentario = s.id AND r.mensaje_error LIKE '%AIJ%'
)
LIMIT 1;

-- Vincular regla con condición AIJ
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
WHERE r.mensaje_error LIKE '%AIJ%' 
AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- 4.2. AIJ → PRIORIZAR antiinflamatorios (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
SELECT 
    3, -- PRIORIZAR
    4, -- ETIQUETA
    e.id,
    'CLINICA',
    'Paciente con AIJ: Priorizar alimentos antiinflamatorios (Omega-3, cúrcuma)',
    false
FROM heuristico.condicion c
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'ANTIINFLAMATORIO'
WHERE c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 4 AND r.id_etiqueta = e.id AND r.mensaje_error LIKE '%antiinflamatorios%'
)
LIMIT 1;

-- Vincular regla con condición AIJ
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
JOIN heuristico.condicion c ON c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
WHERE e.codigo = 'ANTIINFLAMATORIO'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- 4.3. AIJ → PRIORIZAR Omega-3 (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
SELECT 
    3, -- PRIORIZAR
    4, -- ETIQUETA
    e.id,
    'CLINICA',
    'Paciente con AIJ: Aumentar ingesta de Omega-3 (pescado azul, frutos secos)',
    false
FROM heuristico.condicion c
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'OMEGA3'
WHERE c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 4 AND r.id_etiqueta = e.id AND r.mensaje_error LIKE '%Omega-3%'
)
LIMIT 1;

-- Vincular regla con condición AIJ
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
JOIN heuristico.condicion c ON c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
WHERE e.codigo = 'OMEGA3'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- =============================================
-- PASO 5: CREAR REGLAS NUTRICIONALES (Z-SCORE)
-- =============================================

-- 5.1. Sobrepeso/Obesidad (Z-Score > 2) → DISMINUIR carbohidratos refinados (GRUPO)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
    2, -- DISMINUIR
    3, -- GRUPO
    g.id,
    'NUTRICIONAL',
    'Sobrepeso detectado: Disminuir carbohidratos refinados y aumentar fibra',
    false
FROM heuristico.condicion c
JOIN nutricion.grupo_alimentario g ON g.nombre ILIKE '%carbohidrato%' OR g.nombre ILIKE '%cereales%'
WHERE c.id_tipo_condicion = 3 AND c.z_max > 2
AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 3 AND r.id_grupo_alimentario = g.id AND r.mensaje_error LIKE '%Sobrepeso%'
)
LIMIT 1;

-- Vincular regla con condiciones de sobrepeso
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN nutricion.grupo_alimentario g ON g.id = r.id_grupo_alimentario
JOIN heuristico.condicion c ON c.id_tipo_condicion = 3 AND c.z_max > 2
WHERE g.nombre ILIKE '%carbohidrato%'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- 5.2. Desnutrición (Z-Score < -2) → AUMENTAR proteínas (GRUPO)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
    4, -- AUMENTAR
    3, -- GRUPO
    g.id,
    'NUTRICIONAL',
    'Desnutrición detectada: Aumentar ingesta de proteínas de alto valor biológico',
    false
FROM heuristico.condicion c
JOIN nutricion.grupo_alimentario g ON g.nombre ILIKE '%proteína%' OR g.nombre ILIKE '%carne%' OR g.nombre ILIKE '%huevo%' OR g.nombre ILIKE '%lácteos%'
WHERE c.id_tipo_condicion = 3 AND c.z_min < -2
AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 3 AND r.id_grupo_alimentario = g.id AND r.mensaje_error LIKE '%Desnutrición%'
)
LIMIT 1;

-- Vincular regla con condiciones de desnutrición
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN nutricion.grupo_alimentario g ON g.id = r.id_grupo_alimentario
JOIN heuristico.condicion c ON c.id_tipo_condicion = 3 AND c.z_min < -2
WHERE g.nombre ILIKE '%proteína%'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- 5.3. Normalidad nutricional (Z-Score -1 a +1) → PRIORIZAR fibra (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
SELECT 
    3, -- PRIORIZAR
    4, -- ETIQUETA
    e.id,
    'NUTRICIONAL',
    'Estado nutricional óptimo: Priorizar alimentos altos en fibra',
    false
FROM heuristico.condicion c
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'ALTO_FIBRA'
WHERE c.id_tipo_condicion = 3 AND c.z_min >= -1 AND c.z_max <= 1
AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 4 AND r.id_etiqueta = e.id AND r.mensaje_error LIKE '%fibra%'
)
LIMIT 1;

-- Vincular regla con condiciones normales
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
JOIN heuristico.condicion c ON c.id_tipo_condicion = 3 AND c.z_min >= -1 AND c.z_max <= 1
WHERE e.codigo = 'ALTO_FIBRA'
AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- =============================================
-- PASO 6: CREAR REGLAS PARA ALERGIAS (AUTO-GENERADAS)
-- =============================================

-- 6.1. Alergia a ingredientes específicos → ELIMINAR INGREDIENTE
-- (Esto ya lo hace el código automáticamente, pero aseguramos que las etiquetas existan)
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo)
VALUES 
    ('ALERGIA_LACTOSA', 'Contiene lactosa', 'Ingredientes que contienen lactosa', true),
    ('ALERGIA_GLUTEN', 'Contiene gluten', 'Ingredientes con gluten', true)
ON CONFLICT (codigo) DO UPDATE 
SET nombre_visible = EXCLUDED.nombre_visible, 
    descripcion = EXCLUDED.descripcion;

-- 6.2. Asignar etiqueta ALERGIA_LACTOSA a ingredientes lácteos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
JOIN nutricion.subgrupo_alimentario s ON i.id_subgrupo_alimentario = s.id
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'ALERGIA_LACTOSA'
WHERE s.nombre ILIKE '%lácteos%' OR s.nombre ILIKE '%leche%' OR s.nombre ILIKE '%queso%'
AND NOT EXISTS (
    SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
    WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- =============================================
-- PASO 7: VERIFICACIÓN FINAL
-- =============================================

-- Mostrar TODAS las reglas coherentes con sus objetivos
SELECT 
    r.id,
    a.codigo as accion,
    t.codigo as objetivo_tipo,
    CASE 
        WHEN r.id_ingrediente IS NOT NULL THEN 'Ingrediente: ' || (SELECT nombre FROM nutricion.ingrediente WHERE id = r.id_ingrediente)
        WHEN r.id_grupo_alimentario IS NOT NULL THEN 'Grupo: ' || (SELECT nombre FROM nutricion.grupo_alimentario WHERE id = r.id_grupo_alimentario)
        WHEN r.id_subgrupo_alimentario IS NOT NULL THEN 'Subgrupo: ' || (SELECT nombre FROM nutricion.subgrupo_alimentario WHERE id = r.id_subgrupo_alimentario)
        WHEN r.id_etiqueta IS NOT NULL THEN 'Etiqueta: ' || (SELECT nombre_visible FROM nutricion.etiqueta_nutricional WHERE id = r.id_etiqueta)
        WHEN r.id_receta IS NOT NULL THEN 'Receta: ' || (SELECT nombre FROM nutricion.receta WHERE id = r.id_receta)
    END as objetivo,
    r.origen_regla,
    r.mensaje_error,
    array_agg(DISTINCT c.nombre) as condiciones
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
GROUP BY r.id, a.codigo, t.codigo, r.origen_regla, r.mensaje_error
ORDER BY r.id;
