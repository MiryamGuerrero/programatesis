-- =============================================
-- CREAR REGLAS PARA TODAS LAS CONDICIONES REALES
-- Basado en la base de datos Supabase real
-- =============================================

-- =============================================
-- PASO 1: CREAR ETIQUETAS NECESARIAS
-- =============================================

INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion, activo) VALUES
  ('ANTIINFLAMATORIO', 'Antiinflamatorio', 'Alimentos que reducen la inflamación sistémica', true),
  ('OMEGA3', 'Rico en Omega-3', 'Ácidos grasos antiinflamatorios EPA y DHA', true),
  ('CURCUMA', 'Cúrcuma/Turmeric', 'Especia con propiedades antiinflamatorias', true),
  ('FRITOS_PROCESADOS', 'Fritos y Procesados', 'Alimentos que aumentan la inflamación', true),
  ('ASTINGENTE', 'Astringente', 'Alimentos para diarrea (plátano, arroz, manzana, tostada)', true),
  ('SUAVE', 'Dieta suave', 'Fácil digestión, bajo en fibra', true),
  ('LACTEO_ASTRINGENTE', 'Lácteos astringentes', 'Yogur natural, queso fresco', true),
  ('FRUTA_ASTRINGENTE', 'Frutas astringentes', 'Manzana, pera, plátano maduro', true),
  ('HIDRATACION', 'Hidratación', 'Líquidos esenciales para recuperación', true),
  ('PROBIOTICO', 'Probiótico', 'Mejora la flora intestinal', true),
  ('ALTO_FIBRA', 'Alto en fibra', 'Ayuda contra estreñimiento', true),
  ('LÍQUIDOS_CLAROS', 'Líquidos claros', 'Consomé, agua, infusiones', true),
  ('FRACCIONADA', 'Dieta fraccionada', 'Comidas pequeñas frecuentes', true),
  ('ALTO_PROTEINA', 'Alto en proteína', 'Recuperación y crecimiento', true),
  ('BAJO_RESIDUOS', 'Bajo residuos', 'Fácil digestión para náuseas', true)
ON CONFLICT (codigo) DO UPDATE 
  SET nombre_visible = EXCLUDED.nombre_visible, 
      descripcion = EXCLUDED.descripcion,
      activo = EXCLUDED.activo;

-- =============================================
-- PASO 2: REGLAS PARA CONDICIONES CLÍNICAS (AIJ y LUPUS)
-- =============================================

-- 2.1. AIJ (ID 6) → ELIMINAR fritos y procesados
DO $$
DECLARE
    condicion_aIJ INTEGER := 6;
    subgrupo_fritos INTEGER;
    accion_eliminar INTEGER := 1;
    objetivo_subgrupo INTEGER := 2;
BEGIN
    SELECT id INTO subgrupo_fritos FROM nutricion.subgrupo_alimentario 
    WHERE nombre ILIKE '%fritos%' OR nombre ILIKE '%procesados%' LIMIT 1;
    
    IF subgrupo_fritos IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_eliminar, objetivo_subgrupo, subgrupo_fritos,
                'CLINICA',
                '[ALERTA] Paciente con AIJ: Eliminar alimentos fritos y ultraprocesados que aumentan la inflamación articular',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_aIJ
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%AIJ%' AND r.id_subgrupo_alimentario = subgrupo_fritos
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 2.2. AIJ (ID 6) → PRIORIZAR antiinflamatorios
DO $$
DECLARE
    condicion_aIJ INTEGER := 6;
    etiqueta_antiinf INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_antiinf FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ANTIINFLAMATORIO' LIMIT 1;
    
    IF etiqueta_antiinf IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_antiinf,
                'CLINICA',
                '[ATENCIÓN] Paciente con AIJ: Priorizar alimentos antiinflamatorios (Omega-3, cúrcuma, vegetales verdes)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_aIJ
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%antiinflamatorios%' AND r.id_etiqueta = etiqueta_antiinf
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 2.3. AIJ (ID 6) → PRIORIZAR Omega-3
DO $$
DECLARE
    condicion_aIJ INTEGER := 6;
    etiqueta_omega3 INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_omega3 FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'OMEGA3' LIMIT 1;
    
    IF etiqueta_omega3 IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_omega3,
                'CLINICA',
                '[ATENCIÓN] Paciente con AIJ: Aumentar ingesta de Omega-3 (pescado azul, nueces, chía)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_aIJ
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Omega-3%' AND r.id_etiqueta = etiqueta_omega3
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 2.4. LUPUS (ID 7) → PRIORIZAR antioxidantes y Omega-3
DO $$
DECLARE
    condicion_lupus INTEGER := 7;
    etiqueta_antiinf INTEGER;
    etiqueta_omega3 INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_antiinf FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ANTIINFLAMATORIO' LIMIT 1;
    
    SELECT id INTO etiqueta_omega3 FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'OMEGA3' LIMIT 1;
    
    -- Regla antioxidantes/antiinflamatorios
    IF etiqueta_antiinf IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_antiinf,
                'CLINICA',
                '[ATENCIÓN] Paciente con Lupus: Priorizar alimentos antioxidantes y antiinflamatorios (frutos rojos, vegetales verdes)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_lupus
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Lupus%' AND r.id_etiqueta = etiqueta_antiinf
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Regla Omega-3
    IF etiqueta_omega3 IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_omega3,
                'CLINICA',
                '[ATENCIÓN] Paciente con Lupus: Aumentar Omega-3 para reducir inflamación sistémica',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_lupus
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Lupus%' AND r.id_etiqueta = etiqueta_omega3
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- =============================================
-- PASO 3: REGLAS PARA CONDICIONES TEMPORALES (Gastrointestinales)
-- =============================================

