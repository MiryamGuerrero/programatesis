CREATE SCHEMA IF NOT EXISTS referencia;

DROP TABLE IF EXISTS referencia.oms_curva_percentil CASCADE;
DROP TABLE IF EXISTS referencia.oms_curva_zscore CASCADE;
DROP TABLE IF EXISTS referencia.oms_curva_punto CASCADE;
DROP TABLE IF EXISTS referencia.oms_curva CASCADE;
DROP TABLE IF EXISTS referencia.oms_clasificacion_zscore CASCADE;
DROP TABLE IF EXISTS referencia.importacion_oms_log CASCADE;
DROP TABLE IF EXISTS referencia.indicador_antropometrico CASCADE;
DROP TABLE IF EXISTS referencia.fuente_referencia CASCADE;

CREATE TABLE referencia.fuente_referencia (
  id BIGINT PRIMARY KEY,
  codigo VARCHAR(30) UNIQUE NOT NULL,
  nombre VARCHAR(180) NOT NULL,
  organismo VARCHAR(50) NOT NULL,
  anio INTEGER NOT NULL,
  descripcion TEXT,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE referencia.indicador_antropometrico (
  id BIGINT PRIMARY KEY,
  codigo VARCHAR(20) UNIQUE NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  descripcion TEXT,
  unidad_medida VARCHAR(20),
  edad_min_meses INTEGER NOT NULL,
  edad_max_meses INTEGER NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE referencia.oms_curva (
  id BIGINT PRIMARY KEY,
  codigo VARCHAR(80) UNIQUE NOT NULL,
  indicador_id BIGINT REFERENCES referencia.indicador_antropometrico(id),
  indicador_codigo VARCHAR(20) NOT NULL,
  sexo_id INTEGER NOT NULL,
  sexo_codigo CHAR(1) NOT NULL CHECK (sexo_codigo IN ('M','F')),
  sexo_nombre VARCHAR(20) NOT NULL,
  fuente_id BIGINT REFERENCES referencia.fuente_referencia(id),
  fuente_codigo VARCHAR(30),
  edad_min_meses INTEGER NOT NULL,
  edad_max_meses INTEGER NOT NULL,
  edad_min_dias INTEGER,
  edad_max_dias INTEGER,
  unidad_edad VARCHAR(10) NOT NULL CHECK (unidad_edad IN ('DIAS','MESES')),
  fuente_zscore TEXT,
  fuente_percentil TEXT,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  nota TEXT
);

CREATE TABLE referencia.oms_curva_punto (
  id BIGINT PRIMARY KEY,
  curva_id BIGINT NOT NULL REFERENCES referencia.oms_curva(id) ON DELETE CASCADE,
  indicador_codigo VARCHAR(20) NOT NULL,
  sexo_codigo CHAR(1) NOT NULL CHECK (sexo_codigo IN ('M','F')),
  edad_meses INTEGER,
  edad_dias INTEGER,
  l NUMERIC(14,8) NOT NULL,
  m NUMERIC(14,8) NOT NULL,
  s NUMERIC(14,8) NOT NULL,
  stdev NUMERIC(14,8),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_oms_punto_edad CHECK (edad_meses IS NOT NULL OR edad_dias IS NOT NULL),
  CONSTRAINT uq_oms_punto_mes UNIQUE (curva_id, edad_meses),
  CONSTRAINT uq_oms_punto_dia UNIQUE (curva_id, edad_dias)
);

CREATE TABLE referencia.oms_curva_zscore (
  id BIGINT PRIMARY KEY,
  punto_id BIGINT NOT NULL REFERENCES referencia.oms_curva_punto(id) ON DELETE CASCADE,
  sd5neg NUMERIC(14,6), sd4neg NUMERIC(14,6), sd3neg NUMERIC(14,6), sd2neg NUMERIC(14,6), sd1neg NUMERIC(14,6),
  sd0 NUMERIC(14,6), sd1 NUMERIC(14,6), sd2 NUMERIC(14,6), sd3 NUMERIC(14,6), sd4 NUMERIC(14,6),
  fuente_archivo TEXT,
  CONSTRAINT uq_oms_zscore_punto UNIQUE (punto_id)
);

CREATE TABLE referencia.oms_curva_percentil (
  id BIGINT PRIMARY KEY,
  punto_id BIGINT NOT NULL REFERENCES referencia.oms_curva_punto(id) ON DELETE CASCADE,
  p01 NUMERIC(14,6), p1 NUMERIC(14,6), p3 NUMERIC(14,6), p5 NUMERIC(14,6), p10 NUMERIC(14,6), p15 NUMERIC(14,6), p25 NUMERIC(14,6),
  p50 NUMERIC(14,6), p75 NUMERIC(14,6), p85 NUMERIC(14,6), p90 NUMERIC(14,6), p95 NUMERIC(14,6), p97 NUMERIC(14,6), p99 NUMERIC(14,6), p999 NUMERIC(14,6),
  fuente_archivo TEXT,
  CONSTRAINT uq_oms_percentil_punto UNIQUE (punto_id)
);

CREATE TABLE referencia.oms_clasificacion_zscore (
  id BIGINT PRIMARY KEY,
  indicador_codigo VARCHAR(20) NOT NULL,
  edad_min_meses INTEGER NOT NULL,
  edad_max_meses INTEGER NOT NULL,
  z_min NUMERIC(8,4),
  z_max NUMERIC(8,4),
  incluye_min BOOLEAN NOT NULL DEFAULT TRUE,
  incluye_max BOOLEAN NOT NULL DEFAULT FALSE,
  diagnostico VARCHAR(140) NOT NULL,
  severidad VARCHAR(50),
  orden INTEGER NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE referencia.importacion_oms_log (
  nombre_archivo TEXT,
  indicador_codigo VARCHAR(20),
  sexo_codigo VARCHAR(5),
  tipo_archivo VARCHAR(60),
  filas_leidas INTEGER,
  filas_insertadas INTEGER,
  estado VARCHAR(20),
  mensaje TEXT
);

CREATE INDEX idx_oms_punto_busqueda_dias ON referencia.oms_curva_punto(indicador_codigo, sexo_codigo, edad_dias);
CREATE INDEX idx_oms_punto_busqueda_meses ON referencia.oms_curva_punto(indicador_codigo, sexo_codigo, edad_meses);
CREATE INDEX idx_oms_curva_indicador_sexo ON referencia.oms_curva(indicador_codigo, sexo_codigo, unidad_edad, edad_min_meses, edad_max_meses);
