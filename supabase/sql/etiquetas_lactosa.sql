-- =============================================================================
-- ETIQUETAS DE LACTOSA
-- Permite diferenciar ingredientes con/sin lactosa dentro del mismo subgrupo
-- y crear reglas de bloqueo por etiqueta
-- =============================================================================

-- 1. Crear etiquetas de lactosa
INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible)
VALUES
  ('CONTIENE_LACTOSA', 'Contiene lactosa'),
  ('SIN_LACTOSA', 'Sin lactosa');

-- 2. Asignar CONTIENE_LACTOSA a TODOS los lácteos animales
-- Leches animales con lactosa
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (206, 207, 208, 209, 210, 211, 212, 213, 215, 216, 217, 219)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Natas
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (221)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Quesos frescos (con lactosa)
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (225, 230, 231, 233, 234, 235, 238)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Quesos procesados
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (223, 224, 229)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Yogures animales con lactosa
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 256)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Leches fermentadas (kéfir)
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (239)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Mantequillas
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (423, 424, 425)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Salsas con lácteos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (475, 484, 487, 488, 489, 491)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Dulces con lácteos
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (510)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- Chocolates con leche
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (503, 504, 505, 508)
  AND e.codigo = 'CONTIENE_LACTOSA';

-- 3. Asignar SIN_LACTOSA a lácteos sin lactosa
-- Leches sin lactosa
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (214, 218, 220)
  AND e.codigo = 'SIN_LACTOSA';

-- Yogur sin lactosa
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (255)
  AND e.codigo = 'SIN_LACTOSA';

-- Yogur de soja (vegetal, sin lactosa por naturaleza)
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (240)
  AND e.codigo = 'SIN_LACTOSA';

-- Bebidas vegetales (sin lactosa por naturaleza)
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (551, 552, 553, 554, 555, 556, 557)
  AND e.codigo = 'SIN_LACTOSA';

-- Bebida de soja
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (48)
  AND e.codigo = 'SIN_LACTOSA';

-- Batido fermentado de soja
INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
SELECT i.id, e.id
FROM nutricion.ingrediente i
CROSS JOIN nutricion.etiqueta_nutricional e
WHERE i.id IN (47)
  AND e.codigo = 'SIN_LACTOSA';

-- 4. VERIFICACIÓN: Ver ingredientes con CONTIENE_LACTOSA
-- SELECT i.nombre, s.nombre as subgrupo
-- FROM nutricion.ingrediente i
-- JOIN nutricion.ingrediente_etiqueta ie ON ie.id_ingrediente = i.id
-- JOIN nutricion.etiqueta_nutricional e ON e.id = ie.id_etiqueta
-- JOIN nutricion.subgrupo_alimentario s ON s.id = i.id_subgrupo_alimentario
-- WHERE e.codigo = 'CONTIENE_LACTOSA'
-- ORDER BY s.nombre, i.nombre;

-- 5. VERIFICACIÓN: Ver ingredientes con SIN_LACTOSA
-- SELECT i.nombre, s.nombre as subgrupo
-- FROM nutricion.ingrediente i
-- JOIN nutricion.ingrediente_etiqueta ie ON ie.id_ingrediente = i.id
-- JOIN nutricion.etiqueta_nutricional e ON e.id = ie.id_etiqueta
-- JOIN nutricion.subgrupo_alimentario s ON s.id = i.id_subgrupo_alimentario
-- WHERE e.codigo = 'SIN_LACTOSA'
-- ORDER BY s.nombre, i.nombre;
