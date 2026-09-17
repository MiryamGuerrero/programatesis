-- HU13: Optimización de obtención de recetas seguras con preferencias reales y reglas de seguridad individuales.

CREATE OR REPLACE FUNCTION nutricion.obtener_recetas_seguras_eficiente(p_id_paciente uuid, p_limite integer DEFAULT 1000)
 RETURNS TABLE(id integer, nombre text, semaforo text, momentos_ids integer[], tipos_plato_ids integer[], grupos_alimentarios_ids integer[], imagen_url text, es_preferida boolean, es_potenciada boolean, es_disminuida boolean)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_bloqueados_ing INT[];
    v_bloqueados_sub INT[];
    v_bloqueadas_etq TEXT[];
    v_reglas_bloqueadas_receta INT[];
    
    v_potenciados_ing INT[];
    v_potenciados_sub INT[];
    v_potenciados_etq TEXT[];
    v_recom_ing INT[];
    
    v_disminuidos_ing INT[];
    v_disminuidos_sub INT[];
    v_disminuidos_etq TEXT[];
    
    v_condiciones_paciente INT[];
BEGIN
    -- 1. Obtener condiciones activas del paciente (diagnóstico base + temporales activas del último control)
    SELECT array_agg(DISTINCT id_condicion) INTO v_condiciones_paciente
    FROM (
        SELECT id_condicion FROM clinico.diagnostico_paciente 
        WHERE id_paciente = p_id_paciente AND esta_activo = true
        UNION
        SELECT cca.id_condicion FROM clinico.control_condicion_activa cca
        JOIN clinico.control_paciente cp ON cp.id = cca.id_control
        WHERE cp.id_paciente = p_id_paciente AND cca.esta_activa = true
    ) sub;

    -- 2. Blacklist Nivel 1: Alergias del paciente (Ingrediente y Subgrupo)
    SELECT array_agg(id_ingrediente) INTO v_bloqueados_ing
    FROM clinico.alergia_paciente_ingrediente 
    WHERE id_paciente = p_id_paciente AND activa = true;

    SELECT array_agg(id_subgrupo_alimentario) INTO v_bloqueados_sub
    FROM clinico.alergia_paciente_subgrupo 
    WHERE id_paciente = p_id_paciente AND activa = true;

    -- Restricciones médicas (etiquetas bloqueantes directas con fallback)
    SELECT array_agg(DISTINCT 
        coalesce(
            cra.etiqueta_bloqueante_codigo,
            case upper(coalesce(rp.codigo_restriccion, ''))
                when 'INTOLERANCIA_LACTOSA' then 'NO_APTO_PARA_INTOLERANTES_A_LACTOSA'
                when 'INTOLERANCIA_GLUTEN' then 'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN'
                when 'CELIAQUIA' then 'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN'
                when 'ALERGIA_GLUTEN' then 'NO_APTO_PARA_INTOLERANTES_AL_GLUTEN'
                when 'INTOLERANCIA_FRUCTOSA' then 'NO_APTO_INTOLERANCIA_FRUCTOSA'
                when 'INTOLERANCIA_SULFITOS' then 'NO_APTO_PARA_INTOLERANTES_A_SULFITO'
                when 'ALERGIA_SULFITOS' then 'NO_APTO_PARA_INTOLERANTES_A_SULFITO'
                when 'VEGETARIANO' then 'NO_APTO_VEGETARIANOS'
                when 'VEGETARIANA' then 'NO_APTO_VEGETARIANOS'
                when 'DIABETES' then 'NO_APTO_DIABETICOS'
                when 'DIABETES_MELLITUS' then 'NO_APTO_DIABETICOS'
                else null
            end
        )
    )
    INTO v_bloqueadas_etq
    FROM clinico.restriccion_paciente rp
    LEFT JOIN clinico.catalogo_restriccion_alimentaria cra ON cra.codigo = rp.codigo_restriccion
    WHERE rp.id_paciente = p_id_paciente AND rp.activa = true;

    -- Reglas clínicas individuales con acción ELIMINAR (id_accion = 1, ej. Lupus / condiciones agudas)
    IF v_condiciones_paciente IS NOT NULL AND array_length(v_condiciones_paciente, 1) > 0 THEN
        SELECT array_agg(DISTINCT u.id_ingrediente) FILTER (WHERE u.id_ingrediente IS NOT NULL)
        INTO v_bloqueados_ing
        FROM (
            SELECT unnest(coalesce(v_bloqueados_ing, '{}'::int[])) AS id_ingrediente
            UNION
            SELECT r.id_ingrediente
            FROM heuristico.regla r
            JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
            WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 1 AND r.id_ingrediente IS NOT NULL
        ) u;

        SELECT array_agg(DISTINCT u.id_subgrupo_alimentario) FILTER (WHERE u.id_subgrupo_alimentario IS NOT NULL)
        INTO v_bloqueados_sub
        FROM (
            SELECT unnest(coalesce(v_bloqueados_sub, '{}'::int[])) AS id_subgrupo_alimentario
            UNION
            SELECT r.id_subgrupo_alimentario
            FROM heuristico.regla r
            JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
            WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 1 AND r.id_subgrupo_alimentario IS NOT NULL
        ) u;

        SELECT array_agg(DISTINCT r.id_receta) FILTER (WHERE r.id_receta IS NOT NULL)
        INTO v_reglas_bloqueadas_receta
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 1 AND r.id_receta IS NOT NULL;
    END IF;

    -- 3. Nivel 3: Priorización Clínica (Potenciados por Reglas + Recomendaciones Médicas)
    SELECT array_agg(DISTINCT id_ingrediente) INTO v_recom_ing
    FROM clinico.recomendacion_ingrediente
    WHERE id_paciente = p_id_paciente AND activa = true;

    IF v_condiciones_paciente IS NOT NULL AND array_length(v_condiciones_paciente, 1) > 0 THEN
        -- Potenciados por reglas clínicas (ingredientes, subgrupos, etiquetas)
        SELECT array_agg(DISTINCT r.id_ingrediente) FILTER (WHERE r.id_ingrediente IS NOT NULL)
        INTO v_potenciados_ing
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 2;

        SELECT array_agg(DISTINCT r.id_subgrupo_alimentario) FILTER (WHERE r.id_subgrupo_alimentario IS NOT NULL)
        INTO v_potenciados_sub
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 2;

        SELECT array_agg(DISTINCT en.codigo) FILTER (WHERE en.codigo IS NOT NULL)
        INTO v_potenciados_etq
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        JOIN nutricion.etiqueta_nutricional en ON en.id = r.id_etiqueta
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 2;

        -- Disminuidos por reglas clínicas (ingredientes, subgrupos, etiquetas)
        SELECT array_agg(DISTINCT r.id_ingrediente) FILTER (WHERE r.id_ingrediente IS NOT NULL)
        INTO v_disminuidos_ing
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 3;

        SELECT array_agg(DISTINCT r.id_subgrupo_alimentario) FILTER (WHERE r.id_subgrupo_alimentario IS NOT NULL)
        INTO v_disminuidos_sub
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 3;

        SELECT array_agg(DISTINCT en.codigo) FILTER (WHERE en.codigo IS NOT NULL)
        INTO v_disminuidos_etq
        FROM heuristico.regla r
        JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        JOIN nutricion.etiqueta_nutricional en ON en.id = r.id_etiqueta
        WHERE cr.id_condicion = ANY(v_condiciones_paciente) AND r.id_accion = 3;
    END IF;

    -- 4. Consulta Final
    RETURN QUERY
    WITH receta_data AS (
        SELECT 
            r.id, 
            r.nombre::TEXT, 
            r.imagen_url::TEXT,
            (SELECT array_agg(rm.id_momento) FROM nutricion.receta_momento rm WHERE rm.id_receta = r.id) as m_ids,
            (SELECT array_agg(rtp.id_tipo_plato) FROM nutricion.receta_tipo_plato rtp WHERE rtp.id_receta = r.id) as t_ids,
            (SELECT array_agg(ri.id_ingrediente) FROM nutricion.receta_ingrediente ri WHERE ri.id_receta = r.id) as i_ids,
            (SELECT array_agg(en.codigo) FROM nutricion.receta_etiqueta re JOIN nutricion.etiqueta_nutricional en ON en.id = re.id_etiqueta WHERE re.id_receta = r.id) as e_cods,
            (SELECT array_agg(ing.id_subgrupo_alimentario) FROM nutricion.receta_ingrediente ri2 JOIN nutricion.ingrediente ing ON ing.id = ri2.id_ingrediente WHERE ri2.id_receta = r.id) as s_ids,
            (SELECT array_agg(DISTINCT sg.id_grupo_alimentario) FROM nutricion.receta_ingrediente ri3 JOIN nutricion.ingrediente ing3 ON ing3.id = ri3.id_ingrediente JOIN nutricion.subgrupo_alimentario sg ON sg.id = ing3.id_subgrupo_alimentario WHERE ri3.id_receta = r.id) as g_ids
        FROM nutricion.receta r
        WHERE r.activa = true
    ),
    eval_data AS (
        SELECT 
            rd.id, 
            rd.nombre,
            rd.m_ids, 
            rd.t_ids, 
            rd.g_ids,
            rd.imagen_url,
            -- Preferencia real: subgrupos preferidos por el paciente O receta favorita explícita
            (
                EXISTS(
                    SELECT 1 FROM interaccion.preferencia_paciente pp 
                    WHERE pp.id_paciente = p_id_paciente AND pp.id_subgrupo_alimentario = ANY(rd.s_ids)
                )
                OR EXISTS(
                    SELECT 1 FROM interaccion.preferencia_receta pref 
                    WHERE pref.id_paciente = p_id_paciente AND pref.id_receta = rd.id
                )
            ) as es_preferida,
            -- Potenciada por reglas clínicas o recomendación del médico
            (
                (rd.i_ids && coalesce(v_potenciados_ing, '{}'::int[]))
                OR (rd.s_ids && coalesce(v_potenciados_sub, '{}'::int[]))
                OR (rd.e_cods && coalesce(v_potenciados_etq, '{}'::text[]))
                OR (rd.i_ids && coalesce(v_recom_ing, '{}'::int[]))
            ) as es_potenciada,
            -- Disminuida por reglas clínicas
            (
                (rd.i_ids && coalesce(v_disminuidos_ing, '{}'::int[]))
                OR (rd.s_ids && coalesce(v_disminuidos_sub, '{}'::int[]))
                OR (rd.e_cods && coalesce(v_disminuidos_etq, '{}'::text[]))
            ) as es_disminuida
        FROM receta_data rd
        WHERE 
            NOT (rd.i_ids && coalesce(v_bloqueados_ing, '{}'::int[]))
            AND NOT (rd.s_ids && coalesce(v_bloqueados_sub, '{}'::int[]))
            AND NOT (rd.e_cods && coalesce(v_bloqueadas_etq, '{}'::text[]))
            AND NOT (rd.id = ANY(coalesce(v_reglas_bloqueadas_receta, '{}'::int[])))
    )
    SELECT
        ed.id,
        ed.nombre,
        (CASE WHEN ed.es_potenciada THEN 'verde' WHEN ed.es_disminuida THEN 'amarillo' ELSE 'neutral' END)::TEXT as semaforo,
        ed.m_ids as momentos_ids,
        ed.t_ids as tipos_plato_ids,
        ed.g_ids as grupos_alimentarios_ids,
        ed.imagen_url,
        ed.es_preferida,
        ed.es_potenciada,
        ed.es_disminuida
    FROM eval_data ed
    LIMIT p_limite;
END;
$function$;
