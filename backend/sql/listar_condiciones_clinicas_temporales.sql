-- =============================================
-- LISTADO COMPLETO DE CONDICIONES CLÍNICAS Y TEMPORALES
-- Ejecutar en SQL Editor de Supabase
-- =============================================

-- =============================================
-- 1. CONDICIONES CLÍNICAS (Reumatología)
-- =============================================

SELECT '=== CONDICIONES CLÍNICAS (REUMATOLOGÍA) ===' as información;

SELECT 
    c.id as ID,
    c.nombre as NOMBRE_CONDICIÓN,
    c.indicador_codigo as CÓDIGO,
    c.descripcion as DESCRIPCIÓN,
    CASE WHEN c.activa THEN 'SÍ' ELSE 'NO' END as ACTIVA
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'CLINICA'
ORDER BY c.id;

-- Contar total
SELECT 
    COUNT(*) as TOTAL_CLÍNICAS
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'CLINICA' AND c.activa = true;

-- =============================================
-- 2. CONDICIONES TEMPORALES (Alergias, Intolerancias)
-- =============================================

SELECT '=== CONDICIONES TEMPORALES (ALERGIAS/INTOLERANCIAS) ===' as información;

SELECT 
    c.id as ID,
    c.nombre as NOMBRE_CONDICIÓN,
    c.indicador_codigo as CÓDIGO,
    c.descripcion as DESCRIPCIÓN,
    CASE WHEN c.activa THEN 'SÍ' ELSE 'NO' END as ACTIVA
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'TEMPORAL'
ORDER BY c.id;

-- Contar total
SELECT 
    COUNT(*) as TOTAL_TEMPORALES
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'TEMPORAL' AND c.activa = true;

-- =============================================
-- 3. CONDICIONES NUTRICIONALES (Z-Score)
-- =============================================

SELECT '=== CONDICIONES NUTRICIONALES (Z-SCORE) ===' as información;

SELECT 
    c.id as ID,
    c.nombre as NOMBRE_CONDICIÓN,
    c.z_min as Z_MÍNIMO,
    c.z_max as Z_MÁXIMO,
    CASE 
        WHEN c.z_max < -2 THEN 'DESNUTRICIÓN SEVERA'
        WHEN c.z_max >= -2 AND c.z_min < -1 THEN 'DESNUTRICIÓN LEVE'
        WHEN c.z_min >= -1 AND c.z_max <= 1 THEN 'NORMAL'
        WHEN c.z_min > 1 AND c.z_max <= 2 THEN 'SOBREPESO LEVE'
        WHEN c.z_min > 2 THEN 'OBESIDAD'
        ELSE 'RANGO MIXTO'
    END as INTERPRETACIÓN
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'NUTRICIONAL'
ORDER BY c.z_min, c.z_max;

-- =============================================
-- 4. RESUMEN GENERAL
-- =============================================

SELECT '=== RESUMEN GENERAL ===' as información;

SELECT 
    tc.nombre as TIPO_CONDICIÓN,
    COUNT(c.id) as TOTAL_ACTIVAS
FROM heuristico.catalogo_tipo_condicion tc
LEFT JOIN heuristico.condicion c ON c.id_tipo_condicion = tc.id AND c.activa = true
GROUP BY tc.id, tc.nombre
ORDER BY tc.id;

-- =============================================
-- 5. VERIFICAR QUÉ CONDICIONES YA TIENEN REGLAS
-- =============================================

SELECT '=== CONDICIONES CON REGLAS ASIGNADAS ===' as información;

SELECT 
    c.id as ID_CONDICIÓN,
    c.nombre as CONDICIÓN,
    tc.codigo as TIPO,
    COUNT(cr.id_regla) as TOTAL_REGLAS
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
LEFT JOIN heuristico.condicion_regla cr ON cr.id_condicion = c.id
WHERE c.activa = true
GROUP BY c.id, c.nombre, tc.codigo
ORDER BY tc.codigo, c.id;

-- =============================================
-- 6. MOSTRAR TODAS LAS REGLAS ACTUALES
-- =============================================

SELECT '=== LISTA DE TODAS LAS REGLAS ACTUALES ===' as información;

SELECT 
    r.id as ID_REGLA,
    a.nombre as ACCIÓN,
    t.nombre as TIPO_OBJETIVO,
    CASE 
        WHEN r.id_ingrediente IS NOT NULL THEN (SELECT nombre FROM nutricion.ingrediente WHERE id = r.id_ingrediente)
        WHEN r.id_grupo_alimentario IS NOT NULL THEN (SELECT nombre FROM nutricion.grupo_alimentario WHERE id = r.id_grupo_alimentario)
        WHEN r.id_subgrupo_alimentario IS NOT NULL THEN (SELECT nombre FROM nutricion.subgrupo_alimentario WHERE id = r.id_subgrupo_alimentario)
        WHEN r.id_etiqueta IS NOT NULL THEN (SELECT nombre_visible FROM nutricion.etiqueta_nutricional WHERE id = r.id_etiqueta)
        WHEN r.id_receta IS NOT NULL THEN (SELECT nombre FROM nutricion.receta WHERE id = r.id_receta)
        ELSE 'SIN OBJETIVO'
    END as OBJETIVO,
    r.origen_regla as ORIGEN,
    r.mensaje_error as MENSAJE
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
ORDER BY r.id;
