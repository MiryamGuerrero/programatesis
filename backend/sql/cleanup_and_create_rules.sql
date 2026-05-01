-- =============================================
-- LIMPIEZA Y CREACIÓN DE REGLAS COHERENTES
-- =============================================

-- 1. LIMPIAR REGLAS REDUNDANTES O MAL FORMADAS
-- Eliminar reglas sin objetivo claro (donde todos los IDs son NULL)
DELETE FROM heuristico.regla 
WHERE id_ingrediente IS NULL 
  AND id_grupo_alimentario IS NULL 
  AND id_subgrupo_alimentario IS NULL 
  AND id_etiqueta IS NULL 
  AND id_receta IS NULL;

-- 2. ELIMINAR REGLAS DUPLICADAS
DELETE FROM heuristico.regla r1
WHERE r1.ctid < (
  SELECT MAX(r2.ctid)
  FROM heuristico.regla r2
  WHERE r1.id_accion = r2.id_accion
    AND COALESCE(r1.id_ingrediente, 0) = COALESCE(r2.id_ingrediente, 0)
    AND COALESCE(r1.id_grupo_alimentario, 0) = COALESCE(r2.id_grupo_alimentario, 0)
    AND COALESCE(r1.id_subgrupo_alimentario, 0) = COALESCE(r2.id_subgrupo_alimentario, 0)
    AND COALESCE(r1.id_etiqueta, 0) = COALESCE(r2.id_etiqueta, 0)
    AND COALESCE(r1.id_receta, 0) = COALESCE(r2.id_receta, 0)
    AND r1.id_tipo_objetivo = r2.id_tipo_objetivo
);

-- 3. VERIFICAR Y LIMPIAR ETIQUETAS NUTRICIONALES
-- Eliminar etiquetas sin nombre_visible
DELETE FROM nutricion.etiqueta_nutricional 
WHERE nombre_visible IS NULL OR nombre_visible = '';

-- 4. LIMPIAR RELACIONES DE INGREDIENTE-ETIQUETA HUÉRFANAS
DELETE FROM nutricion.ingrediente_etiqueta ie
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.etiqueta_nutricional e 
  WHERE e.id = ie.id_etiqueta
);

-- 5. LIMPIAR RELACIONES DE RECETA-ETIQUETA HUÉRFANAS
DELETE FROM nutricion.receta_etiqueta re
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.etiqueta_nutricional e 
  WHERE e.id = re.id_etiqueta
);

-- =============================================
-- CREACIÓN DE REGLAS COHERENTES
-- =============================================

-- 6. REGLAS POR ALERGIAS (Fuente: ALERGIA)
-- Estas se generan automáticamente desde el código, pero aseguramos que las etiquetas existan

-- 6.1. Etiquetas para intolerancia a lactosa
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo)
VALUES 
  ('CONTIENE_LACTOSA', 'Contiene Lactosa', 'Ingredientes que contienen lactosa', true),
  ('SIN_LACTOSA', 'Sin Lactosa', 'Ingredientes libres de lactosa', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, 
      descripcion = EXCLUDED.descripcion;

-- 6.2. Asignar etiqueta CONTIENE_LACTOSA a ingredientes lácteos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id 
FROM nutricion.ingrediente i
JOIN nutricion.subgrupo_alimentario s ON i.id_subgrupo_alimentario = s.id
WHERE s.nombre LIKE '%lacteos%' OR s.nombre LIKE '%leche%' OR s.nombre LIKE '%queso%' OR s.nombre LIKE '%mantequilla%'
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'CONTIENE_LACTOSA'
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
  WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- 7. REGLAS CLÍNICAS COHERENTES PARA AIJ
-- 7.1. Si tiene AIJ (Artritis Idiopática Juvenil), eliminar subgrupos inflamatorios
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
  1 as id_accion, -- ELIMINAR
  2 as id_tipo_objetivo, -- SUBGRUPO
  s.id as id_subgrupo_alimentario,
  'CLINICA' as origen_regla,
  'Paciente con AIJ: Se recomienda eliminar alimentos procesados/inflamatorios' as mensaje_error,
  false as es_estricta
FROM heuristico.condicion c
JOIN nutricion.subgrupo_alimentario s ON s.nombre LIKE '%procesados%' OR s.nombre LIKE '%fritos%'
WHERE c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
  AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 2 AND r.id_subgrupo_alimentario = s.id
  )
LIMIT 1;

-- 8. REGLAS NUTRICIONALES SEGÚN Z-SCORE
-- 8.1. Si Z-Score > 2 (sobrepeo/obesidad): DISMINUIR grupo de carbohidratos refinados
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
  2 as id_accion, -- DISMINUIR
  3 as id_tipo_objetivo, -- GRUPO
  g.id as id_grupo_alimentario,
  'NUTRICIONAL' as origen_regla,
  'Paciente con sobrepeo: Priorizar carbohidratos complejos sobre refinados' as mensaje_error,
  false as es_estricta
FROM nutricion.grupo_alimentario g
WHERE g.nombre ILIKE '%carbohidrato%' OR g.nombre ILIKE '%cereales%'
  AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 3 AND r.id_grupo_alimentario = g.id AND r.mensaje_error LIKE '%sobrepeo%'
  );

-- 8.2. Si Z-Score < -2 (desnutrición): AUMENTAR grupo de proteínas
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
  4 as id_accion, -- AUMENTAR
  3 as id_tipo_objetivo, -- GRUPO
  g.id as id_grupo_alimentario,
  'NUTRICIONAL' as origen_regla,
  'Paciente con desnutrición: Aumentar ingesta de proteínas de alto valor biológico' as mensaje_error,
  false as es_estricta
FROM nutricion.grupo_alimentario g
WHERE g.nombre ILIKE '%proteína%' OR g.nombre ILIKE '%carne%' OR g.nombre ILIKE '%huevo%' OR g.nombre ILIKE '%lacteos%'
  AND NOT EXISTS (
    SELECT 1 FROM heuristico.regla r 
    WHERE r.id_tipo_objetivo = 3 AND r.id_grupo_alimentario = g.id AND r.mensaje_error LIKE '%desnutrición%'
  );

-- 9. VINCULAR REGLAS CON CONDICIONES
-- 9.1. Vincular reglas de subgrupos inflamatorios con AIJ
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
WHERE r.mensaje_error LIKE '%AIJ%' 
  AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
  );

-- 9.2. Vincular reglas nutricionales con condiciones de peso
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.id_tipo_condicion = 3  -- Condiciones nutricionales
WHERE r.origen_regla = 'NUTRICIONAL'
  AND NOT EXISTS (
    SELECT 1 FROM heuristico.condicion_regla cr 
    WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
  );

-- 10. VERIFICACIÓN FINAL
-- Mostrar reglas actuales
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
  r.mensaje_error
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
ORDER BY r.id;
