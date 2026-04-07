"""
Script para verificar y agregar foreign keys faltantes en ingrediente_etiqueta

Asegura que:
- ingrediente_id → FK a dom_nutricion.ingrediente(id)
- etiqueta_id → FK a dom_nutricion.etiqueta_nutricional(id)
"""

import psycopg
import os
from dotenv import load_dotenv

load_dotenv(r"c:\Users\mirya\Desktop\Reuma Nutri\backend\.env")
db_url = os.getenv("DATABASE_URL")

# SQL para verificar y agregar foreign keys si faltan
SQL_ARREGLAR_FK = """
-- 1. Verificar tabla existe
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'dom_nutricion' 
    AND table_name = 'ingrediente_etiqueta'
) as tabla_existe;
"""

SQL_COLUMNAS = """
-- 2. Verificar que tenemos los campos ingrediente_id y etiqueta_id
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'dom_nutricion' 
AND table_name = 'ingrediente_etiqueta'
ORDER BY ordinal_position;
"""

SQL_FK_ACTUAL = """
-- 3. Ver foreign keys actuales
SELECT constraint_name, column_name, referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'dom_nutricion' 
AND table_name = 'ingrediente_etiqueta'
AND column_name IN ('ingrediente_id', 'etiqueta_id');
"""

SQL_RECREAR_TABLA = """
-- ====== OPCIÓN: Recrear tabla con todas las restricciones si no están ======
-- (Ejecutar si las FK no existen)

-- Guardar datos
CREATE TEMP TABLE temp_ingrediente_etiqueta AS
SELECT * FROM dom_nutricion.ingrediente_etiqueta;

-- Dropear tabla original
DROP TABLE IF EXISTS dom_nutricion.ingrediente_etiqueta CASCADE;

-- Recrear con todas las restricciones
CREATE TABLE dom_nutricion.ingrediente_etiqueta (
    id SERIAL PRIMARY KEY,
    ingrediente_id INT NOT NULL,
    etiqueta_id INT NOT NULL,
    valor_etiqueta VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- ====== FOREIGN KEYS EXPLÍCITAS ======
    CONSTRAINT fk_ingrediente_etiqueta_ingrediente 
        FOREIGN KEY (ingrediente_id) 
        REFERENCES dom_nutricion.ingrediente(id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_ingrediente_etiqueta_etiqueta
        FOREIGN KEY (etiqueta_id)
        REFERENCES dom_nutricion.etiqueta_nutricional(id)
        ON DELETE CASCADE,
    
    -- ====== UNIQUE CONSTRAINT ======
    CONSTRAINT unique_ingrediente_etiqueta
        UNIQUE (ingrediente_id, etiqueta_id)
);

-- Restaurar datos
INSERT INTO dom_nutricion.ingrediente_etiqueta
SELECT * FROM temp_ingrediente_etiqueta;

-- Crear índices
CREATE INDEX idx_ingrediente_etiqueta_ing 
    ON dom_nutricion.ingrediente_etiqueta(ingrediente_id);

CREATE INDEX idx_ingrediente_etiqueta_etiq 
    ON dom_nutricion.ingrediente_etiqueta(etiqueta_id);

DROP TABLE temp_ingrediente_etiqueta;

-- Verificar resultado
SELECT COUNT(*) as total_relaciones FROM dom_nutricion.ingrediente_etiqueta;
"""

SQL_AGREGAR_FK_SIMPLE = """
-- ====== OPCIÓN SIMPLE: Agregar FK directamente si no existen ======
-- (Si la tabla ya existe y solo falta la FK)

-- Agregar FK para ingrediente_id si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'dom_nutricion'
        AND table_name = 'ingrediente_etiqueta'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%ingrediente%'
    ) THEN
        ALTER TABLE dom_nutricion.ingrediente_etiqueta
        ADD CONSTRAINT fk_ingrediente_etiqueta_ingrediente
        FOREIGN KEY (ingrediente_id)
        REFERENCES dom_nutricion.ingrediente(id)
        ON DELETE CASCADE;
        RAISE NOTICE 'Foreign key para ingrediente_id agregada';
    ELSE
        RAISE NOTICE 'Foreign key para ingrediente_id ya existe';
    END IF;
END $$;

-- Agregar FK para etiqueta_id si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = 'dom_nutricion'
        AND table_name = 'ingrediente_etiqueta'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%etiqueta%'
    ) THEN
        ALTER TABLE dom_nutricion.ingrediente_etiqueta
        ADD CONSTRAINT fk_ingrediente_etiqueta_etiqueta
        FOREIGN KEY (etiqueta_id)
        REFERENCES dom_nutricion.etiqueta_nutricional(id)
        ON DELETE CASCADE;
        RAISE NOTICE 'Foreign key para etiqueta_id agregada';
    ELSE
        RAISE NOTICE 'Foreign key para etiqueta_id ya existe';
    END IF;
END $$;

-- Verificar resultado
SELECT constraint_name, table_name, column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'dom_nutricion'
AND table_name = 'ingrediente_etiqueta';
"""

print("="*70)
print("VERIFICAR Y ARREGLAR FOREIGN KEYS EN INGREDIENTE_ETIQUETA")
print("="*70)

