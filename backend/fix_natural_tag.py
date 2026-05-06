import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== VERIFICANDO GRUPOS ALIMENTARIOS ===\n")

# Ver grupos existentes
print("1. Grupos alimentarios en la base:")
cur.execute("SELECT id, nombre FROM nutricion.grupo_alimentario ORDER BY id")
for row in cur.fetchall():
    print(f"  {row['id']}: {row['nombre']}")

# Ver subgrupos
print("\n2. Subgrupos alimentarios (muestra):")
cur.execute("SELECT id, id_grupo_alimentario, nombre FROM nutricion.subgrupo_alimentario ORDER BY id_grupo_alimentario, id LIMIT 20")
for row in cur.fetchall():
    print(f"  {row['id']}: {row['nombre']} (grupo: {row['id_grupo_alimentario']})")

# Obtener ID de NATURAL_O_MINIMAMENTE_PROCESADO
cur.execute("SELECT id FROM nutricion.etiqueta_nutricional WHERE codigo = 'NATURAL_O_MINIMAMENTE_PROCESADO'")
tag_id = cur.fetchone()['id']

# Verificar asignaciones actuales
cur.execute("SELECT COUNT(*) as total FROM nutricion.ingrediente_etiqueta WHERE id_etiqueta = %s", (tag_id,))
current = cur.fetchone()['total']
print(f"\n3. Asignaciones actuales de NATURAL_O_MINIMAMENTE_PROCESADO: {current}")

# Asignar basándose en grupos reales
print("\n4. Asignando NATURAL_O_MINIMAMENTE_PROCESADO con nombres correctos...")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.subgrupo_alimentario sg ON sg.id = i.id_subgrupo_alimentario
    JOIN nutricion.grupo_alimentario g ON g.id = sg.id_grupo_alimentario
    WHERE g.nombre IN ('Frutas', 'Verduras', 'Hortalizas', 'Tuberculos', 'Carnes', 'Pescados', 'Huevos')
    AND i.nombre NOT ILIKE '%%procesado%%' AND i.nombre NOT ILIKE '%%embutido%%'
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_id, tag_id))
count = cur.rowcount
conn.commit()
print(f"  Asignadas: {count} ingredientes")

# Verificar total final
cur.execute("SELECT COUNT(*) as total FROM nutricion.ingrediente_etiqueta WHERE id_etiqueta = %s", (tag_id,))
final = cur.fetchone()['total']
print(f"  Total final: {final} ingredientes")

conn.close()
