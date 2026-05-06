import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== COMPLETANDO CONFIGURACIÓN DE ETIQUETAS ===\n")

# 1. Asignar BAJO_INDICE_GLUCEMICO
print("1. Asignando BAJO_INDICE_GLUCEMICO...")
cur.execute("SELECT id FROM nutricion.etiqueta_nutricional WHERE codigo = 'BAJO_INDICE_GLUCEMICO'")
tag_id = cur.fetchone()['id']

cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT DISTINCT i.id, %s
    FROM nutricion.ingrediente i
    LEFT JOIN nutricion.ingrediente_nutriente inut_hc ON inut_hc.id_ingrediente = i.id AND inut_hc.id_nutriente = 5
    LEFT JOIN nutricion.ingrediente_nutriente inut_fib ON inut_fib.id_ingrediente = i.id AND inut_fib.id_nutriente = 9
    WHERE (inut_hc.valor_por_100g IS NULL OR inut_hc.valor_por_100g < 15)
    OR (inut_fib.valor_por_100g >= 2 AND inut_hc.valor_por_100g > 15)
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_id, tag_id))
count = cur.rowcount
conn.commit()
print(f"  BAJO_INDICE_GLUCEMICO: {count} ingredientes")

# 2. Poblar receta_etiqueta basándose en ingredientes
print("\n2. Poblando etiquetas de recetas desde ingredientes...")
# Por cada receta, obtener todas las etiquetas de sus ingredientes
cur.execute("""
    INSERT INTO nutricion.receta_etiqueta (id_receta, id_etiqueta)
    SELECT DISTINCT r.id, ie.id_etiqueta
    FROM nutricion.receta r
    JOIN nutricion.receta_ingrediente ri ON ri.id_receta = r.id
    JOIN nutricion.ingrediente_etiqueta ie ON ie.id_ingrediente = ri.id_ingrediente
    WHERE NOT EXISTS (
        SELECT 1 FROM nutricion.receta_etiqueta re 
        WHERE re.id_receta = r.id AND re.id_etiqueta = ie.id_etiqueta
    )
""")
count_rec = cur.rowcount
conn.commit()
print(f"  Nuevas asignaciones receta-etiqueta: {count_rec}")

# 3. Verificar estado final
print("\n3. RESUMEN FINAL:")
cur.execute("SELECT COUNT(DISTINCT id_ingrediente) as total FROM nutricion.ingrediente_etiqueta")
ing_count = cur.fetchone()['total']
print(f"  Ingredientes con etiquetas: {ing_count}")

cur.execute("SELECT COUNT(DISTINCT id_receta) as total FROM nutricion.receta_etiqueta")
rec_count = cur.fetchone()['total']
print(f"  Recetas con etiquetas: {rec_count}")

cur.execute("SELECT COUNT(*) as total FROM nutricion.ingrediente_etiqueta")
ing_tags = cur.fetchone()['total']
print(f"  Total asignaciones ingrediente-etiqueta: {ing_tags}")

cur.execute("SELECT COUNT(*) as total FROM nutricion.receta_etiqueta")
rec_tags = cur.fetchone()['total']
print(f"  Total asignaciones receta-etiqueta: {rec_tags}")

# 4. Mostrar algunas recetas con sus etiquetas
print("\n4. MUESTRA DE RECETAS CON ETIQUETAS:")
cur.execute("""
    SELECT r.id, r.nombre, COUNT(re.id_etiqueta) as num_etiquetas
    FROM nutricion.receta r
    JOIN nutricion.receta_etiqueta re ON re.id_receta = r.id
    GROUP BY r.id, r.nombre
    ORDER BY num_etiquetas DESC
    LIMIT 10
""")
for row in cur.fetchall():
    print(f"  {row['id']}: {row['nombre']} ({row['num_etiquetas']} etiquetas)")

conn.close()
print("\n=== CONFIGURACIÓN COMPLETADA ===")
