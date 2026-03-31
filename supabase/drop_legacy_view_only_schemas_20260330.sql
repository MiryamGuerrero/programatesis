-- =====================================================
-- Reuma Nutri - Eliminar esquemas legacy sin tablas base
-- Fecha: 2026-03-30
-- Objetivo: mantener solo esquemas con tablas fisicas
-- =====================================================

BEGIN;

DO $$
DECLARE
    schema_name text;
    base_table_count integer;
BEGIN
    FOREACH schema_name IN ARRAY ARRAY[
        'seguridad',
        'usuarios',
        'clinico',
        'nutricion',
        'heuristico',
        'interaccion',
        'referencia'
    ]
    LOOP
        IF EXISTS (
            SELECT 1
            FROM pg_namespace
            WHERE nspname = schema_name
        ) THEN
            SELECT count(*)::int
            INTO base_table_count
            FROM information_schema.tables
            WHERE table_schema = schema_name
              AND table_type = 'BASE TABLE';

            IF base_table_count = 0 THEN
                EXECUTE format('DROP SCHEMA %I CASCADE', schema_name);
            END IF;
        END IF;
    END LOOP;
END $$;

ALTER ROLE authenticator IN DATABASE postgres
SET pgrst.db_schemas =
    'public,storage,graphql_public,dom_auditoria_seguridad,dom_identidad_usuarios,dom_identidad_catalogos,dom_territorio_catalogos,dom_clinica_diagnosticos,dom_clinica_controles,dom_clinica_alergias,dom_clinica_objetivos,dom_nutricion_catalogos,dom_nutricion_ingredientes,dom_nutricion_ingrediente_rel,dom_recetas_base,dom_recetas_composicion,dom_recetas_analitica,dom_reglas_catalogos,dom_reglas_motor,dom_planes_catalogos_estado,dom_planes_catalogos_tipo,dom_planes_base,dom_planes_permitidos,dom_planes_reemplazos,dom_compras,dom_tutor_acompanamiento,dom_experiencia_usuario,dom_referencia_oms';

ALTER ROLE authenticator
SET pgrst.db_schemas =
    'public,storage,graphql_public,dom_auditoria_seguridad,dom_identidad_usuarios,dom_identidad_catalogos,dom_territorio_catalogos,dom_clinica_diagnosticos,dom_clinica_controles,dom_clinica_alergias,dom_clinica_objetivos,dom_nutricion_catalogos,dom_nutricion_ingredientes,dom_nutricion_ingrediente_rel,dom_recetas_base,dom_recetas_composicion,dom_recetas_analitica,dom_reglas_catalogos,dom_reglas_motor,dom_planes_catalogos_estado,dom_planes_catalogos_tipo,dom_planes_base,dom_planes_permitidos,dom_planes_reemplazos,dom_compras,dom_tutor_acompanamiento,dom_experiencia_usuario,dom_referencia_oms';

NOTIFY pgrst, 'reload config';
NOTIFY pgrst, 'reload schema';

COMMIT;
