BEGIN;

-- 1) Asegurar condiciones clinicas base.
INSERT INTO heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa, indicador_codigo)
SELECT 'General Reumaticos', 'Reglas base obligatorias para pacientes reumaticos', 1, true, 'GENERAL_REUMATICOS'
WHERE NOT EXISTS (
  SELECT 1 FROM heuristico.condicion WHERE upper(coalesce(indicador_codigo, '')) = 'GENERAL_REUMATICOS'
);

INSERT INTO heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa, indicador_codigo)
SELECT 'Lupus Eritematoso Sistemico', 'Condicion clinica LES', 1, true, 'LUPUS_ERITEMATOSO_SISTEMICO'
WHERE NOT EXISTS (
  SELECT 1 FROM heuristico.condicion WHERE upper(coalesce(indicador_codigo, '')) = 'LUPUS_ERITEMATOSO_SISTEMICO'
);

INSERT INTO heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa, indicador_codigo)
SELECT 'Artritis Idiopatica Juvenil', 'Condicion clinica AIJ', 1, true, 'ARTRITIS_IDIOPATICA_JUVENIL'
WHERE NOT EXISTS (
  SELECT 1 FROM heuristico.condicion WHERE upper(coalesce(indicador_codigo, '')) = 'ARTRITIS_IDIOPATICA_JUVENIL'
);

-- 2) Limpiar solo reglas clinicas vinculadas a condiciones clinicas.
WITH reglas_clinicas AS (
  SELECT DISTINCT r.id
  FROM heuristico.regla r
  JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
  JOIN heuristico.condicion c ON c.id = cr.id_condicion
  WHERE upper(coalesce(r.origen_regla, 'CLINICA')) = 'CLINICA'
    AND c.id_tipo_condicion = 1
)
DELETE FROM heuristico.condicion_regla
WHERE id_regla IN (SELECT id FROM reglas_clinicas);

WITH reglas_huerfanas AS (
  SELECT r.id
  FROM heuristico.regla r
  LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
  WHERE cr.id_regla IS NULL
    AND upper(coalesce(r.origen_regla, 'CLINICA')) = 'CLINICA'
)
DELETE FROM heuristico.regla
WHERE id IN (SELECT id FROM reglas_huerfanas);

