import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== ASIGNANDO NATURAL_O_MINIMAMENTE_PROCESADO (v2) ===\n")

# Obtener ID de la etiqueta
cur.execute("SELECT id FROM nutricion.etiqueta_nutricional WHERE codigo = 'NATURAL_O_MINIMAMENTE_PROCESADO'")
tag_id = cur.fetchone()['id']

# Ver ingredientes que NO tienen etiqueta ULTRAPROCESADO o REFINADO
print("1. Verificando ingredientes candidatos...")
cur.execute("""
    SELECT COUNT(DISTINCT i.id) as total
    FROM nutricion.ingrediente i
    JOIN nutricion.subgrupo_alimentario sg ON sg.id = i.id_subgrupo_alimentario
    JOIN nutricion.grupo_alimentario g ON g.id = sg.id_grupo_alimentario
    WHERE g.nombre IN ('FRUTAS', 'VERDURAS Y HORTALIZAS', 'TUBERCULOS', 'CARNES Y DERIVADOS', 'PESCADOS Y DERIVADOS', 'HUEVOS Y DERIVADOS')
    AND i.nombre NOT ILIKE '%%procesado%%' 
    AND i.nombre NOT ILIKE '%%embutido%%'
    AND i.nombre NOT ILIKE '%%en conserva%%'
    AND i.nombre NOT ILIKE '%%frito%%'
    AND i.nombre NOT ILIKE '%%congelado%%'
""")
candidates = cur.fetchone()['total']
print(f"  Ingredientes candidatos: {candidates}")

# Asignar la etiqueta
print("\n2. Asignando etiqueta...")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT DISTINCT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.subgrupo_alimentario sg ON sg.id = i.id_subgrupo_alimentario
    JOIN nutricion.grupo_alimentario g ON g.id = sg.id_grupo_alimentario
    WHERE g.nombre IN ('FRUTAS', 'VERDURAS Y HORTALIZAS', 'TUBERCULOS', 'CARNES Y DERIVADOS', 'PESCADOS Y DERIVADOS', 'HUEVOS Y DERIVADOS')
    AND i.nombre NOT ILIKE '%%procesado%%' 
    AND i.nombre NOT ILIKE '%%embutido%%'
    AND i.nombre NOT ILIKE '%%en conserva%%'
    AND i.nombre NOT ILIKE '%%frito%%'
    AND i.nombre NOT ILIKE '%%congelado%%'
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_id, tag_id))
count = cur.rowcount
conn.commit()
print(f"  Asignadas: {count} ingredientes")

# Verificar si también deberíamos excluir los que ya tienen ULTRAPROCESADO
print("\n3. Verificando ingredientes con ULTRAPROCESADO...")
cur.execute("""
    SELECT COUNT(*) as total
    FROM nutricion.ingrediente_etiqueta ie
    JOIN nutricion.etiqueta_nutricional e ON e.id = ie.id_etiqueta
    WHERE e.codigo = 'ULTRAPROCESADO'
""")
ultra_count = cur.fetchone()['total']
print(f"  Ingredientes con ULTRAPROCESADO: {ultra_count}")

conn.close()
print("\n=== COMPLETADO ===")
