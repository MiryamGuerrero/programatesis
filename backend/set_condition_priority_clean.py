import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== CONFIGURANDO JERARQUIA DE CONDICIONES ===\n")

# 1. Ver estado actual de orden_oms
print("1. ESTADO ACTUAL DE orden_oms:")
cur.execute("""
    SELECT c.id, c.nombre, tc.nombre as tipo, c.orden_oms
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    ORDER BY tc.id, c.orden_oms
""")
for row in cur.fetchall():
    print(f"   {row['id']:3} [{row['tipo']:12}] {row['nombre']:40} orden_oms: {row['orden_oms']}")

# 2. Asignar prioridades claras
print("\n2. ASIGNANDO PRIORIDADES:")

# CLÍNICAS: Prioridad 1 (MÁXIMA)
clinical_conditions = [6, 7]  # Artritis, Lupus
cur.execute("""
    UPDATE heuristico.condicion 
    SET orden_oms = 1 
    WHERE id = ANY(%s)
""", (clinical_conditions,))
print("   [OK] CLÍNICAS (Artritis, Lupus): orden_oms = 1 (MÁXIMA prioridad)")

# TEMPORALES: Prioridad 3 (MÍNIMA)
cur.execute("""
    UPDATE heuristico.condicion 
    SET orden_oms = 3 
    WHERE id_tipo_condicion = 2
""")
print("   [OK] TEMPORALES (Náuseas, Diarrea): orden_oms = 3 (MÍNIMA prioridad) ")

# NUTRICIONALES: Prioridad 2 (MEDIA)
cur.execute("""
    UPDATE heuristico.condicion 
    SET orden_oms = 2 
    WHERE id_tipo_condicion = 3
""")
print("   [OK] NUTRICIONALES (Bajo peso, Obesidad): orden_oms = 2 (MEDIA prioridad) ")

conn.commit()

# 3. Verificar resultado
print("\n3. VERIFICACIÓN FINAL:")
cur.execute("""
    SELECT c.id, c.nombre, tc.nombre as tipo, c.orden_oms
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    ORDER BY c.orden_oms, tc.id
""")
for row in cur.fetchall():
    priority = "[MAXIMA]" if row['orden_oms'] == 1 else "[MEDIA]" if row['orden_oms'] == 2 else "[MINIMA]"
    print(f"   {row['id']:3} {priority} [{row['tipo']:12}] {row['nombre']}")

# 4. Mostrar cómo se aplicarían las reglas (ejemplo)
print("\n4. EJEMPLO DE RESOLUCIÓN (Artritis + Bajo peso):")
print("""
   PACIENTE con: Artritis Idiopática Juvenil (CLÍNICA, orden_oms=1) + Bajo peso (NUTRICIONAL, orden_oms=2)
   
   PASO 1: Aplicar reglas CLÍNICAS (orden_oms=1) primero:
      - PRIORIZAR omega 3 (Artritis)
      - PRIORIZAR fibra (Artritis)
   
   PASO 2: Aplicar reglas NUTRICIONALES (orden_oms=2) después:
      - Si NUTRICIONAL dice ELIMINAR omega 3 → SE IGNORA (Artritis ganó, orden menor)
      - Si NUTRICIONAL dice PRIORIZAR proteína → SE APLICA (no hay choque)
   
   RESULTADO: CLÍNICA > NUTRICIONAL (por orden_oms)
""")

conn.close()

print("=== CONFIGURACIÓN COMPLETADA ===")
print("Ahora tu motor debe procesar reglas en orden de 'orden_oms' (1, 2, 3).")
print("Si hay choque en MISMA etiqueta: GANA la de MENOR orden_oms (CLÍNICA).")