-- 3) Insertar reglas ELIMINAR para GENERAL_REUMATICOS.
WITH
acc AS (SELECT id FROM heuristico.catalogo_accion WHERE upper(nombre) = 'ELIMINAR' LIMIT 1),
obj_ing AS (SELECT id FROM heuristico.catalogo_objetivo_regla WHERE upper(nombre) LIKE 'INGREDIENTE%' LIMIT 1),
obj_sub AS (SELECT id FROM heuristico.catalogo_objetivo_regla WHERE upper(nombre) LIKE 'SUBGRUPO%' LIMIT 1),
obj_etq AS (SELECT id FROM heuristico.catalogo_objetivo_regla WHERE upper(nombre) LIKE 'ETIQUETA%' LIMIT 1),
cond_gen AS (
  SELECT id FROM heuristico.condicion
  WHERE upper(coalesce(indicador_codigo, '')) = 'GENERAL_REUMATICOS'
  LIMIT 1
),
ins AS (
  INSERT INTO heuristico.regla (
    id_accion, id_tipo_objetivo, mensaje_error, es_estricta,
    id_ingrediente, id_subgrupo_alimentario, id_etiqueta, origen_regla
  )
  SELECT acc.id, obj_etq.id, 'No apta: grasas trans elevadas', true, NULL::integer, NULL::integer, 70, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: contiene grasas trans', true, NULL::integer, NULL::integer, 94, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: ultraprocesado', true, NULL::integer, NULL::integer, 138, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: altamente inflamatorio', true, NULL::integer, NULL::integer, 78, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: proinflamatorio', true, NULL::integer, NULL::integer, 118, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: muy alto en sodio', true, NULL::integer, NULL::integer, 112, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_sub.id, 'No apta: salazones de pescado', true, NULL::integer, 37, NULL::integer, 'CLINICA' FROM acc, obj_sub
  UNION ALL SELECT acc.id, obj_sub.id, 'No apta: pescados ahumados', true, NULL::integer, 35, NULL::integer, 'CLINICA' FROM acc, obj_sub
  UNION ALL SELECT acc.id, obj_sub.id, 'No apta: embutidos curados', true, NULL::integer, 109, NULL::integer, 'CLINICA' FROM acc, obj_sub
  UNION ALL SELECT acc.id, obj_sub.id, 'No apta: embutidos frescos y cocidos', true, NULL::integer, 110, NULL::integer, 'CLINICA' FROM acc, obj_sub
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: alto en azucar anadido', true, NULL::integer, NULL::integer, 130, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: bebida azucarada', true, NULL::integer, NULL::integer, 211, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_etq.id, 'No apta: calorias vacias', true, NULL::integer, NULL::integer, 133, 'CLINICA' FROM acc, obj_etq
  UNION ALL SELECT acc.id, obj_sub.id, 'No apta: zumos y nectares comerciales', true, NULL::integer, 53, NULL::integer, 'CLINICA' FROM acc, obj_sub
  UNION ALL SELECT acc.id, obj_sub.id, 'No apta: bebidas isotonicas', true, NULL::integer, 49, NULL::integer, 'CLINICA' FROM acc, obj_sub
  UNION ALL SELECT acc.id, obj_ing.id, 'No apta: aceite de palma', true, 420, NULL::integer, NULL::integer, 'CLINICA' FROM acc, obj_ing
  UNION ALL SELECT acc.id, obj_ing.id, 'No apta: mantequilla', true, 423, NULL::integer, NULL::integer, 'CLINICA' FROM acc, obj_ing
  UNION ALL SELECT acc.id, obj_ing.id, 'No apta: margarina', true, 426, NULL::integer, NULL::integer, 'CLINICA' FROM acc, obj_ing
  UNION ALL SELECT acc.id, obj_ing.id, 'No apta: manteca de cerdo', true, 433, NULL::integer, NULL::integer, 'CLINICA' FROM acc, obj_ing
  RETURNING id
)
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT ins.id, cond_gen.id
FROM ins, cond_gen;

-- 4) LES especifico: alfalfa/L-canavanina (si existe etiqueta/ingrediente).
WITH
acc AS (SELECT id FROM heuristico.catalogo_accion WHERE upper(nombre) = 'ELIMINAR' LIMIT 1),
obj_ing AS (SELECT id FROM heuristico.catalogo_objetivo_regla WHERE upper(nombre) LIKE 'INGREDIENTE%' LIMIT 1),
obj_etq AS (SELECT id FROM heuristico.catalogo_objetivo_regla WHERE upper(nombre) LIKE 'ETIQUETA%' LIMIT 1),
cond_les AS (
  SELECT id FROM heuristico.condicion
  WHERE upper(coalesce(indicador_codigo, '')) = 'LUPUS_ERITEMATOSO_SISTEMICO'
  LIMIT 1
),
id_etq_alf AS (
  SELECT id FROM nutricion.etiqueta_nutricional
  WHERE lower(coalesce(nombre_visible, '')) LIKE '%alfalfa%'
     OR lower(coalesce(codigo, '')) LIKE '%alfalfa%'
  LIMIT 1
),
id_ing_alf AS (
  SELECT id FROM nutricion.ingrediente
  WHERE lower(coalesce(nombre, '')) LIKE '%alfalfa%'
  LIMIT 1
),
ins_les AS (
  INSERT INTO heuristico.regla (
    id_accion, id_tipo_objetivo, mensaje_error, es_estricta,
    id_ingrediente, id_etiqueta, origen_regla
  )
  SELECT acc.id, obj_etq.id, 'No apta LES: alfalfa/L-canavanina', true, NULL::integer, id_etq_alf.id, 'CLINICA'
  FROM acc, obj_etq, id_etq_alf
  UNION ALL
  SELECT acc.id, obj_ing.id, 'No apta LES: alfalfa/L-canavanina', true, id_ing_alf.id, NULL::integer, 'CLINICA'
  FROM acc, obj_ing, id_ing_alf
  RETURNING id
)
INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT ins_les.id, cond_les.id
FROM ins_les, cond_les;

COMMIT;
