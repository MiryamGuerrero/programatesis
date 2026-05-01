-- =============================================
-- LIMPIEZA Y CREACIÓN DE REGLAS COHERENTES
-- =============================================

-- =============================================
-- PASO 1: LIMPIEZA DE REGLAS Y RELACIONES
-- =============================================

-- 1.1. Eliminar reglas sin objetivo (todos los IDs son NULL)
DELETE FROM heuristico.regla 
WHERE id_ingrediente IS NULL 
  AND id_grupo_alimentario IS NULL 
  AND id_subgrupo_alimentario IS NULL 
  AND id_etiqueta IS NULL 
  AND id_receta IS NULL;

-- 1.2. Eliminar reglas duplicadas (mantener la más reciente)
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

-- 1.3. Limpiar relaciones huérfanas en condicion_regla
DELETE FROM heuristico.condicion_regla cr
WHERE NOT EXISTS (
  SELECT 1 FROM heuristico.regla r WHERE r.id = cr.id_regla
);

-- 1.4. Limpiar etiquetas huérfanas en ingrediente_etiqueta
DELETE FROM nutricion.ingrediente_etiqueta ie
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.etiqueta_nutricional e WHERE e.id = ie.id_etiqueta
);

-- 1.5. Limpiar etiquetas huérfanas en receta_etiqueta
DELETE FROM nutricion.receta_etiqueta re
WHERE NOT EXISTS (
  SELECT 1 FROM nutricion.etiqueta_nutricional e WHERE e.id = re.id_etiqueta
);

-- =============================================
-- PASO 2: CREAR ETIQUETAS NUTRICIONALES FALTANTES
-- =============================================

-- 2.1. Etiquetas básicas para intolerancia a lactosa
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo)
VALUES 
  ('CONTIENE_LACTOSA', 'Contiene Lactosa', 'Ingredientes que contienen lactosa', true),
  ('SIN_LACTOSA', 'Sin Lactosa', 'Ingredientes libres de lactosa', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, descripcion = EXCLUDED.descripcion;

-- 2.2. Etiquetas antiinflamatorias
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo)
VALUES 
  ('ANTIINFLAMATORIO', 'Antiinflamatorio', 'Alimentos que reducen la inflamación', true),
  ('ALTO_OMEGA3', 'Alto en Omega-3', 'Rico en ácidos grasos Omega-3', true),
  ('BAJO_EN_GRASAS', 'Bajo en grasas', 'Contenido reducido de grasas', true),
  ('ALTO_EN_GRASAS', 'Alto en grasas', 'Contenido elevado de grasas', true),
  ('ALTO_EN_FIBRA', 'Alto en fibra', 'Rico en fibra dietética', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, descripcion = EXCLUDED.descripcion;

-- 2.3. Asignar etiqueta CONTIENE_LACTOSA a ingredientes lácteos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id 
FROM nutricion.ingrediente i
JOIN nutricion.subgrupo_alimentario s ON i.id_subgrupo_alimentario = s.id
JOIN nutricion.etiqueta_nutricional e ON e.codigo = 'CONTIENE_LACTOSA'
WHERE s.nombre LIKE '%lacteos%' OR s.nombre LIKE '%leche%' OR s.nombre LIKE '%queso%' OR s.nombre LIKE '%mantequilla%'
AND NOT EXISTS (
  SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
  WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = e.id
);

-- =============================================
-- PASO 3: CREAR REGLAS COHERENTES PARA CONDICIONES EXISTENTES
-- =============================================

-- 3.1. Reglas para AIJ (Artritis Idiopática Juvenil) - ELIMINAR alimentos procesados
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
  1, -- ELIMINAR
  2, -- SUBGRUPO
  s.id,
  'CLINICA',
  'Paciente con AIJ: Eliminar alimentos procesados y fritos que aumentan la inflamación',
  false
FROM nutricion.subgrupo_alimentario s
WHERE s.nombre LIKE '%procesados%' OR s.nombre LIKE '%fritos%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.regla r 
  WHERE r.id_tipo_objetivo = 2 AND r.id_subgrupo_alimentario = s.id
);

-- Vincular regla con condición AIJ
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
WHERE r.mensaje_error LIKE '%AIJ%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.condicion_regla cr 
  WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
)
LIMIT 1;

-- 3.2. Regla para AIJ - PRIORIZAR antiinflamatorios
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
SELECT 
  3, -- PRIORIZAR
  4, -- ETIQUETA
  e.id,
  'CLINICA',
  'Paciente con AIJ: Priorizar alimentos antiinflamatorios (Omega-3, cúrcuma)',
  false
FROM nutricion.etiqueta_nutricional e
WHERE e.codigo = 'ANTIINFLAMATORIO'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.regla r 
  WHERE r.id_tipo_objetivo = 4 AND r.id_etiqueta = e.id
);

-- Vincular con AIJ
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.nombre ILIKE '%AIJ%' OR c.nombre ILIKE '%artritis%'
WHERE r.mensaje_error LIKE '%antiinflamatorios%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.condicion_regla cr 
  WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
)
LIMIT 1;

-- 3.3. Reglas nutricionales - Sobrepeso (Z-Score > 2): DISMINUIR carbohidratos refinados
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
  2, -- DISMINUIR
  3, -- GRUPO
  g.id,
  'NUTRICIONAL',
  'Sobrepeso detectado (Z-Score > 2): Disminuir carbohidratos refinados, priorizar fibra',
  false
FROM nutricion.grupo_alimentario g
WHERE g.nombre ILIKE '%carbohidrato%' OR g.nombre ILIKE '%cereales%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.regla r 
  WHERE r.id_tipo_objetivo = 3 AND r.id_grupo_alimentario = g.id AND r.mensaje_error LIKE '%Sobrepeso%'
);

-- Vincular con condiciones nutricionales de sobrepeso
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.id_tipo_condicion = 3 AND c.z_max > 2
WHERE r.mensaje_error LIKE '%Sobrepeso%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.condicion_regla cr 
  WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- 3.4. Reglas nutricionales - Desnutrición (Z-Score < -2): AUMENTAR proteínas
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
SELECT 
  4, -- AUMENTAR
  3, -- GRUPO
  g.id,
  'NUTRICIONAL',
  'Desnutrición detectada (Z-Score < -2): Aumentar ingesta de proteínas de alto valor biológico',
  false
FROM nutricion.grupo_alimentario g
WHERE g.nombre ILIKE '%proteína%' OR g.nombre ILIKE '%carne%' OR g.nombre ILIKE '%huevo%' OR g.nombre ILIKE '%lacteos%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.regla r 
  WHERE r.id_tipo_objetivo = 3 AND r.id_grupo_alimentario = g.id AND r.mensaje_error LIKE '%Desnutrición%'
);

-- Vincular con condiciones nutricionales de desnutrición
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT r.id, c.id
FROM heuristico.regla r
JOIN heuristico.condicion c ON c.id_tipo_condicion = 3 AND c.z_min < -2
WHERE r.mensaje_error LIKE '%Desnutrición%'
AND NOT EXISTS (
  SELECT 1 FROM heuristico.condicion_regla cr 
  WHERE cr.id_regla = r.id AND cr.id_condicion = c.id
);

-- =============================================
-- PASO 4: VERIFICACIÓN FINAL
-- =============================================

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
