-- HU14: Saneamiento de combinaciones de Media Mañana y Media Tarde (Snacks Pediátricos)
-- Elimina combinaciones compuestas aberrantes (ej. Compota + Postre, Colada + Compota)
-- e introduce combinaciones monoplato o snack + líquido coherentes.

BEGIN;

-- 1. Eliminar asignación errónea de platos fuertes a media mañana y media tarde
DELETE FROM nutricion.receta_momento
WHERE id_momento IN (2, 4)
  AND id_receta IN (197, 198, 199, 200, 201);

-- 2. Eliminar combinaciones antiguas de media mañana (2) y media tarde (4)
DELETE FROM nutricion.regla_menu_combinacion
WHERE id_momento IN (2, 4);

-- 3. Crear función auxiliar para insertar y asociar combinaciones
CREATE OR REPLACE PROCEDURE nutricion.sp_crear_combinacion_snack(
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

-- Condicion IDs:
-- LIGERA: 30, 111, 122, 123 (Peso elevado, Riesgo sobrepeso, Sobrepeso, Obesidad)
-- EQUILIBRADA: 29, 110, 112, 117 (Peso normal, Normal, Talla normal, Talla alta)
-- ENERGETICA: 28, 101, 119, 125 (Bajo peso, Emaciación, Delgadez, Talla baja)
-- RECUPERACION: 27, 100, 118, 124 (Bajo peso severo, Emaciación severa, Delgadez severa, Talla baja severa)
-- SUAVE: 27, 28, 100, 101, 119

DO $$
DECLARE
    m INT;
    cond_ligera INT[] := ARRAY[30, 111, 122, 123];
    cond_equil INT[] := ARRAY[29, 110, 112, 117];
    cond_energ INT[] := ARRAY[28, 101, 119, 125];
    cond_recup INT[] := ARRAY[27, 100, 118, 124];
    cond_suave INT[] := ARRAY[27, 28, 100, 101, 119];
BEGIN
    FOR m IN 2..4 LOOP
        IF m = 3 THEN CONTINUE; END IF; -- Solo momentos 2 (Media Mañana) y 4 (Media Tarde)

        -- COMBINACION_LIGERA (Monoplatos frescos, saciantes y bajos en calorías)
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_LIGERA', '[{"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37', cond_ligera);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_LIGERA', '[{"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '44', cond_ligera);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_LIGERA', '[{"id": 30, "nombre": "Colación ligera"}]'::jsonb, '30', cond_ligera);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_LIGERA', '[{"id": 45, "nombre": "Snack saludable"}]'::jsonb, '45', cond_ligera);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_LIGERA', '[{"id": 37, "nombre": "Fruta preparada"}, {"id": 31, "nombre": "Infusión"}]'::jsonb, '31-37', cond_ligera);

        -- COMBINACION_EQUILIBRADA (Monoplatos balanceados o snack + hidratación natural)
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 37, "nombre": "Fruta preparada"}]'::jsonb, '37', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '44', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 33, "nombre": "Barra saludable"}]'::jsonb, '33', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 48, "nombre": "Horneado"}]'::jsonb, '48', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 28, "nombre": "Sandwich saludable"}]'::jsonb, '28', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 37, "nombre": "Fruta preparada"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '37-44', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 37, "nombre": "Fruta preparada"}, {"id": 43, "nombre": "Frutos secos"}]'::jsonb, '37-43', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 28, "nombre": "Sandwich saludable"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '28-36', cond_equil);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_EQUILIBRADA', '[{"id": 48, "nombre": "Horneado"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '36-48', cond_equil);

        -- COMBINACION_ENERGETICA (Densidad energética limpia monoplato o con fruto seco)
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_ENERGETICA', '[{"id": 46, "nombre": "Batido"}]'::jsonb, '46', cond_energ);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_ENERGETICA', '[{"id": 21, "nombre": "Colada"}]'::jsonb, '21', cond_energ);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_ENERGETICA', '[{"id": 28, "nombre": "Sandwich saludable"}]'::jsonb, '28', cond_energ);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_ENERGETICA', '[{"id": 44, "nombre": "Yogur preparado"}, {"id": 43, "nombre": "Frutos secos"}]'::jsonb, '43-44', cond_energ);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_ENERGETICA', '[{"id": 33, "nombre": "Barra saludable"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '33-44', cond_energ);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_ENERGETICA', '[{"id": 48, "nombre": "Horneado"}, {"id": 36, "nombre": "Jugo natural"}]'::jsonb, '36-48', cond_energ);

        -- COMBINACION_RECUPERACION_NUTRICIONAL (Alta proteína y energía)
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 46, "nombre": "Batido"}]'::jsonb, '46', cond_recup);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 21, "nombre": "Colada"}]'::jsonb, '21', cond_recup);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 28, "nombre": "Sandwich saludable"}]'::jsonb, '28', cond_recup);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 44, "nombre": "Yogur preparado"}, {"id": 43, "nombre": "Frutos secos"}]'::jsonb, '43-44', cond_recup);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_RECUPERACION_NUTRICIONAL', '[{"id": 48, "nombre": "Horneado"}, {"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '44-48', cond_recup);

        -- COMBINACION_SUAVE (Textura fácil para brote o deglución difícil)
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_SUAVE', '[{"id": 35, "nombre": "Compota"}]'::jsonb, '35', cond_suave);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_SUAVE', '[{"id": 44, "nombre": "Yogur preparado"}]'::jsonb, '44', cond_suave);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_SUAVE', '[{"id": 21, "nombre": "Colada"}]'::jsonb, '21', cond_suave);
        CALL nutricion.sp_crear_combinacion_snack(m, 'COMBINACION_SUAVE', '[{"id": 46, "nombre": "Batido"}]'::jsonb, '46', cond_suave);
    END LOOP;
END;
$$;

DROP PROCEDURE IF EXISTS nutricion.sp_crear_combinacion_snack(INT, TEXT, JSONB, TEXT, INT[]);

COMMIT;
