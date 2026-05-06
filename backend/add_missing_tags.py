import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os
from datetime import datetime

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

# Etiquetas nuevas a agregar
new_tags = [
    ('ALTA_FUENTE_DE_VITAMINA_D', 'Alta fuente de vitamina D', 'Identifica alimentos con >15mcg vit D/100g. Esencial para salud ósea en artritis y lupus'),
    ('MEDIA_FUENTE_DE_VITAMINA_D', 'Media fuente de vitamina D', 'Contiene 5-15mcg vit D/100g. Contribuye al aporte diario de vitamina D'),
    ('ALTO_EN_GRASA_SATURADA', 'Alto en grasa saturada', 'Contiene >4g grasa saturada/100g. Limitar en enfermedades inflamatorias y riesgo cardiovascular'),
    ('BAJO_EN_GRASA_SATURADA', 'Bajo en grasa saturada', 'Contiene <1.5g grasa saturada/100g. Mejor opción para control lipídico'),
    ('PROTEINA_MAGRA', 'Proteína magra', 'Fuente proteica con <3g grasa/100g. Ideal para crecimiento y preservación muscular'),
    ('NATURAL_O_MINIMAMENTE_PROCESADO', 'Natural o mínimamente procesado', 'Alimento sin aditivos industriales significativos. Preferible en dieta antiinflamatoria'),
    ('ALTO_INDICE_GLUCEMICO', 'Alto índice glucémico', 'IG >70. Puede elevar glucosa rápidamente, limitar en control metabólico'),
    ('BAJO_INDICE_GLUCEMICO', 'Bajo índice glucémico', 'IG <55. Mejor control glucémico, útil en síndrome metabólico asociado'),
    ('ALTO_EN_POTASIO', 'Alto en potasio', 'Contiene >300mg K/100g. Vigilar en enfermedad renal o medicación que retiene potasio'),
    ('BAJO_EN_POTASIO', 'Bajo en potasio', 'Contiene <100mg K/100g. Seguro en restricción de potasio por daño renal'),
    ('ALTO_EN_FOSFORO', 'Alto en fósforo', 'Contiene >200mg P/100g. Vigilar en enfermedad renal y riesgo óseo'),
    ('BAJO_EN_FOSFORO', 'Bajo en fósforo', 'Contiene <50mg P/100g. Seguro en restricción de fósforo por daño renal')
]

print("=== AGREGANDO ETIQUETAS FALTANTES ===")
inserted = 0
skipped = 0

for codigo, nombre, descripcion in new_tags:
    # Verificar si ya existe
    cur.execute("SELECT 1 FROM nutricion.etiqueta_nutricional WHERE codigo = %s", (codigo,))
    if cur.fetchone():
        print(f"  SKIP: {codigo} (ya existe)")
        skipped += 1
        continue
    
    # Insertar nueva etiqueta
    cur.execute("""
        INSERT INTO nutricion.etiqueta_nutricional (codigo, nombre_visible, descripcion)
        VALUES (%s, %s, %s)
    """, (codigo, nombre, descripcion))
    print(f"  INSERTADO: {codigo} - {nombre}")
    inserted += 1

conn.commit()
print(f"\nResumen: {inserted} insertadas, {skipped} ya existían")

# Verificar total final
cur.execute("SELECT COUNT(*) as total FROM nutricion.etiqueta_nutricional")
total = cur.fetchone()['total']
print(f"Total de etiquetas en la base: {total}")

conn.close()
