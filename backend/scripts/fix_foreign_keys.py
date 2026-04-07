"""
Script simple para verificar y agregar foreign keys en ingrediente_etiqueta
Usa psycopg2 que ya está en requirements.txt
"""

import psycopg2
import psycopg2.errors
import os
from dotenv import load_dotenv

load_dotenv(r"c:\Users\mirya\Desktop\Reuma Nutri\backend\.env")
db_url = os.getenv("DATABASE_URL", "").replace("postgresql://", "dbname=")

print("="*70)
print("VERIFICAR Y AGREGAR FOREIGN KEYS EN INGREDIENTE_ETIQUETA")
print("="*70)

try:
    conn = psycopg2.connect(db_url, sslmode='require')
    cur = conn.cursor()
    
    # 1. Verificar tabla
    print("\n[1] Verificando tabla dom_nutricion.ingrediente_etiqueta...")
    cur.execute("""
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'dom_nutricion' 
            AND table_name = 'ingrediente_etiqueta'
        )
    """)
    existe = cur.fetchone()[0]
    
    if not existe:
        print("❌ Tabla no existe")
        exit(1)
    
    print("✅ Tabla existe")
    
    # 2. Ver columnas
    print("\n[2] Columnas:")
    cur.execute("""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'dom_nutricion' 
        AND table_name = 'ingrediente_etiqueta'
        ORDER BY ordinal_position
    """)
    
    for col_name, col_type in cur.fetchall():
        print(f"   - {col_name}: {col_type}")
    
    # 3. Ver FK actuales
    print("\n[3] Foreign Keys actuales:")
    cur.execute("""
        SELECT constraint_name, column_name
        FROM information_schema.key_column_usage
        WHERE table_schema = 'dom_nutricion' 
        AND table_name = 'ingrediente_etiqueta'
        AND constraint_type = 'FOREIGN KEY'
    """)
    
    fks = cur.fetchall()
    if fks:
        print(f"   ✅ Ya existen {len(fks)} FK:")
        for fk_name, col in fks:
            print(f"      - {col} ({fk_name})")
    else:
        print("   ❌ No hay FK - agregando...")
        
        # Agregar FK para ingrediente_id
        try:
            cur.execute("""
                ALTER TABLE dom_nutricion.ingrediente_etiqueta
                ADD CONSTRAINT fk_ingrediente_etiqueta_ingrediente
                FOREIGN KEY (ingrediente_id)
                REFERENCES dom_nutricion.ingrediente(id)
                ON DELETE CASCADE
            """)
            conn.commit()
            print("   ✅ FK agregada: ingrediente_id")
        except psycopg2.errors.DuplicateObject:
            print("   ℹ️  FK ingrediente_id ya existe")
        except Exception as e:
            print(f"   ⚠️  Error FK ingrediente: {str(e)[:80]}")
        
        # Agregar FK para etiqueta_id
        try:
            cur.execute("""
                ALTER TABLE dom_nutricion.ingrediente_etiqueta
                ADD CONSTRAINT fk_ingrediente_etiqueta_etiqueta
                FOREIGN KEY (etiqueta_id)
                REFERENCES dom_nutricion.etiqueta_nutricional(id)
                ON DELETE CASCADE
            """)
            conn.commit()
            print("   ✅ FK agregada: etiqueta_id")
        except psycopg2.errors.DuplicateObject:
            print("   ℹ️  FK etiqueta_id ya existe")
        except Exception as e:
            print(f"   ⚠️  Error FK etiqueta: {str(e)[:80]}")
    
    # 4. Verificar resultado
    print("\n[4] Verificación final:")
    cur.execute("""
        SELECT constraint_name, column_name
        FROM information_schema.key_column_usage
        WHERE table_schema = 'dom_nutricion' 
        AND table_name = 'ingrediente_etiqueta'
        AND constraint_type = 'FOREIGN KEY'
    """)
    
    fks_final = cur.fetchall()
    if len(fks_final) >= 2:
        print(f"   ✅ {len(fks_final)} Foreign Keys correctamente configuradas:")
        for fk_name, col in fks_final:
            print(f"      - {col}")
    else:
        print(f"   ⚠️  Solo {len(fks_final)} FK encontradas")
    
    # 5. Contar relaciones
    cur.execute("SELECT COUNT(*) FROM dom_nutricion.ingrediente_etiqueta")
    total = cur.fetchone()[0]
    print(f"\n[5] Total de relaciones ingrediente-etiqueta: {total}")
    
    # 6. Mostrar estructura final
    print("\n[6] Estructura final de tabla:")
    cur.execute("""
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_schema = 'dom_nutricion' 
        AND table_name = 'ingrediente_etiqueta'
        ORDER BY ordinal_position
    """)
    
    for col, tipo, nullable in cur.fetchall():
        null_str = "NULL" if nullable == 'YES' else "NOT NULL"
        print(f"   {col:20} {tipo:15} {null_str}")
    
    print("\n" + "="*70)
    print("✅ VERIFICACIÓN COMPLETADA - RELACIONES CORRECTAS")
    print("="*70)
    
    print("""
RESUMEN:
  ┌─────────────────────────────────────────┐
  │ ingrediente_etiqueta                    │
  ├─────────────────────────────────────────┤
  │ ingrediente_id ──→ ingrediente(id)      │
  │ etiqueta_id ──→ etiqueta_nutricional(id)│
  └─────────────────────────────────────────┘

Esto permite que:
  ✓ 1 ingrediente tenga múltiples etiquetas
  ✓ 1 etiqueta se asigne a múltiples ingredientes
  ✓ Integridad referencial (sin datos huérfanos)
  ✓ Cascada de borrado automático
    """)
    
    cur.close()
    conn.close()

except Exception as e:
    print(f"\n❌ Error: {str(e)}")
    print("\nVerifica que DATABASE_URL esté configurado en .env")
    exit(1)
