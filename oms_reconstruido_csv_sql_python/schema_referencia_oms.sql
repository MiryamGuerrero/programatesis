CREATE TABLE referencia.indicador_antropometrico (
    id smallint PRIMARY KEY,
    codigo varchar(10) UNIQUE NOT NULL,
    nombre varchar(120) NOT NULL,
    descripcion text,
    unidad_medida varchar(20),
    edad_min_meses smallint NOT NULL,
    edad_max_meses smallint NOT NULL,
    activo boolean NOT NULL DEFAULT true
);

CREATE TABLE referencia.condicion_nutricional (
    id smallint PRIMARY KEY,
    indicador_codigo varchar(10) NOT NULL REFERENCES referencia.indicador_antropometrico(codigo),
    codigo varchar(40) NOT NULL,
    nombre varchar(120) NOT NULL,
    z_min numeric(6,2),
    z_max numeric(6,2),
    incluye_min boolean NOT NULL DEFAULT false,
    incluye_max boolean NOT NULL DEFAULT false,
    orden smallint NOT NULL,
    descripcion text,
    UNIQUE (indicador_codigo, codigo)
);

CREATE TABLE referencia.oms_curva (
    id smallint PRIMARY KEY,
    codigo varchar(40) UNIQUE NOT NULL,
    indicador_id smallint NOT NULL REFERENCES referencia.indicador_antropometrico(id),
    indicador_codigo varchar(10) NOT NULL REFERENCES referencia.indicador_antropometrico(codigo),
    sexo_id smallint NOT NULL,
    sexo_codigo char(1) NOT NULL CHECK (sexo_codigo IN ('M','F')),
    sexo_nombre varchar(20) NOT NULL,
    edad_min_meses smallint NOT NULL,
    edad_max_meses smallint NOT NULL,
    unidad_edad varchar(10) NOT NULL DEFAULT 'MESES',
    fuente_zscore varchar(160),
    fuente_percentil varchar(160),
    activo boolean NOT NULL DEFAULT true
);

CREATE TABLE referencia.oms_curva_punto (
    id integer PRIMARY KEY,
    curva_id smallint NOT NULL REFERENCES referencia.oms_curva(id),
    indicador_codigo varchar(10) NOT NULL,
    sexo_codigo char(1) NOT NULL CHECK (sexo_codigo IN ('M','F')),
    edad_meses smallint NOT NULL CHECK (edad_meses BETWEEN 61 AND 228),
    l numeric(12,6) NOT NULL,
    m numeric(12,6) NOT NULL,
    s numeric(12,6) NOT NULL,
    stdev numeric(12,6),
    sd5neg numeric(12,3),
    sd4neg numeric(12,3),
    sd3neg numeric(12,3),
    sd2neg numeric(12,3),
    sd1neg numeric(12,3),
    sd0 numeric(12,3),
    sd1 numeric(12,3),
    sd2 numeric(12,3),
    sd3 numeric(12,3),
    sd4 numeric(12,3),
    UNIQUE (curva_id, edad_meses)
);

CREATE TABLE referencia.oms_curva_percentil (
    id integer PRIMARY KEY,
    curva_id smallint NOT NULL REFERENCES referencia.oms_curva(id),
    indicador_codigo varchar(10) NOT NULL,
    sexo_codigo char(1) NOT NULL CHECK (sexo_codigo IN ('M','F')),
    edad_meses smallint NOT NULL CHECK (edad_meses BETWEEN 61 AND 228),
    percentil_codigo varchar(8) NOT NULL,
    percentil numeric(5,1) NOT NULL,
    valor numeric(12,3) NOT NULL,
    UNIQUE (curva_id, edad_meses, percentil_codigo)
);

CREATE INDEX idx_oms_punto_busqueda 
ON referencia.oms_curva_punto (indicador_codigo, sexo_codigo, edad_meses);

CREATE INDEX idx_condicion_nutricional_indicador
ON referencia.condicion_nutricional (indicador_codigo, orden);