-- 3.1. Diarrea Leve a Moderada (ID 9) → PRIORIZAR dieta BRAT (astringente)
DO $$
DECLARE
    condicion_diarrhea INTEGER := 9;
    etiqueta_astringente INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_astringente FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ASTINGENTE' LIMIT 1;
    
    IF etiqueta_astringente IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_astringente,
                'TEMPORAL',
                '[ATENCIÓN] Diarrea leve-moderada: Priorizar dieta astringente (plátano, arroz, manzana, tostada) por 24-72 horas',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_diarrhea
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Diarrea leve-moderada%' AND r.id_etiqueta = etiqueta_astringente
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 3.2. Diarrea Aguda (ID 16) → PRIORIZAR hidratación + astringente
DO $$
DECLARE
    condicion_diarrhea_aguda INTEGER := 16;
    etiqueta_hidratacion INTEGER;
    etiqueta_astringente INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_hidratacion FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'HIDRATACION' LIMIT 1;
    
    SELECT id INTO etiqueta_astringente FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ASTINGENTE' LIMIT 1;
    
    -- Hidratación
    IF etiqueta_hidratacion IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_hidratacion,
                'TEMPORAL',
                '[ALERTA] Diarrea aguda: Priorizar hidratación constante con suero oral o agua',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_diarrhea_aguda
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Diarrea aguda%' AND r.id_etiqueta = etiqueta_hidratacion
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Astringente
    IF etiqueta_astringente IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_astringente,
                'TEMPORAL',
                '[ATENCIÓN] Diarrea aguda: Dieta astringente BRAT (plátano, arroz, manzana, tostada)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_diarrhea_aguda
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Diarrea aguda%' AND r.id_etiqueta = etiqueta_astringente
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 3.3. Náuseas y Vómitos (ID 10, 17) → PRIORIZAR dieta fraccionada y suave
DO $$
DECLARE
    etiqueta_fraccionada INTEGER;
    etiqueta_suave INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_fraccionada FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'FRACCIONADA' LIMIT 1;
    
    SELECT id INTO etiqueta_suave FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'SUAVE' LIMIT 1;
    
    -- Para ambas condiciones 10 y 17
    FOR i IN 10, 17 LOOP
        -- Dieta fraccionada
        IF etiqueta_fraccionada IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_fraccionada,
                    'TEMPORAL',
                    '[ATENCIÓN] Náuseas y vómitos: Dieta fraccionada (6 comidas pequeñas) por 24-48 horas',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, i
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%Náuseas y vómitos%' AND r.id_etiqueta = etiqueta_fraccionada
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Dieta suave
        IF etiqueta_suave IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_suave,
                    'TEMPORAL',
                    '[ATENCIÓN] Náuseas y vómitos: Dieta suave, líquidos claros, evitar grasas',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, i
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%Náuseas y vómitos%' AND r.id_etiqueta = etiqueta_suave
            ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;
