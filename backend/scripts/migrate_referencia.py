import sys
import os
import csv
import io

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.db import get_pool

OMS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'oms'))
SCHEMA = "referencia"

CSV_FILES = [
    ("indicador_antropometrico", "indicador_antropometrico_rows (2).csv"),
    ("oms_curva", "oms_curva_rows (2).csv"),
    ("oms_curva_punto", "oms_curva_punto_rows (2).csv"),
    ("oms_curva_percentil", "oms_curva_percentil_rows (2).csv"),
]

CREATE_TABLES_SQL = f"""
CREATE SCHEMA IF NOT EXISTS {SCHEMA};

DROP TABLE IF EXISTS {SCHEMA}.oms_curva_percentil CASCADE;
DROP TABLE IF EXISTS {SCHEMA}.oms_curva_punto CASCADE;
DROP TABLE IF EXISTS {SCHEMA}.oms_curva CASCADE;
DROP TABLE IF EXISTS {SCHEMA}.indicador_antropometrico CASCADE;

CREATE TABLE {SCHEMA}.indicador_antropometrico (
    id INT PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    unidad_medida VARCHAR(20),
    edad_min_meses INT,
    edad_max_meses INT,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE {SCHEMA}.oms_curva (
    id INT PRIMARY KEY,
    codigo VARCHAR(100) UNIQUE NOT NULL,
    indicador_id INT REFERENCES {SCHEMA}.indicador_antropometrico(id),
    indicador_codigo VARCHAR(50),
    sexo_id INT,
    sexo_codigo VARCHAR(5),
    sexo_nombre VARCHAR(20),
    edad_min_meses INT,
    edad_max_meses INT,
    unidad_edad VARCHAR(20),
    fuente_zscore VARCHAR(255),
    fuente_percentil VARCHAR(255),
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE {SCHEMA}.oms_curva_punto (
    id SERIAL PRIMARY KEY,
    curva_id INT REFERENCES {SCHEMA}.oms_curva(id),
    indicador_codigo VARCHAR(50),
    sexo_codigo VARCHAR(5),
    edad_meses INT,
    l NUMERIC,
    m NUMERIC,
    s NUMERIC,
    stdev NUMERIC,
    sd5neg NUMERIC,
    sd4neg NUMERIC,
    sd3neg NUMERIC,
    sd2neg NUMERIC,
    sd1neg NUMERIC,
    sd0 NUMERIC,
    sd1 NUMERIC,
    sd2 NUMERIC,
    sd3 NUMERIC,
    sd4 NUMERIC
);

CREATE TABLE {SCHEMA}.oms_curva_percentil (
    id SERIAL PRIMARY KEY,
    curva_id INT REFERENCES {SCHEMA}.oms_curva(id),
    indicador_codigo VARCHAR(50),
    sexo_codigo VARCHAR(5),
    edad_meses INT,
    percentil_codigo VARCHAR(10),
    percentil NUMERIC,
    valor NUMERIC
);
"""

def csv_to_copy_data(csv_path):
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        output = io.StringIO()
        writer = csv.writer(output, lineterminator='\n')
        for row in reader:
            cleaned = ['\\N' if cell == '' else cell for cell in row]
            writer.writerow(cleaned)
        output.seek(0)
        return output, header

def migrate():
    print(f"Iniciando migración del esquema {SCHEMA}...")
    pool = get_pool()

    with pool.connection() as conn:
        with conn.cursor() as cur:
            print("Eliminando tablas antiguas y creando nuevas...")
            cur.execute(CREATE_TABLES_SQL)
            print("Tablas creadas exitosamente.")

            for table_name, csv_filename in CSV_FILES:
                csv_path = os.path.join(OMS_DIR, csv_filename)
                if not os.path.exists(csv_path):
                    print(f"  ! CSV no encontrado: {csv_path}")
                    continue

                print(f"Cargando {csv_filename} -> {SCHEMA}.{table_name}...")
                data, columns = csv_to_copy_data(csv_path)
                cols_sql = ", ".join(columns)
                copy_sql = f"COPY {SCHEMA}.{table_name} ({cols_sql}) FROM STDIN WITH CSV DELIMITER ',' NULL '\\N'"
                with cur.copy(copy_sql) as copy:
                    copy.write(data.read())
                print(f"  OK - {table_name}")

    print(f"Migración del esquema {SCHEMA} completada con éxito.")

if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"Error durante la migración: {e}")
        sys.exit(1)
