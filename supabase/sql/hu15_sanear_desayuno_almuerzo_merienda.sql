-- HU15: Saneamiento Integral de Menús para Desayuno (1), Almuerzo (3) y Merienda (5)
-- Elimina combinaciones absurdas:
--   - Desayuno: elimina sopas, purés de papa y queques con sopa.
--   - Almuerzo: elimina coladas con carne/guisos y dobles/triples dulces.
--   - Merienda: elimina cenas pesadas con colada+parrilla y cenas de solo postre (colada+horneado+yogur).
-- Establece plantillas coherentes, digestivas y equilibradas.

BEGIN;

-- 1. Eliminar combinaciones antiguas de Desayuno (1), Almuerzo (3) y Merienda (5)
DELETE FROM nutricion.regla_menu_combinacion
WHERE id_momento IN (1, 3, 5);

-- 2. Procedimiento auxiliar para insertar combinaciones y condiciones
CREATE OR REPLACE PROCEDURE nutricion.sp_crear_combinacion_menu(
    p_momento INT,
    p_rol TEXT,
    p_platillos JSONB,
    p_key TEXT,
    p_condiciones INT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_combo_id BIGINT;
    v_cond INT;
BEGIN
    INSERT INTO nutricion.regla_menu_combinacion (id_momento, rol, platillos, platillos_key, activo)
    VALUES (p_momento, p_rol, p_platillos, p_key, true)
    RETURNING id INTO v_combo_id;

    FOREACH v_cond IN ARRAY p_condiciones LOOP
        INSERT INTO nutricion.regla_menu_combinacion_condicion (id_regla_menu_combinacion, id_condicion_nutricional)
        VALUES (v_combo_id, v_cond)
        ON CONFLICT DO NOTHING;
    END LOOP;
END;
$$;

DO $$
DECLARE
    cond_ligera INT[] := ARRAY[30, 111, 122, 123]; -- Peso elevado, Riesgo sobrepeso, Sobrepeso, Obesidad
    cond_equil INT[]  := ARRAY[29, 110, 112, 117]; -- Peso normal, Normal, Talla normal, Talla alta
    cond_energ INT[]  := ARRAY[28, 101, 119, 125]; -- Bajo peso, Emaciación, Delgadez, Talla baja
    cond_recup INT[]  := ARRAY[27, 100, 118, 124]; -- Bajo peso severo, Emaciación severa, Delgadez severa, Talla baja severa
    cond_suave INT[]  := ARRAY[27, 28, 100, 101, 119]; -- Texturas suaves para brote / deglución
BEGIN

    -- =========================================================================
    -- MOMENTO 1: DESAYUNO
    -- =========================================================================
    -- COMBINACION_LIGERA
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_LIGERA', '[{"id": 49, "nombre": "Desayuno"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '31-49', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_LIGERA', '[{"id": 42, "nombre": "Tortilla"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37-42', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_LIGERA', '[{"id": 49, "nombre": "Desayuno"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37-49', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_LIGERA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '28-31', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_LIGERA', '[{"id": 39, "nombre": "Wrap desayuno"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '31-39', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_LIGERA', '[{"id": 44, "nombre": "Yogur preparado"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37-44', cond_ligera);

    -- COMBINACION_EQUILIBRADA
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 49, "nombre": "Desayuno"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37-49', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 42, "nombre": "Tortilla"}, {"id": 37, "nombre": "Fruta preparada"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '36-37-42', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '28-37', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 39, "nombre": "Wrap desayuno"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '36-39', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 22, "nombre": "Pancakes saludables"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '22-37', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 17, "nombre": "Bowl nutricional"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '17-37', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_EQUILIBRADA', '[{"id": 48, "nombre": "Horneado"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '44-48', cond_equil);

    -- COMBINACION_ENERGETICA
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_ENERGETICA', '[{"id": 49, "nombre": "Desayuno"}, {"id": 46, "nombre": "Batido"}]'::jsonb, '46-49', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_ENERGETICA', '[{"id": 42, "nombre": "Tortilla"}, {"id": 21, "nombre": "Colada"}]'::jsonb, '21-42', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_ENERGETICA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 21, "nombre": "Colada"}]'::jsonb, '21-28', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_ENERGETICA', '[{"id": 22, "nombre": "Pancakes saludables"}, {"id": 44, "nombre": "Yogur preparado"}, {"id": 43, "nombre": "Frutos secos"}]'::jsonb, '22-43-44', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_ENERGETICA', '[{"id": 39, "nombre": "Wrap desayuno"}, {"id": 46, "nombre": "Batido"}]'::jsonb, '39-46', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_ENERGETICA', '[{"id": 48, "nombre": "Horneado"}, {"id": 21, "nombre": "Colada"}]'::jsonb, '21-48', cond_energ);

    -- COMBINACION_RECUPERACION_NUTRICIONAL
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 49, "nombre": "Desayuno"}, {"id": 46, "nombre": "Batido"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37-46-49', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 21, "nombre": "Colada"}, {"id": 43, "nombre": "Frutos secos"}]'::jsonb, '21-28-43', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 22, "nombre": "Pancakes saludables"}, {"id": 46, "nombre": "Batido"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '22-44-46', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 42, "nombre": "Tortilla"}, {"id": 21, "nombre": "Colada"}, {"id": 48, "nombre": "Horneado"}]'::jsonb, '21-42-48', cond_recup);

    -- COMBINACION_SUAVE
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_SUAVE', '[{"id": 21, "nombre": "Colada"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '21-37', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_SUAVE', '[{"id": 44, "nombre": "Yogur preparado"}, {"id": 35, "nombre": "Compota"}]'::jsonb, '35-44', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_SUAVE', '[{"id": 46, "nombre": "Batido"}, {"id": 35, "nombre": "Compota"}]'::jsonb, '35-46', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(1, 'COMBINACION_SUAVE', '[{"id": 22, "nombre": "Pancakes saludables"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '22-44', cond_suave);

    -- =========================================================================
    -- MOMENTO 3: ALMUERZO
    -- =========================================================================
    -- COMBINACION_LIGERA
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_LIGERA', '[{"id": 16, "nombre": "Sopa"}, {"id": 40, "nombre": "Ensalada"}, {"id": 20, "nombre": "Parrilla"}]'::jsonb, '16-20-40', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_LIGERA', '[{"id": 40, "nombre": "Ensalada"}, {"id": 25, "nombre": "Plato fuerte"}]'::jsonb, '25-40', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_LIGERA', '[{"id": 16, "nombre": "Sopa"}, {"id": 23, "nombre": "Plato ligero"}]'::jsonb, '16-23', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_LIGERA', '[{"id": 17, "nombre": "Bowl nutricional"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '17-37', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_LIGERA', '[{"id": 40, "nombre": "Ensalada"}, {"id": 26, "nombre": "Salteado"}]'::jsonb, '26-40', cond_ligera);

    -- COMBINACION_EQUILIBRADA
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 16, "nombre": "Sopa"}, {"id": 25, "nombre": "Plato fuerte"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '16-25-36', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 40, "nombre": "Ensalada"}, {"id": 25, "nombre": "Plato fuerte"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '25-36-40', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 41, "nombre": "Arroz preparado"}, {"id": 19, "nombre": "Estofado"}, {"id": 40, "nombre": "Ensalada"}]'::jsonb, '19-40-41', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 41, "nombre": "Arroz preparado"}, {"id": 20, "nombre": "Parrilla"}, {"id": 40, "nombre": "Ensalada"}]'::jsonb, '20-40-41', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 47, "nombre": "Pasta saludable"}, {"id": 40, "nombre": "Ensalada"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '36-40-47', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 16, "nombre": "Sopa"}, {"id": 29, "nombre": "Guiso"}, {"id": 41, "nombre": "Arroz preparado"}]'::jsonb, '16-29-41', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_EQUILIBRADA', '[{"id": 17, "nombre": "Bowl nutricional"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '17-36', cond_equil);

    -- COMBINACION_ENERGETICA
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_ENERGETICA', '[{"id": 16, "nombre": "Sopa"}, {"id": 25, "nombre": "Plato fuerte"}, {"id": 41, "nombre": "Arroz preparado"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '16-25-36-41', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_ENERGETICA', '[{"id": 41, "nombre": "Arroz preparado"}, {"id": 29, "nombre": "Guiso"}, {"id": 32, "nombre": "Puré"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '29-32-36-41', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_ENERGETICA', '[{"id": 47, "nombre": "Pasta saludable"}, {"id": 20, "nombre": "Parrilla"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '20-36-47', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_ENERGETICA', '[{"id": 16, "nombre": "Sopa"}, {"id": 25, "nombre": "Plato fuerte"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '16-25-37', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_ENERGETICA', '[{"id": 19, "nombre": "Estofado"}, {"id": 41, "nombre": "Arroz preparado"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '19-37-41', cond_energ);

    -- COMBINACION_RECUPERACION_NUTRICIONAL
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 16, "nombre": "Sopa"}, {"id": 25, "nombre": "Plato fuerte"}, {"id": 41, "nombre": "Arroz preparado"}, {"id": 34, "nombre": "Postre saludable"}]'::jsonb, '16-25-34-41', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 41, "nombre": "Arroz preparado"}, {"id": 19, "nombre": "Estofado"}, {"id": 32, "nombre": "Puré"}, {"id": 34, "nombre": "Postre saludable"}]'::jsonb, '19-32-34-41', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 16, "nombre": "Sopa"}, {"id": 29, "nombre": "Guiso"}, {"id": 41, "nombre": "Arroz preparado"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '16-29-36-41', cond_recup);

    -- COMBINACION_SUAVE
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_SUAVE', '[{"id": 16, "nombre": "Sopa"}, {"id": 32, "nombre": "Puré"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '16-32-37', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_SUAVE', '[{"id": 16, "nombre": "Sopa"}, {"id": 23, "nombre": "Plato ligero"}, {"id": 35, "nombre": "Compota"}]'::jsonb, '16-23-35', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(3, 'COMBINACION_SUAVE', '[{"id": 19, "nombre": "Estofado"}, {"id": 32, "nombre": "Puré"}, {"id": 35, "nombre": "Compota"}]'::jsonb, '19-32-35', cond_suave);

    -- =========================================================================
    -- MOMENTO 5: MERIENDA / CENA (NOCHE)
    -- =========================================================================
    -- COMBINACION_LIGERA
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_LIGERA', '[{"id": 16, "nombre": "Sopa"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '16-31', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_LIGERA', '[{"id": 40, "nombre": "Ensalada"}, {"id": 23, "nombre": "Plato ligero"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '23-31-40', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_LIGERA', '[{"id": 42, "nombre": "Tortilla"}, {"id": 40, "nombre": "Ensalada"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '31-40-42', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_LIGERA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '28-31', cond_ligera);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_LIGERA', '[{"id": 38, "nombre": "Wrap saludable"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '31-38', cond_ligera);

    -- COMBINACION_EQUILIBRADA
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_EQUILIBRADA', '[{"id": 16, "nombre": "Sopa"}, {"id": 23, "nombre": "Plato ligero"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '16-23-31', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_EQUILIBRADA', '[{"id": 42, "nombre": "Tortilla"}, {"id": 40, "nombre": "Ensalada"}]'::jsonb, '40-42', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_EQUILIBRADA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '28-31', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_EQUILIBRADA', '[{"id": 38, "nombre": "Wrap saludable"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '31-38', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_EQUILIBRADA', '[{"id": 17, "nombre": "Bowl nutricional"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '17-31', cond_equil);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_EQUILIBRADA', '[{"id": 26, "nombre": "Salteado"}, {"id": 40, "nombre": "Ensalada"}]'::jsonb, '26-40', cond_equil);

    -- COMBINACION_ENERGETICA
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_ENERGETICA', '[{"id": 16, "nombre": "Sopa"}, {"id": 25, "nombre": "Plato fuerte"}]'::jsonb, '16-25', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_ENERGETICA', '[{"id": 41, "nombre": "Arroz preparado"}, {"id": 26, "nombre": "Salteado"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '26-31-41', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_ENERGETICA', '[{"id": 47, "nombre": "Pasta saludable"}, {"id": 23, "nombre": "Plato ligero"}]'::jsonb, '23-47', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_ENERGETICA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '28-44', cond_energ);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_ENERGETICA', '[{"id": 38, "nombre": "Wrap saludable"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '38-44', cond_energ);

    -- COMBINACION_RECUPERACION_NUTRICIONAL
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 16, "nombre": "Sopa"}, {"id": 25, "nombre": "Plato fuerte"}, {"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '16-25-37', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 41, "nombre": "Arroz preparado"}, {"id": 29, "nombre": "Guiso"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '29-31-41', cond_recup);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 47, "nombre": "Pasta saludable"}, {"id": 20, "nombre": "Parrilla"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '20-31-47', cond_recup);

    -- COMBINACION_SUAVE
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_SUAVE', '[{"id": 16, "nombre": "Sopa"}, {"id": 32, "nombre": "Puré"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '16-31-32', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_SUAVE', '[{"id": 16, "nombre": "Sopa"}, {"id": 23, "nombre": "Plato ligero"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '16-23-31', cond_suave);
    CALL nutricion.sp_crear_combinacion_menu(5, 'COMBINACION_SUAVE', '[{"id": 23, "nombre": "Plato ligero"}, {"id": 35, "nombre": "Compota"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '23-31-35', cond_suave);

END;
$$;

DROP PROCEDURE IF EXISTS nutricion.sp_crear_combinacion_menu(INT, TEXT, JSONB, TEXT, INT[]);

COMMIT;
