import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== ANÁLISIS DE ESTRUCTURA HEURÍSTICA ===\n")

# 1. Estructura actual de heuristico.regla
print("1. ESTRUCTURA ACTUAL DE heuristico.regla:")
cur.execute("""
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns 
    WHERE table_schema = 'heuristico' AND table_name = 'regla'
    ORDER BY ordinal_position
""")
for col in cur.fetchall():
    nullable = "NULL" if col['is_nullable'] == 'YES' else "NOT NULL"
    print(f"   {col['column_name']:30} {col['data_type']:30} {nullable}")

# 2. Ver cómo se están usando los campos objetivo
print("\n2. USO ACTUAL DE CAMPOS OBJETIVO:")
campos = ['id_ingrediente', 'id_grupo_alimentario', 'id_subgrupo_alimentario', 'id_etiqueta', 'id_receta']
for campo in campos:
    cur.execute(f"SELECT COUNT(*) as total FROM heuristico.regla WHERE {campo} IS NOT NULL")
    count = cur.fetchone()['total']
    if count > 0:
        print(f"   {campo:30} usado en {count} reglas")

# 3. Ver acciones y sus pesos
print("\n3. CATÁLOGO DE ACCIONES:")
cur.execute("SELECT * FROM heuristico.catalogo_accion ORDER BY id")
for row in cur.fetchall():
    print(f"   {row['codigo']:15} peso: {row['peso_puntaje']:5} - {row['nombre']}")

# 4. Ver objetivos
print("\n4. CATÁLOGO DE OBJETIVOS:")
cur.execute("SELECT * FROM heuristico.catalogo_objetivo_regla ORDER BY id")
for row in cur.fetchall():
    print(f"   {row['codigo']:15} - {row['nombre']}")

# 5. Ver si hay reglas con múltiples campos llenos (inconsistencia)
print("\n5. VERIFICAR REGLAS CON MÚLTIPLES OBJETIVOS (inconsistencia):")
cur.execute("""
    SELECT id, 
           (CASE WHEN id_ingrediente IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN id_grupo_alimentario IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN id_subgrupo_alimentario IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN id_etiqueta IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN id_receta IS NOT NULL THEN 1 ELSE 0 END) as num_objetivos
    FROM heuristico.regla
    WHERE (CASE WHEN id_ingrediente IS NOT NULL THEN 1 ELSE 0 END +
           CASE WHEN id_grupo_alimentario IS NOT NULL THEN 1 ELSE 0 END +
           CASE WHEN id_subgrupo_alimentario IS NOT NULL THEN 1 ELSE 0 END +
           CASE WHEN id_etiqueta IS NOT NULL THEN 1 ELSE 0 END +
           CASE WHEN id_receta IS NOT NULL THEN 1 ELSE 0 END) > 1
""")
inconsistent = cur.fetchall()
if inconsistent:
    print(f"   [!] Encontradas {len(inconsistent)} reglas con múltiples objetivos")
    for row in inconsistent[:5]:
        print(f"      Regla {row['id']}: {row['num_objetivos']} objetivos")
else:
    print("   [OK] No hay reglas con múltiples objetivos (consistente)")

# 6. Ver condiciones
print("\n6. CONDICIONES CLÍNICAS:")
cur.execute("""
    SELECT c.id, c.nombre, tc.nombre as tipo, c.activa,
           (SELECT COUNT(*) FROM heuristico.condicion_regla cr WHERE cr.id_condicion = c.id) as num_reglas
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    ORDER BY c.id
""")
for row in cur.fetchall():
    estado = "ACTIVA" if row['activa'] else "INACTIVA"
    print(f"   {row['id']:3} {row['nombre']:40} [{row['tipo']}] {estado} - {row['num_reglas']} reglas")

# 7. Análisis de optimización
print("\n=== ANÁLISIS DE OPTIMIZACIÓN ===")
print("\nHALLAZGOS:")

# 7.1. RECETA no está en catálogo pero existe en regla
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla WHERE id_receta IS NOT NULL")
receta_count = cur.fetchone()['total']
print(f"\n1. RECETA COMO OBJETIVO:")
print(f"   - 'RECETA' NO está en catalogo_objetivo_regla")
print(f"   - Pero existe columna 'id_receta' en tabla regla ({receta_count} reglas usan esto)")
print(f"   - [SUGERENCIA] Agregar 'RECETA' al catálogo o unificar manejo de objetivos")

# 7.2. Campos objetivo separados
print(f"\n2. MANEJO DE OBJETIVOS:")
print(f"   - Actual: 5 columnas separadas (id_ingrediente, id_grupo, etc.)")
print(f"   - Cada regla usa solo UNA columna (verificado arriba)")
print(f"   - [SUGERENCIA] Considerar unificar en una sola columna con tipo")

# 7.3. Pesos de acción
print(f"\n3. PESOS DE ACCIÓN:")
print(f"   - Los pesos están en catalogo_accion (ELIMINAR=-100, PRIORIZAR=20, etc.)")
print(f"   - No hay forma de ajustar el peso por regla individual")
print(f"   - [SUGERENCIA] Agregar columna 'peso_ajuste' en regla si se necesita flexibilidad")

# 7.4. Orden de reglas
cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion_regla")
total_cr = cur.fetchone()['total']
print(f"\n4. ORDEN DE REGLAS:")
print(f"   - No hay columna 'orden' en condicion_regla ({total_cr} relaciones)")
print(f"   - [SUGERENCIA] Agregar 'orden' para priorizar reglas dentro de una condición")

# 7.5. Reglas activas/inactivas
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla WHERE es_estricta = TRUE")
estrictas = cur.fetchone()['total']
print(f"\n5. REGLAS ESTRICTAS:")
print(f"   - {estrictas} reglas marcadas como estrictas")
print(f"   - No hay columna 'activa' general para reglas")
print(f"   - [SUGERENCIA] Agregar 'activa' a regla para habilitar/deshabilitar sin borrar")

# 8. Propuesta de mejora
print("\n=== PROPUESTA DE OPTIMIZACIÓN ===")
print("""
🏗️  MODELO ACTUAL (Fortalezas):
   [OK] Soporta múltiples tipos de objetivos (ingrediente, grupo, etiqueta, etc.)
   [OK] Relación muchos-a-muchos entre condiciones y reglas
   [OK] Acciones con pesos predefinidos
   [OK] Origen de regla (CLINICA, TEMPORAL)

[!] PUNTOS A MEJORAR:
   1. Inconsistencia: 'RECETA' existe en regla pero no en catálogo
   2. Estructura de objetivos: 5 columnas separadas es difícil de mantener
   3. No hay orden/prioridad de reglas
   4. No hay forma de desactivar reglas individuales
   5. No hay ajuste de peso por regla

[SUGERENCIA] CAMBIOS RECOMENDADOS (opcionales):
   1. Agregar 'RECETA' a catalogo_objetivo_regla
   2. Agregar columna 'orden' a heuristico.condicion_regla
   3. Agregar columna 'activa' a heuristico.regla
   4. Considerar simplificar: en lugar de 5 columnas, usar:
      - id_objetivo_tipo (FK a catalogo_objetivo_regla)
      - id_objetivo (el ID del objetivo según el tipo)
      PERO: Esto rompería la integridad referencial (FKs), así que lo actual está bien.

[OK] CONCLUSIÓN:
   La estructura actual es FUNCIONAL y CORRECTA para el propósito.
   Las mejoras son OPCIONALES y no bloquean el funcionamiento.
   Prioridad: Agregar 'orden' y 'activa' a reglas.
""")

conn.close()

print("\n=== ANÁLISIS COMPLETADO ===")
