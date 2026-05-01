-- =============================================
-- ANÁLISIS COMPLETO DE TODAS LAS CONDICIONES
-- Ejecutar en SQL Editor de Supabase
-- =============================================

-- =============================================
-- 1. CONDICIONES CLÍNICAS (Tipo 1)
-- =============================================

SELECT '=== CONDICIONES CLÍNICAS (Tipo 1) ===' as info;

SELECT 
    c.id,
    c.nombre,
    c.indicador_codigo,
    c.descripcion,
    c.activa
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'CLINICA' AND c.activa = true
ORDER BY c.id;

-- =============================================
-- 2. CONDICIONES TEMPORALES (Tipo 2)
-- =============================================

SELECT '=== CONDICIONES TEMPORALES (Tipo 2) ===' as info;

SELECT 
    c.id,
    c.nombre,
    c.indicador_codigo,
    c.descripcion,
    c.activa
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'TEMPORAL' AND c.activa = true
ORDER BY c.id;

-- =============================================
-- 3. CONDICIONES NUTRICIONALES (Tipo 3)
-- =============================================

SELECT '=== CONDICIONES NUTRICIONALES (Tipo 3) ===' as info;

SELECT 
    c.id,
    c.nombre,
    c.indicador_codigo,
    c.z_min,
    c.z_max,
    c.descripcion,
    c.activa
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
WHERE tc.codigo = 'NUTRICIONAL' AND c.activa = true
ORDER BY c.z_min, c.z_max;

-- =============================================
-- 4. RESUMEN POR TIPO
-- =============================================

SELECT '=== RESUMEN POR TIPO ===' as info;

SELECT 
    tc.codigo as tipo,
    tc.nombre as descripcion,
    COUNT(c.id) as total_activas
FROM heuristico.catalogo_tipo_condicion tc
LEFT JOIN heuristico.condicion c ON c.id_tipo_condicion = tc.id AND c.activa = true
GROUP BY tc.id, tc.codigo, tc.nombre
ORDER BY tc.id;

-- =============================================
-- 5. VERIFICAR REGLAS ACTUALES POR CONDICIÓN
-- =============================================

SELECT '=== REGLAS ACTUALES POR CONDICIÓN ===' as info;

SELECT 
    c.id as condicion_id,
    c.nombre as condicion,
    tc.codigo as tipo,
    COUNT(cr.id_regla) as total_reglas
FROM heuristico.condicion c
JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
LEFT JOIN heuristico.condicion_regla cr ON cr.id_condicion = c.id
WHERE c.activa = true
GROUP BY c.id, c.nombre, tc.codigo
ORDER BY tc.codigo, c.id;

-- =============================================
-- 6. MOSTRAR TODAS LAS REGLAS ACTUALES
-- =============================================

SELECT '=== TODAS LAS REGLAS ACTUALES ===' as info;

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
        ELSE 'SIN OBJETIVO'
    END as objetivo,
    r.origen_regla,
    r.mensaje_error,
    string_agg(DISTINCT c.nombre, ', ') as condiciones
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
GROUP BY r.id, a.codigo, t.codigo, r.origen_regla, r.mensaje_error
ORDER BY r.id;
