-- =============================================
-- ELIMINAR TODAS LAS REGLAS Y CREAR NUEVAS COHERENTES
-- Basado en: heuristico.condicion + nutricion.* reales
-- =============================================

-- =============================================
-- PASO 1: ELIMINAR TODAS LAS REGLAS EXISTENTES
-- =============================================

-- Eliminar relaciones en condicion_regla
DELETE FROM heuristico.condicion_regla;

-- Eliminar TODAS las reglas
DELETE FROM heuristico.regla;

-- Reiniciar secuencia de IDs (opcional)
ALTER SEQUENCE IF EXISTS heuristico.regla_id_seq RESTART WITH 1;

SELECT '=== TODAS LAS REGLAS ELIMINADAS ===' as info;
SELECT 'Total reglas después de limpieza:', COUNT(*) FROM heuristico.regla;

-- =============================================
-- PASO 2: CREAR REGLAS PARA CONDICIONES CLÍNICAS
-- =============================================

-- 2.1. AIJ (ID 6) → ELIMINAR ultraprocesados (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    1, -- ELIMINAR
    4, -- ETIQUETA
    138, -- ULTRAPROCESADO
    'CLINICA',
    '[ALERTA] Paciente con AIJ: Eliminar alimentos ultraprocesados que aumentan la inflamación articular',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 6;

-- 2.2. AIJ (ID 6) → ELIMINAR altamente inflamatorio (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    1, -- ELIMINAR
    4, -- ETIQUETA
    78, -- ALTAMENTE_INFLAMATORIO
    'CLINICA',
    '[ALERTA] Paciente con AIJ: Eliminar alimentos altamente inflamatorios (fritos, embutidos)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 6;

-- 2.3. AIJ (ID 6) → PRIORIZAR antiinflamatorios (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    84, -- ANTIINFLAMATORIO
    'CLINICA',
    '[ATENCIÓN] Paciente con AIJ: Priorizar alimentos antiinflamatorios (vegetales verdes, frutos rojos)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 6;

-- 2.4. AIJ (ID 6) → PRIORIZAR Rico en Omega-3 (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    75, -- RICO_EN_OMEGA_3
    'CLINICA',
    '[ATENCIÓN] Paciente con AIJ: Priorizar alimentos ricos en Omega-3 (pescado azul, frutos secos)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 6;

-- 2.5. AIJ (ID 6) → PRIORIZAR pescado azul (SUBGRUPO)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_subgrupo_alimentario, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    2, -- SUBGRUPO
    33, -- Pescado azul
    'CLINICA',
    '[ATENCIÓN] Paciente con AIJ: Priorizar consumo de pescado azul (salmón, atún, sardinas) mínimo 3 veces/semana',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 6;

-- 2.6. LUPUS (ID 7) → PRIORIZAR antioxidantes (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    82, -- ALTO_PODER_ANTIOXIDANTE
    'CLINICA',
    '[ATENCIÓN] Paciente con Lupus: Priorizar alimentos con alto poder antioxidante (frutos rojos, cítricos)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 7;

-- 2.7. LUPUS (ID 7) → PRIORIZAR antiinflamatorios (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    84, -- ANTIINFLAMATORIO
    'CLINICA',
    '[ATENCIÓN] Paciente con Lupus: Priorizar alimentos antiinflamatorios para reducir brotes',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 7;

-- 2.8. LUPUS (ID 7) → ELIMINAR proinflamatorios (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    1, -- ELIMINAR
    4, -- ETIQUETA
    118, -- PROINFLAMATORIO
    'CLINICA',
    '[ALERTA] Paciente con Lupus: Eliminar alimentos proinflamatorios (azúcares refinados, grasas trans)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 7;

-- =============================================
-- PASO 3: CREAR REGLAS PARA CONDICIONES TEMPORALES
-- =============================================

-- 3.1. Diarrea Leve a Moderada (ID 9) → PRIORIZAR dieta astringente (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    146, -- DIETA_ASTRINGENTE
    'TEMPORAL',
    '[ATENCIÓN] Diarrea leve-moderada: Priorizar dieta astringente BRAT (plátano, arroz, manzana, tostada) por 24-72 horas',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 9;

-- 3.2. Diarrea Leve a Moderada (ID 9) → PRIORIZAR bajo en fibra (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    72, -- ALTA_FUENTE_DE_FIBRA (NEGATIVO: evitar fibra en diarrea)
    'TEMPORAL',
    '[ATENCIÓN] Diarrea leve-moderada: EVITAR alimentos altos en fibra temporalmente',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 9;

-- 3.3. Náuseas y Vómitos (ID 10) → PRIORIZAR dieta suave (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    137, -- DIETA_SUAVE
    'TEMPORAL',
    '[ATENCIÓN] Náuseas y vómitos: Priorizar dieta suave, líquidos claros, evitar grasas por 24-48 horas',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 10;

-- 3.4. Náuseas y Vómitos (ID 17) → PRIORIZAR dieta suave (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    137, -- DIETA_SUAVE
    'TEMPORAL',
    '[ATENCIÓN] Náuseas y vómitos (Gastrointestinal): Dieta suave fraccionada (6 comidas pequeñas)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 17;

-- 3.5. Gripe/Resfriado (ID 15) → PRIORIZAR alto en vitamina C (ETIQUETA - buscar)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    82, -- ALTO_PODER_ANTIOXIDANTE (usar como vitamina C)
    'TEMPORAL',
    '[ATENCIÓN] Gripe/Resfriado: Priorizar alimentos con alto poder antioxidante (cítricos, kiwi, pimiento)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 15;

-- 3.6. Diarrea Aguda (ID 16) → ELIMINAR alto en fibra (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    1, -- ELIMINAR
    4, -- ETIQUETA
    72, -- ALTA_FUENTE_DE_FIBRA
    'TEMPORAL',
    '[ALERTA] Diarrea aguda: ELIMINAR alimentos altos en fibra, lácteos y grasas',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 16;

-- 3.7. Diarrea Aguda (ID 16) → PRIORIZAR dieta astringente (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    146, -- DIETA_ASTRINGENTE
    'TEMPORAL',
    '[ALERTA] Diarrea aguda: Priorizar dieta astringente BRAT + hidratación con suero oral',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 16;

-- 3.8. Estreñimiento Temporal (ID 18) → PRIORIZAR alta fibra (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    72, -- ALTA_FUENTE_DE_FIBRA
    'TEMPORAL',
    '[ATENCIÓN] Estreñimiento temporal: Priorizar fibra dietética (vegetales, frutas con cáscara, cereales integrales)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 18;

-- 3.9. Estreñimiento Temporal (ID 18) → PRIORIZAR alto en magnesio (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    74, -- ALTA_FUENTE_DE_MAGNESIO
    'TEMPORAL',
    '[ATENCIÓN] Estreñimiento temporal: Priorizar alimentos ricos en magnesio (frutos secos, espinacas, aguacate)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 18;

-- 3.10. Infección de Garganta (ID 19) → PRIORIZAR dieta suave (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    137, -- DIETA_SUAVE
    'TEMPORAL',
    '[ATENCIÓN] Infección de garganta: Dieta suave, líquidos templados, evitar irritantes',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 19;

-- 3.11. Fiebre (ID 20) → PRIORIZAR equilibrio de líquidos (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    95, -- EQUILIBRIO_DE_L_QUIDOS_IDEAL
    'TEMPORAL',
    '[ALERTA] Fiebre: Priorizar hidratación constante (2.5-3L agua/día) para compensar pérdida de líquidos',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 20;

-- 3.12. Falta de Apetito (ID 21) → PRIORIZAR alta proteína (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    76, -- ALTA_FUENTE_DE_PROTE_NA
    'TEMPORAL',
    '[ATENCIÓN] Falta de apetito: Priorizar alimentos densos en nutrientes y proteínas de alto valor',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 21;

-- 3.13. Falta de Apetito (ID 21) → PRIORIZAR dieta fraccionada (usar etiqueta suave)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    137, -- DIETA_SUAVE (para fraccionada también)
    'TEMPORAL',
    '[ATENCIÓN] Falta de apetito: Comidas pequeñas y frecuentes (cada 2-3 horas)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 21;

-- 3.14. Brote Articular/Crisis (ID 22) → ELIMINAR altamente inflamatorio (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    1, -- ELIMINAR
    4, -- ETIQUETA
    78, -- ALTAMENTE_INFLAMATORIO
    'TEMPORAL',
    '[ALERTA] Brote articular: ELIMINAR inmediatamente alimentos altamente inflamatorios (fritos, embutidos, azúcares)',
    true  -- Estricta durante brote
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 22;

-- 3.15. Brote Articular/Crisis (ID 22) → PRIORIZAR antiinflamatorios (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    77, -- ALTAMENTE_ANTIINFLAMATORIO
    'TEMPORAL',
    '[ALERTA] Brote articular: Priorizar intensamente alimentos altamente antiinflamatorios (cúrcuma, jengibre, ajo)',
    true
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 22;

-- 3.16. Brote Articular/Crisis (ID 22) → PRIORIZAR Rico en Omega-3 (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    75, -- RICO_EN_OMEGA_3
    'TEMPORAL',
    '[ALERTA] Brote articular: Dosis extra de Omega-3 (2-3 porciones de pescado azul diarias)',
    true
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 22;

-- =============================================
-- PASO 4: CREAR REGLAS PARA CONDICIONES NUTRICIONALES (Z-SCORE)
-- =============================================

-- 4.1. Desnutrición Severa (IDs 23, 27, 107, 100) → AUMENTAR alta proteína (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    4, -- AUMENTAR
    4, -- ETIQUETA
    76, -- ALTA_FUENTE_DE_PROTE_NA
    'NUTRICIONAL',
    '[ALERTA] Desnutrición severa detectada (Z < -3): AUMENTAR ingesta de proteínas de alto valor biológico URGENTEMENTE',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 23
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 27
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 107
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 100;

-- 4.2. Desnutrición Severa → AUMENTAR alta fuente de hierro (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    4, -- AUMENTAR
    4, -- ETIQUETA
    73, -- ALTA_FUENTE_DE_HIERRO
    'NUTRICIONAL',
    '[ALERTA] Desnutrición severa: AUMENTAR ingesta de hierro (carnes rojas, legumbres, espinacas)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 23
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 27
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 107
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 100;

-- 4.3. Desnutrición Moderada (IDs 24, 28, 106, 101) → AUMENTAR proteínas (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    4, -- AUMENTAR
    4, -- ETIQUETA
    76, -- ALTA_FUENTE_DE_PROTE_NA
    'NUTRICIONAL',
    '[ALERTA] Desnutrición detectada (Z -3 a -2): AUMENTAR ingesta de proteínas para recuperar peso',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 24
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 28
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 106
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 101;

-- 4.4. Desnutrición Moderada → AUMENTAR grupo cereales (GRUPO)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_grupo_alimentario, origen_regla, mensaje_error, es_estricta)
VALUES (
    4, -- AUMENTAR
    3, -- GRUPO
    1, -- CEREALES
    'NUTRICIONAL',
    '[ATENCIÓN] Desnutrición: AUMENTAR carbohidratos complejos (cereales integrales) para ganancia de peso',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 24
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 28
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 106
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 101;

-- 4.5. Normalidad (IDs 29, 103, 25) → PRIORIZAR alta fibra (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    72, -- ALTA_FUENTE_DE_FIBRA
    'NUTRICIONAL',
    '[NORMAL] Estado nutricional óptimo: Priorizar alimentos altos en fibra para mantener salud digestiva',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 29
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 103
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 25;

-- 4.6. Normalidad → PRIORIZAR equilibrio de líquidos (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    95, -- EQUILIBRIO_DE_L_QUIDOS_IDEAL
    'NUTRICIONAL',
    '[NORMAL] Estado nutricional óptimo: Mantener equilibrio hídrico (2-2.5L agua/día)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 29
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 103
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 25;

-- 4.7. Sobrepeso (ID 104) → DISMINUIR alto en grasas (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    2, -- DISMINUIR
    4, -- ETIQUETA
    80, -- ALTO_EN_GRASAS
    'NUTRICIONAL',
    '[ALERTA] Sobrepeso detectado (Z +1 a +2): DISMINUIR alimentos altos en grasas saturadas y trans',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 104;

-- 4.8. Sobrepeso → DISMINUIR ultraprocesados (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    2, -- DISMINUIR
    4, -- ETIQUETA
    138, -- ULTRAPROCESADO
    'NUTRICIONAL',
    '[ALERTA] Sobrepeso: DISMINUIR ultraprocesados, azúcares añadidos y bebidas azucaradas',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 104;

-- 4.9. Obesidad (IDs 30, 105) → DISMINUIR alto en grasas (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    2, -- DISMINUIR
    4, -- ETIQUETA
    80, -- ALTO_EN_GRASAS
    'NUTRICIONAL',
    '[ALERTA] Obesidad detectada (Z > +2): DISMINUIR drásticamente grasas saturadas y trans',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 30
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 105;

-- 4.10. Obesidad → DISMINUIR alto en sodio (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    2, -- DISMINUIR
    4, -- ETIQUETA
    81, -- ALTO_EN_SODIO
    'NUTRICIONAL',
    '[ALERTA] Obesidad: DISMINUIR sodio para reducir retención de líquidos',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 30
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 105;

-- 4.11. Obesidad → PRIORIZAR bajo en grasas (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    90, -- BAJO_EN_GRASAS
    'NUTRICIONAL',
    '[ATENCIÓN] Obesidad: Priorizar alimentos bajos en grasas (pescado blanco, claras de huevo, vegetales)',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 30
UNION ALL
SELECT currval('heuristico.regla_id_seq'), 105;

-- 4.12. Riesgo de Desnutrición (ID 102) → AUMENTAR proteínas (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    4, -- AUMENTAR
    4, -- ETIQUETA
    76, -- ALTA_FUENTE_DE_PROTE_NA
    'NUTRICIONAL',
    '[ATENCIÓN] Riesgo de desnutrición: AUMENTAR ingesta proteica y calorías para prevenir pérdida de peso',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 102;

-- 4.13. Talla muy alta (ID 26) → PRIORIZAR alta fuente de calcio (ETIQUETA)
INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, origen_regla, mensaje_error, es_estricta)
VALUES (
    3, -- PRIORIZAR
    4, -- ETIQUETA
    71, -- ALTA_FUENTE_DE_CALCIO
    'NUTRICIONAL',
    '[ATENCIÓN] Talla muy alta para la edad: Priorizar calcio y vitamina D para salud ósea',
    false
);

INSERT INTO heuristico.condicion_regla (id_regla, id_condicion)
SELECT currval('heuristico.regla_id_seq'), 26;

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
    r.mensaje_error as MENSAJE,
    c.nombre as CONDICIÓN
FROM heuristico.regla r
JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
JOIN heuristico.catalogo_objetivo_regla t ON t.id = r.id_tipo_objetivo
LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
ORDER BY r.origen_regla, r.id;

-- Resumen
SELECT '=== RESUMEN ===' as info;
SELECT 'Total reglas creadas:' as concepto, COUNT(*) as valor FROM heuristico.regla
UNION ALL
SELECT 'Reglas CLÍNICAS:', COUNT(*) FROM heuristico.regla WHERE origen_regla = 'CLINICA'
UNION ALL
SELECT 'Reglas TEMPORALES:', COUNT(*) FROM heuristico.regla WHERE origen_regla = 'TEMPORAL'
UNION ALL
SELECT 'Reglas NUTRICIONALES:', COUNT(*) FROM heuristico.regla WHERE origen_regla = 'NUTRICIONAL'
UNION ALL
SELECT 'Total condiciones con reglas:', COUNT(DISTINCT cr.id_condicion) FROM heuristico.condicion_regla cr;