END $$;

-- 3.4. Estreñimiento Temporal (ID 18) → PRIORIZAR fibra y líquidos
DO $$
DECLARE
    condicion_estrenimiento INTEGER := 18;
    etiqueta_fibra INTEGER;
    etiqueta_hidratacion INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_fibra FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ALTO_FIBRA' LIMIT 1;
    
    SELECT id INTO etiqueta_hidratacion FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'HIDRATACION' LIMIT 1;
    
    -- Fibra
    IF etiqueta_fibra IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_fibra,
                'TEMPORAL',
                '[ATENCIÓN] Estreñimiento temporal: Aumentar fibra dietética (vegetales, frutas con cáscara, cereales integrales)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_estrenimiento
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Estreñimiento temporal%' AND r.id_etiqueta = etiqueta_fibra
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Hidratación
    IF etiqueta_hidratacion IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_hidratacion,
                'TEMPORAL',
                '[ATENCIÓN] Estreñimiento temporal: Aumentar ingesta de líquidos (2-2.5L agua diaria)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_estrenimiento
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Estreñimiento temporal%' AND r.id_etiqueta = etiqueta_hidratacion
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 3.5. Fiebre (ID 20) → PRIORIZAR hidratación
DO $$
DECLARE
    condicion_fiebre INTEGER := 20;
    etiqueta_hidratacion INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_hidratacion FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'HIDRATACION' LIMIT 1;
    
    IF etiqueta_hidratacion IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_hidratacion,
                'TEMPORAL',
                '[ALERTA] Fiebre: Priorizar hidratación constante para compensar pérdida de líquidos',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_fiebre
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Fiebre%' AND r.id_etiqueta = etiqueta_hidratacion
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 3.6. Falta de Apetito (ID 21) → PRIORIZAR proteína y fraccionada
DO $$
DECLARE
    condicion_apetito INTEGER := 21;
    etiqueta_proteina INTEGER;
    etiqueta_fraccionada INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_proteina FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ALTO_PROTEINA' LIMIT 1;
    
    SELECT id INTO etiqueta_fraccionada FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'FRACCIONADA' LIMIT 1;
    
    -- Proteína
    IF etiqueta_proteina IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_proteina,
                'TEMPORAL',
                '[ATENCIÓN] Falta de apetito: Priorizar alimentos densos en nutrientes y proteínas',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_apetito
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Falta de apetito%' AND r.id_etiqueta = etiqueta_proteina
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Fraccionada
    IF etiqueta_fraccionada IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_fraccionada,
                'TEMPORAL',
                '[ATENCIÓN] Falta de apetito: Comidas pequeñas y frecuentes (cada 2-3 horas)',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_apetito
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Falta de apetito%' AND r.id_etiqueta = etiqueta_fraccionada
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 3.7. Brote Articular/Crisis (ID 22) → ELIMINAR inflamatorios, PRIORIZAR antiinflamatorios
DO $$
DECLARE
    condicion_brote INTEGER := 22;
    subgrupo_fritos INTEGER;
    etiqueta_antiinf INTEGER;
    etiqueta_omega3 INTEGER;
    accion_eliminar INTEGER := 1;
    accion_priorizar INTEGER := 3;
    objetivo_subgrupo INTEGER := 2;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO subgrupo_fritos FROM nutricion.subgrupo_alimentario 
    WHERE nombre ILIKE '%fritos%' OR nombre ILIKE '%procesados%' LIMIT 1;
    
    SELECT id INTO etiqueta_antiinf FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ANTIINFLAMATORIO' LIMIT 1;
    
    SELECT id INTO etiqueta_omega3 FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'OMEGA3' LIMIT 1;
    
    -- ELIMINAR fritos
    IF subgrupo_fritos IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_eliminar, objetivo_subgrupo, subgrupo_fritos,
                'TEMPORAL',
                '[ALERTA] Brote articular: Eliminar fritos y procesados inmediatamente',
                true)  -- Estricta durante brote
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_brote
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Brote articular%' AND r.id_subgrupo_alimentario = subgrupo_fritos
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- PRIORIZAR antiinflamatorios
    IF etiqueta_antiinf IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_antiinf,
                'TEMPORAL',
                '[ALERTA] Brote articular: Priorizar intensamente alimentos antiinflamatorios',
                true)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_brote
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Brote articular%' AND r.id_etiqueta = etiqueta_antiinf
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- PRIORIZAR Omega-3
    IF etiqueta_omega3 IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_omega3,
                'TEMPORAL',
                '[ALERTA] Brote articular: Dosis extra de Omega-3 (2-3 porciones de pescado azul)',
                true)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_brote
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Brote articular%' AND r.id_etiqueta = etiqueta_omega3
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- =============================================
-- PASO 4: REGLAS PARA CONDICIONES NUTRICIONALES (Z-SCORE)
-- =============================================

