import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== CONDICIONES TEMPORALES ===\n")

# Obtener todas las condiciones de tipo TEMPORAL
cur.execute("""
    SELECT c.id, c.nombre, c.descripcion, c.activa, 
           c.dias_duracion_estandar, c.indicador_codigo
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    WHERE tc.codigo = 'TEMPORAL'
    ORDER BY c.id
""")
condiciones = cur.fetchall()

if not condiciones:
    print("No se encontraron condiciones temporales.")
else:
    print(f"Total: {len(condiciones)} condiciones temporales\n")
    
    for row in condiciones:
        estado = "ACTIVA" if row['activa'] else "INACTIVA"
        duracion = row['dias_duracion_estandar'] if row['dias_duracion_estandar'] else "N/A"
        indicador = row['indicador_codigo'] if row['indicador_codigo'] else "N/A"
        
        print(f"ID: {row['id']}")
        print(f"  Nombre: {row['nombre']}")
        print(f"  Estado: {estado}")
        print(f"  Duracion estandar: {duracion} dias")
        print(f"  Indicador: {indicador}")
        if row['descripcion']:
            print(f"  Descripcion: {row['descripcion'][:100]}...")
        print()

# Verificar si tienen reglas asociadas
print("=== REGLAS ASOCIADAS ===\n")
for row in condiciones:
    cur.execute("""
        SELECT COUNT(*) as total 
        FROM heuristico.condicion_regla 
        WHERE id_condicion = %s
    """, (row['id'],))
    num_reglas = cur.fetchone()['total']
    
    status = "OK - tiene reglas" if num_reglas > 0 else "VACIA - sin reglas"
    print(f"  {row['id']}: {row['nombre']:40} | {num_reglas} reglas | {status}")

conn.close()

print("\n=== LISTA COMPLETADA ===")
