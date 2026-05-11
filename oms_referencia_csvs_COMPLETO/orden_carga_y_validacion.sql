-- ORDEN DE CARGA EN SUPABASE
-- 1. Ejecuta crear_tablas_referencia.sql
-- 2. Importa los CSV en este orden:
--    fuente_referencia.csv
--    indicador_antropometrico.csv
--    oms_curva.csv
--    oms_curva_punto.csv
--    oms_curva_zscore.csv
--    oms_curva_percentil.csv
--    oms_clasificacion_zscore.csv
--    importacion_oms_log.csv

-- Validar conteo por curva:
SELECT c.codigo, c.indicador_codigo, c.sexo_codigo, c.unidad_edad, COUNT(p.id) total_puntos
FROM referencia.oms_curva c
LEFT JOIN referencia.oms_curva_punto p ON p.curva_id = c.id
GROUP BY c.codigo, c.indicador_codigo, c.sexo_codigo, c.unidad_edad
ORDER BY c.id;

-- Debe salir:
-- 1857 filas para cada curva diaria OMS 2006, BMI/HFA/WFA masculino y femenino
-- 168 filas para BMI/HFA 61-228 meses OMS 2007 por sexo
-- 60 filas para WFA 61-120 meses OMS 2007 por sexo
