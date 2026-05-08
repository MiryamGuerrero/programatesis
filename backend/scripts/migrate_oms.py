import sys
import os

# Añadir el path de la aplicación para poder importar app.core.db
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.db import db_cursor

def migrate():
    print("Iniciando migración del esquema OMS...")
    
    with db_cursor() as cur:
        # Crear esquema si no existe
        cur.execute("CREATE SCHEMA IF NOT EXISTS oms;")
        
        # Eliminar tablas existentes para asegurar coincidencia exacta con CSVs
        print("Eliminando tablas antiguas si existen...")
        cur.execute("DROP TABLE IF EXISTS oms.oms_curva_percentil CASCADE;")
        cur.execute("DROP TABLE IF EXISTS oms.oms_curva_punto CASCADE;")
        cur.execute("DROP TABLE IF EXISTS oms.oms_curva CASCADE;")
        cur.execute("DROP TABLE IF EXISTS oms.indicador_antropometrico CASCADE;")
        
        # 1. indicador_antropometrico
        print("Creando tabla oms.indicador_antropometrico...")
        cur.execute("""
            CREATE TABLE oms.indicador_antropometrico (
                id INT PRIMARY KEY,
                codigo VARCHAR(50) UNIQUE NOT NULL,
                nombre VARCHAR(100) NOT NULL,
                descripcion TEXT,
                unidad_medida VARCHAR(20),
                edad_min_meses INT,
                edad_max_meses INT,
                activo BOOLEAN DEFAULT TRUE
            );
        """)
        
        # 2. oms_curva
        print("Creando tabla oms.oms_curva...")
        cur.execute("""
            CREATE TABLE oms.oms_curva (
                id INT PRIMARY KEY,
                codigo VARCHAR(100) UNIQUE NOT NULL,
                indicador_id INT REFERENCES oms.indicador_antropometrico(id),
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
        """)
        
        # 3. oms_curva_punto
        print("Creando tabla oms.oms_curva_punto...")
        cur.execute("""
            CREATE TABLE oms.oms_curva_punto (
                id SERIAL PRIMARY KEY,
                curva_id INT REFERENCES oms.oms_curva(id),
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
        """)
        
        # 4. oms_curva_percentil
        print("Creando tabla oms.oms_curva_percentil...")
        cur.execute("""
            CREATE TABLE oms.oms_curva_percentil (
                id SERIAL PRIMARY KEY,
                curva_id INT REFERENCES oms.oms_curva(id),
                indicador_codigo VARCHAR(50),
                sexo_codigo VARCHAR(5),
                edad_meses INT,
                percentil_codigo VARCHAR(10),
                percentil NUMERIC,
                valor NUMERIC
            );
        """)
        
        print("Migración completada con éxito.")

if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"Error durante la migración: {e}")
        sys.exit(1)