try:
    with psycopg.connect(db_url, sslmode='require') as conn:
        with conn.cursor() as cur:
            
            # 1. Verificar que tabla existe
            print("\n[1] Verificando tabla dom_nutricion.ingrediente_etiqueta...")
            cur.execute("""
                SELECT EXISTS (
                    SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = 'dom_nutricion' 
                    AND table_name = 'ingrediente_etiqueta'
                )
            """)
            existe = cur.fetchone()[0]
            
            if existe:
                print("✅ Tabla existe")
            else:
                print("❌ Tabla NO existe - es necesario crearla primero")
                exit(1)
            
            # 2. Verificar columnas
            print("\n[2] Columnas en la tabla:")
            cur.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_schema = 'dom_nutricion' 
                AND table_name = 'ingrediente_etiqueta'
                ORDER BY ordinal_position
            """)
            
            columnas = cur.fetchall()
            for col_name, col_type in columnas:
                print(f"   - {col_name}: {col_type}")
            
            # 3. Verificar foreign keys
            print("\n[3] Foreign Keys actuales:")
            cur.execute("""
                SELECT constraint_name, column_name, referenced_table_name, referenced_column_name
                FROM information_schema.key_column_usage
                WHERE table_schema = 'dom_nutricion' 
                AND table_name = 'ingrediente_etiqueta'
                AND constraint_type = 'FOREIGN KEY'
            """)
            
            fks = cur.fetchall()
            if fks:
                for fk_name, col, ref_table, ref_col in fks:
                    print(f"   ✅ {col} → {ref_table}({ref_col}) [{fk_name}]")
            else:
                print("   ❌ NO HAY FOREIGN KEYS - NECESITO AGREGARLAS")
            
            # ====== AGREGAR FK SI FALTAN ======
            
            fk_ingrediente_existe = any('ingrediente' in str(row[3]).lower() for row in fks if row)
            fk_etiqueta_existe = any('etiqueta' in str(row[3]).lower() for row in fks if row)
            
            if not fk_ingrediente_existe or not fk_etiqueta_existe:
                print("\n[4] Agregando foreign keys faltantes...")
                
                # FK para ingrediente_id
                if not fk_ingrediente_existe:
                    try:
                        cur.execute("""
                            ALTER TABLE dom_nutricion.ingrediente_etiqueta
                            ADD CONSTRAINT fk_ingrediente_etiqueta_ingrediente
                            FOREIGN KEY (ingrediente_id)
                            REFERENCES dom_nutricion.ingrediente(id)
                            ON DELETE CASCADE
                        """)
                        conn.commit()
                        print("   ✅ FK agregada: ingrediente_id → ingrediente(id)")
                    except Exception as e:
                        print(f"   ⚠️  FK ingrediente_id: {str(e)[:100]}")
                
                # FK para etiqueta_id
                if not fk_etiqueta_existe:
                    try:
                        cur.execute("""
                            ALTER TABLE dom_nutricion.ingrediente_etiqueta
                            ADD CONSTRAINT fk_ingrediente_etiqueta_etiqueta
                            FOREIGN KEY (etiqueta_id)
                            REFERENCES dom_nutricion.etiqueta_nutricional(id)
                            ON DELETE CASCADE
                        """)
                        conn.commit()
                        print("   ✅ FK agregada: etiqueta_id → etiqueta_nutricional(id)")
                    except Exception as e:
                        print(f"   ⚠️  FK etiqueta_id: {str(e)[:100]}")
            
            # 5. Verificar resultado final
            print("\n[5] Verificación final de Foreign Keys:")
            cur.execute("""
                SELECT constraint_name, column_name
                FROM information_schema.key_column_usage
                WHERE table_schema = 'dom_nutricion' 
                AND table_name = 'ingrediente_etiqueta'
                AND constraint_type = 'FOREIGN KEY'
            """)
            
            fks_final = cur.fetchall()
            if fks_final:
                for fk_name, col in fks_final:
                    print(f"   ✅ {col} -> {fk_name}")
            else:
                print("   ❌ Aún no hay FK")
            
            # 6. Contar relaciones
            print("\n[6] Estadísticas:")
            cur.execute("SELECT COUNT(*) FROM dom_nutricion.ingrediente_etiqueta")
            total = cur.fetchone()[0]
            print(f"   Total de relaciones ingrediente-etiqueta: {total}")
            
            # 7. Mostrar muestra
            cur.execute("""
                SELECT ie.id, ie.ingrediente_id, i.nombre, 
                       ie.etiqueta_id, e.nombre_categoria, ie.valor_etiqueta
                FROM dom_nutricion.ingrediente_etiqueta ie
                LEFT JOIN dom_nutricion.ingrediente i ON ie.ingrediente_id = i.id
                LEFT JOIN dom_nutricion.etiqueta_nutricional e ON ie.etiqueta_id = e.id
                LIMIT 5
            """)
            
            muestra = cur.fetchall()
            if muestra:
                print("\n   Primeras 5 relaciones:")
                for row in muestra:
                    print(f"   - {row[2]} ({row[1]}) -> {row[4]} ({row[3]})")
            
            print("\n" + "="*70)
            print("✅ VERIFICACIÓN COMPLETADA")
            print("="*70)
            
            print("""
NOTA: Las foreign keys conectan:
  - ingrediente_etiqueta.ingrediente_id → ingrediente.id
  - ingrediente_etiqueta.etiqueta_id → etiqueta_nutricional.id

Esto permite que:
  ✓ Cada ingrediente pueda tener múltiples etiquetas
  ✓ Al borrar un ingrediente se borren sus etiquetas
  ✓ Al borrar una etiqueta se eliminen las relaciones
  ✓ Integridad referencial garantizada en BD
            """)

except Exception as e:
    print(f"\n❌ Error: {str(e)}")
    print("\nVerifica que:")
    print("  1. La variable DATABASE_URL en .env está configurada")
    print("  2. Tienes acceso a la BD")
    print("  3. Las tablas ingrediente y etiqueta_nutricional existen")
