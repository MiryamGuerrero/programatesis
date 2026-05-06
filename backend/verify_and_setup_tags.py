import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

# Cargar credenciales del .env
load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== 1. VERIFICACIÓN DE ETIQUETAS BASE ===")
# 1.1 Total de etiquetas en nutricion.etiqueta_nutricional
cur.execute("SELECT COUNT(*) as total FROM nutricion.etiqueta_nutricional")
total_tags = cur.fetchone()['total']
print(f"Total de etiquetas base: {total_tags}")

# 1.2 Verificar si existen las etiquetas nuevas propuestas
new_tags = [
    'ALTA_FUENTE_DE_VITAMINA_D', 'MEDIA_FUENTE_DE_VITAMINA_D',
    'ALTO_EN_GRASA_SATURADA', 'BAJO_EN_GRASA_SATURADA',
    'PROTEINA_MAGRA', 'NATURAL_O_MINIMAMENTE_PROCESADO',
    'ALTO_INDICE_GLUCEMICO', 'BAJO_INDICE_GLUCEMICO',
    'ALTO_EN_POTASIO', 'BAJO_EN_POTASIO',
    'ALTO_EN_FOSFORO', 'BAJO_EN_FOSFORO'
]

# Construir placeholders para IN clause
placeholders = ','.join(['%s'] * len(new_tags))
cur.execute(f"SELECT codigo FROM nutricion.etiqueta_nutricional WHERE codigo IN ({placeholders})", new_tags)
existing_new_tags = [row['codigo'] for row in cur.fetchall()]
missing_new_tags = [tag for tag in new_tags if tag not in existing_new_tags]

print(f"\nEtiquetas nuevas ya existentes: {len(existing_new_tags)}")
print(f"Etiquetas nuevas faltantes: {len(missing_new_tags)}")
if missing_new_tags:
    print(f"  Faltantes: {missing_new_tags}")

print("\n=== 2. VERIFICACIÓN DE ASIGNACIONES ===")
# 2.1 Asignaciones de etiquetas a ingredientes
cur.execute("SELECT COUNT(*) as total FROM nutricion.ingrediente_etiqueta")
ing_tags_count = cur.fetchone()['total']
print(f"Total de asignaciones ingrediente-etiqueta: {ing_tags_count}")

# 2.2 Asignaciones de etiquetas a recetas
cur.execute("SELECT COUNT(*) as total FROM nutricion.receta_etiqueta")
rec_tags_count = cur.fetchone()['total']
print(f"Total de asignaciones receta-etiqueta: {rec_tags_count}")

# 2.3 Ingredientes con etiquetas (muestra)
cur.execute("""
    SELECT COUNT(DISTINCT id_ingrediente) as total_ingredientes 
    FROM nutricion.ingrediente_etiqueta
""")
ing_with_tags = cur.fetchone()['total_ingredientes']
print(f"Ingredientes con al menos una etiqueta: {ing_with_tags}")

# 2.4 Recetas con etiquetas (muestra)
cur.execute("""
    SELECT COUNT(DISTINCT id_receta) as total_recetas 
    FROM nutricion.receta_etiqueta
""")
rec_with_tags = cur.fetchone()['total_recetas']
print(f"Recetas con al menos una etiqueta: {rec_with_tags}")

conn.close()

print("\n=== 3. RESULTADO DE VERIFICACIÓN ===")
if total_tags < 38 + len(new_tags):
    print(f"Faltan etiquetas por agregar: {38 + len(new_tags) - total_tags}")
else:
    print("Todas las etiquetas (base + nuevas) están presentes")

if ing_tags_count == 0:
    print("No hay etiquetas asignadas a ingredientes aún")
else:
    print(f"Hay {ing_tags_count} etiquetas asignadas a ingredientes")

if rec_tags_count == 0:
    print("No hay etiquetas asignadas a recetas aún")
else:
    print(f"Hay {rec_tags_count} etiquetas asignadas a recetas")
