import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== VERIFICACIÓN DE REGLAS EXISTENTES ===\n")

# 1. Ver muestra de reglas existentes
print("1. MUESTRA DE REGLAS EXISTENTES (10 primeras):")
try:
    cur.execute("""
        SELECT r.id, o.codigo as objetivo_codigo, a.codigo as accion_codigo, 
               r.id_ingrediente, r.id_grupo_alimentario, r.id_etiqueta
        FROM heuristico.regla r
        LEFT JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
        LEFT JOIN heuristico.catalogo_accion_regla a ON a.id = r.id_accion
        LIMIT 10
    """)
    for row in cur.fetchall():
        # Determinar qué tipo de objetivo es
        objetivo = "???"
        if row['id_ingrediente']:
            objetivo = f"ING: {row['id_ingrediente']}"
        elif row['id_grupo_alimentario']:
            objetivo = f"GRUPO: {row['id_grupo_alimentario']}"
        elif row['id_etiqueta']:
            objetivo = f"ETIQUETA: {row['id_etiqueta']}"
        
        print(f"  {row['id']}: {objetivo} -> {row['accion_codigo']}")
except Exception as e:
    print(f"  Error: {e}")

# 2. Ver catálogo de acciones y objetivos
print("\n2. CATÁLOGO ACCIONES:")
try:
    cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_accion_regla ORDER BY id")
    for row in cur.fetchall():
        print(f"  {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  Error: {e}")

print("\n3. CATÁLOGO OBJETIVOS:")
try:
    cur.execute("SELECT id, codigo, nombre FROM heuristico.catalogo_objetivo_regla ORDER BY id")
    for row in cur.fetchall():
        print(f"  {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  Error: {e}")

# 4. Buscar condiciones de artritis/lupus
print("\n4. BÚSQUEDA DE CONDICIONES ARTRITIS/LUPUS:")
try:
    cur.execute("""
        SELECT id, nombre, codigo 
        FROM heuristico.condicion 
        WHERE nombre ILIKE '%artritis%' OR nombre ILIKE '%lupus%' 
           OR codigo ILIKE '%artritis%' OR codigo ILIKE '%lupus%'
    """)
    condiciones = cur.fetchall()
    if condiciones:
        print(f"  Encontradas {len(condiciones)} condiciones:")
        for row in condiciones:
            print(f"    {row['id']}: {row['codigo']} - {row['nombre']}")
    else:
        print("  NO HAY condiciones para artritis o lupus")
except Exception as e:
    print(f"  Error: {e}")

# 5. Ver todas las condiciones disponibles
print("\n5. TODAS LAS CONDICIONES DISPONIBLES:")
try:
    cur.execute("SELECT id, codigo, nombre FROM heuristico.condicion ORDER BY id")
    for row in cur.fetchall():
        print(f"  {row['id']}: {row['codigo']} - {row['nombre']}")
except Exception as e:
    print(f"  Error: {e}")

# 6. Ver si hay relación condicion-regla para artritis/lupus
print("\n6. RELACIÓN CONDICION-REGLA:")
try:
    cur.execute("""
        SELECT cr.id, c.codigo as condicion, r.id as regla_id,
               o.codigo as objetivo, a.codigo as accion
        FROM heuristico.condicion_regla cr
        JOIN heuristico.condicion c ON c.id = cr.id_condicion
        JOIN heuristico.regla r ON r.id = cr.id_regla
        LEFT JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
        LEFT JOIN heuristico.catalogo_accion_regla a ON a.id = r.id_accion
        WHERE c.codigo ILIKE '%artritis%' OR c.codigo ILIKE '%lupus%'
        LIMIT 10
    """)
    relaciones = cur.fetchall()
    if relaciones:
        print(f"  Encontradas {len(relaciones)} relaciones:")
        for row in relaciones:
            print(f"    {row['id']}: {row['condicion']} -> Regla {row['regla_id']} ({row['objetivo']} -> {row['accion']})")
    else:
        print("  NO HAY relaciones condicion-regla para artritis/lupus")
except Exception as e:
    print(f"  Error: {e}")

conn.close()

print("\n=== ESTADO FINAL ===")
print("Si no hay condiciones ni relaciones para artritis/lupus, hay que limpiar y crear desde cero.")
