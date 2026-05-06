import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== VERIFICACIÓN DE REGLAS (esquema heuristico) ===\n")

# 1. Estructura de las tablas principales
print("1. ESTRUCTURA DE TABLAS PRINCIPALES:")

tables_to_check = ['heuristico.regla', 'heuristico.condicion', 'heuristico.condicion_regla', 
                  'heuristico.catalogo_objetivo_regla', 'heuristico.catalogo_tipo_condicion']

for table in tables_to_check:
    try:
        # Obtener columnas
        schema, table_name = table.split('.')
        cur.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
        """, (schema, table_name))
        cols = cur.fetchall()
        print(f"\n  {table}:")
        for col in cols:
            print(f"    {col['column_name']}: {col['data_type']}")
    except Exception as e:
        print(f"\n  {table}: ERROR - {e}")

# 2. Verificar datos existentes
print("\n\n2. DATOS EXISTENTES:")

# Reglas
try:
    cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
    count = cur.fetchone()['total']
    print(f"  heuristico.regla: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM heuristico.regla LIMIT 10")
        print("    Muestra:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  heuristico.regla: ERROR - {e}")

# Condiciones
try:
    cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion")
    count = cur.fetchone()['total']
    print(f"  heuristico.condicion: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM heuristico.condicion LIMIT 10")
        print("    Muestra:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  heuristico.condicion: ERROR - {e}")

# Catálogo objetivo regla
try:
    cur.execute("SELECT COUNT(*) as total FROM heuristico.catalogo_objetivo_regla")
    count = cur.fetchone()['total']
    print(f"  heuristico.catalogo_objetivo_regla: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_objetivo_regla")
        print("    Objetivos disponibles:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  heuristico.catalogo_objetivo_regla: ERROR - {e}")

# Catálogo tipo condicion
try:
    cur.execute("SELECT COUNT(*) as total FROM heuristico.catalogo_tipo_condicion")
    count = cur.fetchone()['total']
    print(f"  heuristico.catalogo_tipo_condicion: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_tipo_condicion")
        print("    Tipos disponibles:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  heuristico.catalogo_tipo_condicion: ERROR - {e}")

# 3. Verificar si hay reglas para artritis o lupus
print("\n\n3. BÚSQUEDA DE ARTRITIS/LUPUS:")
try:
    cur.execute("""
        SELECT r.id, r.codigo, r.nombre, c.codigo as condicion
        FROM heuristico.regla r
        LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
        LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
        WHERE r.codigo ILIKE '%artritis%' OR r.codigo ILIKE '%lupus%' 
           OR c.codigo ILIKE '%artritis%' OR c.codigo ILIKE '%lupus%'
    """)
    results = cur.fetchall()
    if results:
        print(f"  Encontradas {len(results)} coincidencias:")
        for row in results:
            print(f"    {row['id']}: {row['codigo']} - {row['nombre']} (Condición: {row['condicion']})")
    else:
        print("  NO HAY reglas para artritis o lupus aún")
except Exception as e:
    print(f"  Error: {e}")

conn.close()

print("\n=== ESTADO FINAL ===")
print("Las tablas están en el esquema 'heuristico', no en 'nutricion'.")
print("Si no hay datos, están limpias y listas para recibir configuración real.")
