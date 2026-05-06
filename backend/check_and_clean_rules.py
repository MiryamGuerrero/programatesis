import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== VERIFICACIÓN Y LIMPIEZA DE REGLAS ===\n")

# 1. Ver estructura de todas las tablas del esquema heuristico
print("1. ESTRUCTURA DE TABLAS:")
tables = ['regla', 'condicion', 'condicion_regla', 'catalogo_accion', 
          'catalogo_objetivo_regla', 'catalogo_tipo_condicion']

for table in tables:
    try:
        cur.execute(f"""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = 'heuristico' AND table_name = '{table}'
            ORDER BY ordinal_position
        """)
        cols = cur.fetchall()
        print(f"\n  heuristico.{table}:")
        for col in cols:
            print(f"    {col['column_name']}: {col['data_type']}")
    except Exception as e:
        print(f"\n  heuristico.{table}: ERROR - {e}")

# 2. Ver datos existentes en condicion
print("\n\n2. DATOS EN HEURISTICO.CONDICION:")
try:
    cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion")
    count = cur.fetchone()['total']
    print(f"  Total: {count} registros")
    
    if count > 0:
        # Ver columnas disponibles
        cur.execute("SELECT * FROM heuristico.condicion LIMIT 3")
        rows = cur.fetchall()
        print("  Muestra:")
        for row in rows:
            print(f"    {row}")
except Exception as e:
    print(f"  Error: {e}")

# 3. Ver datos en regla
print("\n3. DATOS EN HEURISTICO.REGLA:")
try:
    cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
    count = cur.fetchone()['total']
    print(f"  Total: {count} registros")
    
    if count > 0:
        cur.execute("SELECT * FROM heuristico.regla LIMIT 3")
        rows = cur.fetchall()
        print("  Muestra:")
        for row in rows:
            print(f"    {row}")
except Exception as e:
    print(f"  Error: {e}")

# 4. Ver catálogos
print("\n4. CATÁLOGO ACCIONES:")
try:
    cur.execute("SELECT * FROM heuristico.catalogo_accion ORDER BY id")
    for row in cur.fetchall():
        print(f"  {row}")
except Exception as e:
    print(f"  Error: {e}")

print("\n5. CATÁLOGO OBJETIVOS:")
try:
    cur.execute("SELECT * FROM heuristico.catalogo_objetivo_regla ORDER BY id")
    for row in cur.fetchall():
        print(f"  {row}")
except Exception as e:
    print(f"  Error: {e}")

print("\n6. CATÁLOGO TIPO CONDICION:")
try:
    cur.execute("SELECT * FROM heuristico.catalogo_tipo_condicion ORDER BY id")
    for row in cur.fetchall():
        print(f"  {row}")
except Exception as e:
    print(f"  Error: {e}")

# 7. Buscar arthritis/lupus en condicion
print("\n7. BÚSQUEDA DE ARTRITIS/LUPUS:")
try:
    # Primero ver qué columnas tiene la tabla
    cur.execute("SELECT * FROM heuristico.condicion LIMIT 1")
    sample = cur.fetchone()
    if sample:
        columns = list(sample.keys())
        print(f"  Columnas disponibles: {columns}")
        
        # Buscar en las columnas de texto
        for col in columns:
            if 'nombre' in col.lower() or 'descripcion' in col.lower() or 'codigo' in col.lower():
                cur.execute(f"""
                    SELECT id, {col} 
                    FROM heuristico.condicion 
                    WHERE {col} ILIKE '%artritis%' OR {col} ILIKE '%lupus%'
                """)
                results = cur.fetchall()
                if results:
                    print(f"  En {col}:")
                    for row in results:
                        print(f"    {row}")
except Exception as e:
    print(f"  Error: {e}")

conn.close()

print("\n=== ESTADO ===")
print("Si hay datos 'falsos' o de prueba, hay que limpiar las tablas.")
print("Las tablas deben estar limpias para recibir datos reales.")
