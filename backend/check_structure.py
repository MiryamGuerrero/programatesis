import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== ESTRUCTURA DE TABLAS CLAVE ===\n")

# 1. Estructura de ingrediente_nutriente
print("1. nutricion.ingrediente_nutriente:")
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_schema = 'nutricion' AND table_name = 'ingrediente_nutriente'
    ORDER BY ordinal_position
""")
for col in cur.fetchall():
    print(f"  {col['column_name']}: {col['data_type']}")

# 2. Ver algunos datos de ejemplo
print("\n2. Ejemplo de datos en ingrediente_nutriente:")
cur.execute("""
    SELECT * FROM nutricion.ingrediente_nutriente LIMIT 5
""")
for row in cur.fetchall():
    print(f"  {row}")

# 3. Nutrientes disponibles
print("\n3. Nutrientes disponibles en la base:")
cur.execute("""
    SELECT id, nombre FROM nutricion.nutriente ORDER BY id
""")
for row in cur.fetchall():
    print(f"  {row['id']}: {row['nombre']}")

conn.close()
