-- Esquema limpio de referencia OMS para diagnóstico nutricional pediátrico
-- Motor recomendado: PostgreSQL
-- Importar primero condicion, oms_indicador y luego referencias/clasificaciones.

CREATE SCHEMA IF NOT EXISTS referencia;

CREATE TABLE IF NOT EXISTS referencia.condicion (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  tipo TEXT NOT NULL,
  edad_uso TEXT,
  grupo_diagnostico TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS referencia.oms_indicador (
  ref_code TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  estandar TEXT NOT NULL,
  edad_aplicable TEXT NOT NULL,
  clave_busqueda TEXT NOT NULL,
  variable_observada TEXT NOT NULL,
  uso_clinico TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS referencia.oms_referencia_zscore (
  id BIGSERIAL PRIMARY KEY,
  ref_code TEXT NOT NULL REFERENCES referencia.oms_indicador(ref_code),
  sexo CHAR(1) NOT NULL CHECK (sexo IN ('M','F')),
  edad_meses NUMERIC(8,3),
  edad_dias INTEGER,
  medida_cm NUMERIC(6,2),
  l NUMERIC(14,7) NOT NULL,
  m NUMERIC(14,7) NOT NULL,
  s NUMERIC(14,7) NOT NULL,
  stdev NUMERIC(14,7),
  sd5neg NUMERIC(14,3),
  sd4neg NUMERIC(14,3),
  sd3neg NUMERIC(14,3),
  sd2neg NUMERIC(14,3),
  sd1neg NUMERIC(14,3),
  sd0 NUMERIC(14,3),
  sd1 NUMERIC(14,3),
  sd2 NUMERIC(14,3),
  sd3 NUMERIC(14,3),
  sd4 NUMERIC(14,3),
  source_file TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS referencia.oms_referencia_percentil (
  id BIGSERIAL PRIMARY KEY,
  ref_code TEXT NOT NULL REFERENCES referencia.oms_indicador(ref_code),
  sexo CHAR(1) NOT NULL CHECK (sexo IN ('M','F')),
  edad_meses NUMERIC(8,3),
  edad_dias INTEGER,
  medida_cm NUMERIC(6,2),
  l NUMERIC(14,7) NOT NULL,
  m NUMERIC(14,7) NOT NULL,
  s NUMERIC(14,7) NOT NULL,
  stdev NUMERIC(14,7),
  p01 NUMERIC(14,3),
  p1 NUMERIC(14,3),
  p3 NUMERIC(14,3),
  p5 NUMERIC(14,3),
  p10 NUMERIC(14,3),
  p15 NUMERIC(14,3),
  p25 NUMERIC(14,3),
  p50 NUMERIC(14,3),
  p75 NUMERIC(14,3),
  p85 NUMERIC(14,3),
  p90 NUMERIC(14,3),
  p95 NUMERIC(14,3),
  p97 NUMERIC(14,3),
  p99 NUMERIC(14,3),
  p999 NUMERIC(14,3),
  source_file TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS referencia.oms_clasificacion_zscore (
  ref_code TEXT NOT NULL REFERENCES referencia.oms_indicador(ref_code),
  edad_meses_min INTEGER NOT NULL,
  edad_meses_max INTEGER NOT NULL,
  z_min NUMERIC(5,2),
  z_max NUMERIC(5,2),
  incluye_min BOOLEAN NOT NULL DEFAULT FALSE,
  incluye_max BOOLEAN NOT NULL DEFAULT FALSE,
  diagnostico TEXT NOT NULL,
  condicion_id INTEGER NOT NULL REFERENCES referencia.condicion(id),
  grupo_diagnostico TEXT NOT NULL,
  PRIMARY KEY (ref_code, edad_meses_min, edad_meses_max, diagnostico)
);

CREATE TABLE IF NOT EXISTS referencia.oms_fuente_archivo (
  source_file TEXT PRIMARY KEY,
  ref_code_detectado TEXT,
  tipo_tabla TEXT,
  sexo CHAR(1),
  usado_en_csv_limpio TEXT,
  filas_datos INTEGER,
  columnas INTEGER,
  primer_valor_clave TEXT,
  ultimo_valor_clave TEXT,
  sha256 TEXT,
  nota TEXT
);


CREATE UNIQUE INDEX IF NOT EXISTS uq_oms_zscore_ref_key
  ON referencia.oms_referencia_zscore(ref_code, sexo, COALESCE(edad_meses,-1), COALESCE(edad_dias,-1), COALESCE(medida_cm,-1));

CREATE UNIQUE INDEX IF NOT EXISTS uq_oms_percentil_ref_key
  ON referencia.oms_referencia_percentil(ref_code, sexo, COALESCE(edad_meses,-1), COALESCE(edad_dias,-1), COALESCE(medida_cm,-1));

CREATE INDEX IF NOT EXISTS idx_oms_zscore_lookup_medida
  ON referencia.oms_referencia_zscore(ref_code, sexo, medida_cm)
  WHERE medida_cm IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_oms_zscore_lookup_mes
  ON referencia.oms_referencia_zscore(ref_code, sexo, edad_meses)
  WHERE edad_meses IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_oms_zscore_lookup_dia
  ON referencia.oms_referencia_zscore(ref_code, sexo, edad_dias)
  WHERE edad_dias IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_oms_clasificacion_lookup
  ON referencia.oms_clasificacion_zscore(ref_code, edad_meses_min, edad_meses_max, grupo_diagnostico);

-- COPY sugerido desde psql, ejecutado en la carpeta donde están los CSV:
-- \copy referencia.condicion FROM 'condicion.csv' CSV HEADER ENCODING 'UTF8';
-- \copy referencia.oms_indicador FROM 'oms_indicador.csv' CSV HEADER ENCODING 'UTF8';
-- \copy referencia.oms_referencia_zscore(ref_code,sexo,edad_meses,edad_dias,medida_cm,l,m,s,stdev,sd5neg,sd4neg,sd3neg,sd2neg,sd1neg,sd0,sd1,sd2,sd3,sd4,source_file) FROM 'oms_referencia_zscore.csv' CSV HEADER ENCODING 'UTF8';
-- \copy referencia.oms_referencia_percentil(ref_code,sexo,edad_meses,edad_dias,medida_cm,l,m,s,stdev,p01,p1,p3,p5,p10,p15,p25,p50,p75,p85,p90,p95,p97,p99,p999,source_file) FROM 'oms_referencia_percentil.csv' CSV HEADER ENCODING 'UTF8';
-- \copy referencia.oms_clasificacion_zscore FROM 'oms_clasificacion_zscore.csv' CSV HEADER ENCODING 'UTF8';
-- \copy referencia.oms_fuente_archivo FROM 'oms_fuente_archivo.csv' CSV HEADER ENCODING 'UTF8';
