import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== VERIFICACIÓN DE REGLAS EN LA BASE DE DATOS ===\n")

# 1. Buscar tablas relacionadas con reglas
print("1. TABLAS DE REGLAS ENCONTRADAS:")
cur.execute("""
    SELECT table_schema, table_name 
    FROM information_schema.tables 
    WHERE table_name ILIKE '%regla%' 
    OR table_name ILIKE '%rule%'
    OR table_name ILIKE '%condicion%'
    OR table_name ILIKE '%enfermedad%'
    ORDER BY table_schema, table_name
""")
tables = cur.fetchall()
for t in tables:
    print(f"  {t['table_schema']}.{t['table_name']}")

# 2. Verificar si hay datos en las tablas principales de reglas
print("\n2. DATOS EN TABLAS DE REGLAS:")

# Verificar condiciones_clinicas
try:
    cur.execute("SELECT COUNT(*) as total FROM nutricion.condicion_clinica")
    count = cur.fetchone()['total']
    print(f"  nutricion.condicion_clinica: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre_visible FROM nutricion.condicion_clinica LIMIT 10")
        print("    Muestra:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre_visible']}")
except:
    print("  nutricion.condicion_clinica: NO EXISTE O ERROR")

# Verificar regla_clinica
try:
    cur.execute("SELECT COUNT(*) as total FROM nutricion.regla_clinica")
    count = cur.fetchone()['total']
    print(f"  nutricion.regla_clinica: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM nutricion.regla_clinica LIMIT 10")
        print("    Muestra:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except:
    print("  nutricion.regla_clinica: NO EXISTE O ERROR")

# Verificar regla_condicion (relación)
try:
    cur.execute("SELECT COUNT(*) as total FROM nutricion.regla_condicion")
    count = cur.fetchone()['total']
    print(f"  nutricion.regla_condicion: {count} registros")
except:
    print("  nutricion.regla_condicion: NO EXISTE O ERROR")

# Verificar accion_regla
try:
    cur.execute("SELECT COUNT(*) as total FROM nutricion.accion_regla")
    count = cur.fetchone()['total']
    print(f"  nutricion.accion_regla: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM nutricion.accion_regla")
        print("    Acciones disponibles:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except:
    print("  nutricion.accion_regla: NO EXISTE O ERROR")

# Verificar objetivo_regla
try:
    cur.execute("SELECT COUNT(*) as total FROM nutricion.objetivo_regla")
    count = cur.fetchone()['total']
    print(f"  nutricion.objetivo_regla: {count} registros")
    
    if count > 0:
        cur.execute("SELECT id, codigo, nombre FROM nutricion.objetivo_regla")
        print("    Objetivos disponibles:")
        for row in cur.fetchall():
            print(f"      {row['id']}: {row['codigo']} - {row['nombre']}")
except:
    print("  nutricion.objetivo_regla: NO EXISTE O ERROR")

# 3. Verificar si hay reglas ya configuradas para artritis o lupus
print("\n3. REGLAS PARA ARTRITIS/LUPUS:")
try:
    cur.execute("""
        SELECT rc.id, cc.codigo as condicion, r.codigo as regla, r.nombre
        FROM nutricion.regla_condicion rc
        JOIN nutricion.condicion_clinica cc ON cc.id = rc.id_condicion_clinica
        JOIN nutricion.regla_clinica r ON r.id = rc.id_regla_clinica
        WHERE cc.codigo ILIKE '%artritis%' OR cc.codigo ILIKE '%lupus%'
    """)
    rules = cur.fetchall()
    if rules:
        print(f"  Encontradas {len(rules)} reglas:")
        for row in rules:
            print(f"    {row['id']}: {row['condicion']} -> {row['regla']} ({row['nombre']})")
    else:
        print("  NO HAY reglas para artritis o lupus aún")
except Exception as e:
    print(f"  Error: {e}")

conn.close()

print("\n=== ESTADO FINAL ===")
print("Si las tablas están vacías, están limpias y listas para recibir datos reales.")
