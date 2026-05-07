-- SCRIPT PARA GENERACIÓN MASIVA DE REGLAS NUTRICIONALES
-- Este script puebla la tabla heuristico.regla con recomendaciones inteligentes
-- basadas en el estado nutricional del paciente.

DO $$
DECLARE
    r_cond RECORD;
    r_item RECORD;
    v_regla_id INTEGER;
    v_accion INTEGER;
    v_mensaje TEXT;
    v_es_exceso BOOLEAN;
    v_es_deficit BOOLEAN;
BEGIN
    -- 1. Limpiar reglas nutricionales previas para evitar duplicados (opcional)
    -- DELETE FROM heuristico.condicion_regla WHERE id_regla IN (SELECT id FROM heuristico.regla WHERE origen_regla = 'NUTRICIONAL');
    -- DELETE FROM heuristico.regla WHERE origen_regla = 'NUTRICIONAL';

    -- 2. Recorrer cada condición nutricional (tipo 3)
    FOR r_cond IN 
        SELECT id, nombre FROM heuristico.condicion WHERE id_tipo_condicion = 3 AND activa = true
    LOOP
        -- Determinar si la condición es de exceso o déficit
        v_es_exceso := (r_cond.nombre ILIKE '%sobrepeso%' OR r_cond.nombre ILIKE '%elevado%' OR r_cond.nombre ILIKE '%obesidad%' OR r_cond.nombre ILIKE '%alta%');
        v_es_deficit := (r_cond.nombre ILIKE '%bajo%' OR r_cond.nombre ILIKE '%severa%' OR r_cond.nombre ILIKE '%delgadez%' OR r_cond.nombre ILIKE '%desnutrición%' OR r_cond.nombre ILIKE '%desnutricion%');

        -- A. REGLAS PARA INGREDIENTES (5 items)
        FOR r_item IN SELECT id, nombre FROM nutricion.ingrediente WHERE activo = true LIMIT 5 LOOP
            v_accion := CASE WHEN v_es_exceso THEN 2 WHEN v_es_deficit THEN 3 ELSE 4 END;
            v_mensaje := 'Ajustar consumo de ' || r_item.nombre || ' debido a estado de ' || r_cond.nombre || '.';
            
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, mensaje_error, origen_regla, es_estricta)
            VALUES (v_accion, 1, r_item.id, v_mensaje, 'NUTRICIONAL', false) RETURNING id INTO v_regla_id;
            
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (r_cond.id, v_regla_id);
        END LOOP;

        -- B. REGLAS PARA GRUPOS ALIMENTARIOS (5 items)
        FOR r_item IN SELECT id, nombre FROM nutricion.grupo_alimentario LIMIT 5 LOOP
            v_accion := CASE WHEN v_es_exceso THEN 2 WHEN v_es_deficit THEN 3 ELSE 4 END;
            v_mensaje := 'Controlar grupo ' || r_item.nombre || ' en pacientes con ' || r_cond.nombre || '.';
            
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, mensaje_error, origen_regla, es_estricta)
            VALUES (v_accion, 2, r_item.id, v_mensaje, 'NUTRICIONAL', false) RETURNING id INTO v_regla_id;
            
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (r_cond.id, v_regla_id);
        END LOOP;

        -- C. REGLAS PARA ETIQUETAS NUTRICIONALES (5 items)
        FOR r_item IN SELECT id, nombre_visible FROM nutricion.etiqueta_nutricional LIMIT 5 LOOP
            IF (r_item.nombre_visible ILIKE '%grasa%' OR r_item.nombre_visible ILIKE '%calor%') THEN
                v_accion := CASE WHEN v_es_exceso THEN 1 ELSE 3 END;
            ELSIF (r_item.nombre_visible ILIKE '%fibra%' OR r_item.nombre_visible ILIKE '%proteína%') THEN
                v_accion := 3;
            ELSE
                v_accion := 4;
            END IF;
            
            v_mensaje := 'Observar etiqueta ' || r_item.nombre_visible || ' en contexto de ' || r_cond.nombre || '.';
            
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, origen_regla, es_estricta)
            VALUES (v_accion, 3, r_item.id, v_mensaje, 'NUTRICIONAL', false) RETURNING id INTO v_regla_id;
            
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (r_cond.id, v_regla_id);
        END LOOP;

        -- D. REGLAS PARA SUBGRUPOS ALIMENTARIOS (5 items)
        FOR r_item IN SELECT id, nombre FROM nutricion.subgrupo_alimentario LIMIT 5 LOOP
            v_accion := CASE WHEN v_es_exceso THEN 2 WHEN v_es_deficit THEN 3 ELSE 4 END;
            v_mensaje := 'Recomendación para subgrupo ' || r_item.nombre || ' bajo ' || r_cond.nombre || '.';
            
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, mensaje_error, origen_regla, es_estricta)
            VALUES (v_accion, 4, r_item.id, v_mensaje, 'NUTRICIONAL', false) RETURNING id INTO v_regla_id;
            
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla) VALUES (r_cond.id, v_regla_id);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Poblamiento de reglas nutricionales completado.';
END $$;
