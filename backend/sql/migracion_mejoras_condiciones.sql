-- =============================================
-- MIGRACIÓN: MEJORA CATÁLOGO DE CONDICIONES
-- =============================================

-- 1. Añadir campo de duración sugerida a la tabla de catálogo
-- Este campo permitirá que el médico no tenga que calcular manualmente la fecha fin.
ALTER TABLE heuristico.condicion 
ADD COLUMN IF NOT EXISTS duracion_dias_sugerida INTEGER DEFAULT NULL;

-- 2. Comentario para claridad de la base de datos
COMMENT ON COLUMN heuristico.condicion.duracion_dias_sugerida IS 'Duración aproximada en días para condiciones temporales (Diarrea, Náuseas, etc).';

-- 3. Actualización de datos existentes (Ejemplos de condiciones temporales comunes)
-- Esto ayuda a que el sistema ya tenga inteligencia desde el día 1.
UPDATE heuristico.condicion SET duracion_dias_sugerida = 3 WHERE nombre ILIKE '%Diarrea%' AND id_tipo_condicion = 2;
UPDATE heuristico.condicion SET duracion_dias_sugerida = 2 WHERE nombre ILIKE '%Náuseas%' AND id_tipo_condicion = 2;
UPDATE heuristico.condicion SET duracion_dias_sugerida = 2 WHERE nombre ILIKE '%Vómito%' AND id_tipo_condicion = 2;
UPDATE heuristico.condicion SET duracion_dias_sugerida = 7 WHERE nombre ILIKE '%Brote%' AND id_tipo_condicion = 2;
UPDATE heuristico.condicion SET duracion_dias_sugerida = 5 WHERE nombre ILIKE '%Inflamación%' AND id_tipo_condicion = 2;
UPDATE heuristico.condicion SET duracion_dias_sugerida = 1 WHERE nombre ILIKE '%Fiebre%' AND id_tipo_condicion = 2;

-- 4. Verificación de la estructura de asignación
-- Aseguramos que la tabla donde se guardan las condiciones del paciente tenga lo necesario.
-- Si ya existe, no hará nada.
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='clinico' AND table_name='control_condicion_activa' AND column_name='fecha_fin') THEN
        ALTER TABLE clinico.control_condicion_activa ADD COLUMN fecha_fin DATE;
    END IF;
END $$;