-- 4.1. Desnutrición Severa (Z < -3: IDs 107, 23, 27) → AUMENTAR proteína
DO $$
DECLARE
    grupo_proteinas INTEGER;
    accion_aumentar INTEGER := 4;
    objetivo_grupo INTEGER := 3;
BEGIN
    SELECT id INTO grupo_proteinas FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%proteína%' OR nombre ILIKE '%carne%' OR nombre ILIKE '%huevo%' LIMIT 1;
    
    IF grupo_proteinas IS NOT NULL THEN
        FOR cond_id IN 107, 23, 27 LOOP
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_aumentar, objetivo_grupo, grupo_proteinas,
                    'NUTRICIONAL',
                    '[ALERTA] Desnutrición severa detectada (Z < -3): AUMENTAR ingesta proteica urgentemente para recuperar peso',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, cond_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%Desnutrición severa%' AND r.id_grupo_alimentario = grupo_proteinas
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;
END $$;

-- 4.2. Desnutrición Moderada (Z -3 a -2: IDs 24, 28, 106) → AUMENTAR proteína y calorías
DO $$
DECLARE
    grupo_proteinas INTEGER;
    grupo_carbohidratos INTEGER;
    accion_aumentar INTEGER := 4;
    objetivo_grupo INTEGER := 3;
BEGIN
    SELECT id INTO grupo_proteinas FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%proteína%' OR nombre ILIKE '%carne%' LIMIT 1;
    
    SELECT id INTO grupo_carbohidratos FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%carbohidrato%' OR nombre ILIKE '%cereal%' LIMIT 1;
    
    FOR cond_id IN 24, 28, 106 LOOP
        -- Aumentar proteína
        IF grupo_proteinas IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_aumentar, objetivo_grupo, grupo_proteinas,
                    'NUTRICIONAL',
                    '[ALERTA] Desnutrición detectada (Z -3 a -2): Aumentar ingesta de proteínas de alto valor biológico',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, cond_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%Desnutrición detectada%' AND r.id_grupo_alimentario = grupo_proteinas
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Aumentar carbohidratos (calorías)
        IF grupo_carbohidratos IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_aumentar, objetivo_grupo, grupo_carbohidratos,
                    'NUTRICIONAL',
                    '[ATENCIÓN] Desnutrición detectada: Aumentar carbohidratos complejos para ganancia de peso',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, cond_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%ganancia de peso%' AND r.id_grupo_alimentario = grupo_carbohidratos
            ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;
END $$;

-- 4.3. Normalidad (Z -2 a +1: IDs 103, 29) → PRIORIZAR fibra
DO $$
DECLARE
    etiqueta_fibra INTEGER;
    accion_priorizar INTEGER := 3;
    objetivo_etiqueta INTEGER := 4;
BEGIN
    SELECT id INTO etiqueta_fibra FROM nutricion.etiqueta_nutricional 
    WHERE codigo = 'ALTO_FIBRA' LIMIT 1;
    
    IF etiqueta_fibra IS NOT NULL THEN
        FOR cond_id IN 103, 29 LOOP
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_priorizar, objetivo_etiqueta, etiqueta_fibra,
                    'NUTRICIONAL',
                    '[NORMAL] Estado nutricional óptimo: Priorizar fibra para mantener salud digestiva',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, cond_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%nutricional óptimo%' AND r.id_etiqueta = etiqueta_fibra
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;
END $$;

-- 4.4. Sobrepeso (Z +1 a +2: ID 104) → DISMINUIR carbohidratos
DO $$
DECLARE
    condicion_sobrepeso INTEGER := 104;
    grupo_carbohidratos INTEGER;
    accion_disminuir INTEGER := 2;
    objetivo_grupo INTEGER := 3;
