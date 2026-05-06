import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== RESUMEN DE ASIGNACIÓN DE ETIQUETAS ===\n")

# 1. Top 10 etiquetas más usadas en ingredientes
print("1. TOP 10 ETIQUETAS MÁS USADAS EN INGREDIENTES:")
cur.execute("""
    SELECT e.codigo, e.nombre_visible, COUNT(*) as total
    FROM nutricion.ingrediente_etiqueta ie
    JOIN nutricion.etiqueta_nutricional e ON e.id = ie.id_etiqueta
    GROUP BY e.id, e.codigo, e.nombre_visible
    ORDER BY total DESC
    LIMIT 10
""")
for row in cur.fetchall():
    print(f"  {row['codigo']:40} | {row['total']:4} ingredientes")

# 2. Verificar si las nuevas etiquetas tienen asignaciones
print("\n2. ESTADO DE LAS 12 ETIQUETAS NUEVAS EN INGREDIENTES:")
new_tag_codes = [
    'ALTA_FUENTE_DE_VITAMINA_D', 'MEDIA_FUENTE_DE_VITAMINA_D',
    'ALTO_EN_GRASA_SATURADA', 'BAJO_EN_GRASA_SATURADA',
    'PROTEINA_MAGRA', 'NATURAL_O_MINIMAMENTE_PROCESADO',
    'ALTO_INDICE_GLUCEMICO', 'BAJO_INDICE_GLUCEMICO',
    'ALTO_EN_POTASIO', 'BAJO_EN_POTASIO',
    'ALTO_EN_FOSFORO', 'BAJO_EN_FOSFORO'
]

placeholders = ','.join(['%s'] * len(new_tag_codes))
cur.execute(f"""
    SELECT e.codigo, COUNT(ie.id_ingrediente) as total_ingredientes
    FROM nutricion.etiqueta_nutricional e
    LEFT JOIN nutricion.ingrediente_etiqueta ie ON ie.id_etiqueta = e.id
    WHERE e.codigo IN ({placeholders})
    GROUP BY e.id, e.codigo
    ORDER BY e.codigo
""", new_tag_codes)

for row in cur.fetchall():
    status = f"{row['total_ingredientes']} ingredientes" if row['total_ingredientes'] > 0 else "SIN ASIGNAR"
    print(f"  {row['codigo']:35} | {status}")

# 3. Recetas con etiquetas (muestra)
print("\n3. RECETAS CON ETIQUETAS (muestra):")
cur.execute("""
    SELECT r.id, r.nombre, COUNT(re.id_etiqueta) as num_etiquetas
    FROM nutricion.receta r
    LEFT JOIN nutricion.receta_etiqueta re ON re.id_receta = r.id
    WHERE re.id_etiqueta IS NOT NULL
    GROUP BY r.id, r.nombre
    LIMIT 10
""")
recetas = cur.fetchall()
if recetas:
    for row in recetas:
        print(f"  {row['id']}: {row['nombre']} ({row['num_etiquetas']} etiquetas)")
else:
    print("  No hay recetas con etiquetas aún")

# 4. Sugerencia de próximos pasos
print("\n=== PRÓXIMOS PASOS SUGERIDOS ===")
print("1. Asignar las 12 nuevas etiquetas a ingredientes basándose en composición nutricional")
print("2. Poblar nutricion.receta_etiqueta calculando etiquetas desde ingredientes")
print("3. Crear reglas clínicas usando estas etiquetas")

conn.close()
