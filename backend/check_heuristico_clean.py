import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== VERIFICACIÓN DE ESQUEMA HEURISTICO ===\n")

# 1. Listar todas las tablas en heuristico
print("1. TABLAS EN ESQUEMA HEURISTICO:")
cur.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'heuristico'
    ORDER BY table_name
""")
tables = cur.fetchall()
for t in tables:
    print(f"  {t['table_name']}")

# 2. Verificar datos en heuristico.regla
print("\n2. DATOS EN HEURISTICO.REGLA:")
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
count = cur.fetchone()['total']
print(f"  Total de registros: {count}")

if count > 0:
    print("  Muestra (primeros 5):")
    cur.execute("""
        SELECT id, id_accion, id_tipo_objetivo, 
               id_ingrediente, id_grupo_alimentario, id_etiqueta,
               es_estricta
        FROM heuristico.regla 
        LIMIT 5
    """)
    for row in cur.fetchall():
        print(f"    {row}")

# 3. Verificar datos en heuristico.condicion
print("\n3. DATOS EN HEURISTICO.CONDICION:")
cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion")
count = cur.fetchone()['total']
print(f"  Total de registros: {count}")

if count > 0:
    print("  Muestra (primeros 5):")
    cur.execute("""
        SELECT id, codigo, nombre, activa
        FROM heuristico.condicion 
        LIMIT 5
    """)
    for row in cur.fetchall():
        print(f"    {row}")

# 4. Verificar datos en heuristico.condicion_regla
print("\n4. DATOS EN HEURISTICO.CONDICION_REGLA:")
cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion_regla")
count = cur.fetchone()['total']
print(f"  Total de registros: {count}")

# 5. Buscar específicamente artritis o lupus
print("\n5. BÚSQUEDA DE ARTRITIS/LUPUS:")
cur.execute("""
    SELECT id, codigo, nombre 
    FROM heuristico.condicion 
    WHERE codigo ILIKE '%artritis%' OR codigo ILIKE '%lupus%'
       OR nombre ILIKE '%artritis%' OR nombre ILIKE '%lupus%'
""")
results = cur.fetchall()
if results:
    print(f"  Encontradas {len(results)} condiciones:")
    for row in results:
        print(f"    {row['id']}: {row['codigo']} - {row['nombre']}")
else:
    print("  NO HAY condiciones para artritis o lupus")

# 6. Ver catálogo objetivo regla
print("\n6. CATÁLOGO OBJETIVO REGLA:")
cur.execute("SELECT * FROM heuristico.catalogo_objetivo_regla ORDER BY id")
for row in cur.fetchall():
    print(f"  {row}")

# 7. Ver catálogo tipo condicion
print("\n7. CATÁLOGO TIPO CONDICION:")
cur.execute("SELECT * FROM heuristico.catalogo_tipo_condicion ORDER BY id")
for row in cur.fetchall():
    print(f"  {row}")

# 8. Ver posibles acciones (pueden estar en otra tabla o ser IDs directos)
print("\n8. VERIFICANDO ESTRUCTURA DE REGLA (acciones):")
cur.execute("""
    SELECT DISTINCT id_accion 
    FROM heuristico.regla 
    WHERE id_accion IS NOT NULL
""")
acciones = cur.fetchall()
if acciones:
    print(f"  Acciones únicas usadas: {[a['id_accion'] for a in acciones]}")
else:
    print("  No hay acciones definidas")

conn.close()

print("\n=== ESTADO FINAL ===")
print("Si no hay condiciones para artritis/lupus, debes crearlas.")
print("Las tablas parecen tener datos (106 reglas), pero hay que verificar si son 'reales' o basura.")
