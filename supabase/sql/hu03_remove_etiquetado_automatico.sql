-- HU03: Retiro de etiquetado automatico
-- Objetivo:
-- 1) Eliminar el esquema de etiquetado automatico.
-- 2) Mantener el esquema manual basado en:
--    - nutricion.etiqueta_nutricional (catalogo padre)
--    - nutricion.ingrediente_etiqueta (N:M ingrediente-etiqueta)
--
-- Recomendado: ejecutar solo despues de generar backup.

begin;

-- Mantener solo el modelo manual de etiquetas.
drop schema if exists etiquetado cascade;

commit;