BEGIN
    SELECT id INTO grupo_carbohidratos FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%carbohidrato%' OR nombre ILIKE '%cereal%' LIMIT 1;
    
    IF grupo_carbohidratos IS NOT NULL THEN
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                      origen_regla, mensaje_error, es_estricta)
        VALUES (accion_disminuir, objetivo_grupo, grupo_carbohidratos,
                'NUTRICIONAL',
                '[ALERTA] Sobrepeso detectado (Z +1 a +2): DISMINUIR carbohidratos refinados, priorizar vegetales y fibra',
                false)
        ON CONFLICT DO NOTHING;
        
        INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
        SELECT r.id, condicion_sobrepeso
        FROM heuristico.regla r
        WHERE r.mensaje_error LIKE '%Sobrepeso detectado%' AND r.id_grupo_alimentario = grupo_carbohidratos
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- 4.5. Obesidad (Z > +2: IDs 30, 105) → DISMINUIR grasa y carbohidratos
DO $$
DECLARE
    grupo_carbohidratos INTEGER;
    grupo_grasas INTEGER;
    accion_disminuir INTEGER := 2;
    objetivo_grupo INTEGER := 3;
BEGIN
    SELECT id INTO grupo_carbohidratos FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%carbohidrato%' OR nombre ILIKE '%cereal%' LIMIT 1;
    
    SELECT id INTO grupo_grasas FROM nutricion.grupo_alimentario 
    WHERE nombre ILIKE '%grasa%' OR nombre ILIKE '%aceite%' LIMIT 1;
    
    FOR cond_id IN 30, 105 LOOP
        -- Disminuir carbohidratos
        IF grupo_carbohidratos IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_disminuir, objetivo_grupo, grupo_carbohidratos,
                    'NUTRICIONAL',
                    '[ALERTA] Obesidad detectada (Z > +2): DISMINUIR carbohidratos refinados y azúcares',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, cond_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%Obesidad detectada%' AND r.id_grupo_alimentario = grupo_carbohidratos
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Disminuir grasas
        IF grupo_grasas IS NOT NULL THEN
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, 
                                          origen_regla, mensaje_error, es_estricta)
            VALUES (accion_disminuir, objetivo_grupo, grupo_grasas,
                    'NUTRICIONAL',
                    '[ALERTA] Obesidad detectada: DISMINUIR grasas saturadas y trans',
                    false)
            ON CONFLICT DO NOTHING;
            
            INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
            SELECT r.id, cond_id
            FROM heuristico.regla r
            WHERE r.mensaje_error LIKE '%grasas saturadas%' AND r.id_grupo_alimentario = grupo_grasas
            ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;
END $$;

-- =============================================
-- PASO 5: VERIFICACIÓN FINAL
-- =============================================

SELECT '=== VERIFICACIÓN FINAL: TODAS LAS REGLAS CREADAS ===' as info;

SELECT 
    r.id,
    a.codigo as ACCIÓN,
    t.codigo as TIPO_OBJETIVO,
    CASE 
        WHEN r.id_ingrediente IS NOT NULL THEN 'Ingrediente'
        WHEN r.id_grupo_alimentario IS NOT NULL THEN 'Grupo'
        WHEN r.id_subgrupo_alimentario IS NOT NULL THEN 'Subgrupo'
        WHEN r.id_etiqueta IS NOT NULL THEN 'Etiqueta'
        WHEN r.id_receta IS NOT NULL THEN 'Receta'
        ELSE 'SIN OBJETIVO'
    END as TIPO,
    COALESCE(
        (SELECT nombre FROM nutricion.ingrediente WHERE id = r.id_ingrediente),
        (SELECT nombre FROM nutricion.grupo_alimentario WHERE id = r.id_grupo_alimentario),
        (SELECT nombre FROM nutricion.subgrupo_alimentario WHERE id = r.id_subgrupo_alimentario),
        (SELECT nombre_visible FROM nutricion.etiqueta_nutricional WHERE id = r.id_etiqueta),
        'N/A'
    ) as OBJETIVO,
    r.origen_regla as ORIGEN,
    c.nombre as CONDICIÓN
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
ORDER BY r.origen_regla, r.id;
