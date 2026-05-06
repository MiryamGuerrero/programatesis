import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== ASIGNACIÓN DE 12 NUEVAS ETIQUETAS A INGREDIENTES ===\n")

# Obtener IDs de las etiquetas nuevas
cur.execute("""
    SELECT id, codigo FROM nutricion.etiqueta_nutricional 
    WHERE codigo IN (
        'ALTA_FUENTE_DE_VITAMINA_D', 'MEDIA_FUENTE_DE_VITAMINA_D',
        'ALTO_EN_GRASA_SATURADA', 'BAJO_EN_GRASA_SATURADA',
        'PROTEINA_MAGRA', 'NATURAL_O_MINIMAMENTE_PROCESADO',
        'ALTO_INDICE_GLUCEMICO', 'BAJO_INDICE_GLUCEMICO',
        'ALTO_EN_POTASIO', 'BAJO_EN_POTASIO',
        'ALTO_EN_FOSFORO', 'BAJO_EN_FOSFORO'
    )
""")
tag_ids = {row['codigo']: row['id'] for row in cur.fetchall()}

total_assigned = 0

# 1. VITAMINA D (simulado basado en fuentes comunes)
print("1. VITAMINA D:")
# Fuentes ricas en Vit D: pescados grasos, hongos, huevos, lácteos fortificados
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    WHERE i.nombre ILIKE ANY(ARRAY['%%salmon%%', '%%atun%%', '%%caballa%%', '%%sardina%%', '%%hongo%%', '%%champi%%', '%%huevo%%'])
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTA_FUENTE_DE_VITAMINA_D'], tag_ids['ALTA_FUENTE_DE_VITAMINA_D']))
count = cur.rowcount
total_assigned += count
print(f"  ALTA_FUENTE_DE_VITAMINA_D: {count} ingredientes")

# 2. GRASA SATURADA (basado en datos nutricionales)
print("\n2. GRASA SATURADA:")
# Alto en grasa saturada: >4g/100g (usando grasa total como proxy aproximado)
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id
    JOIN nutricion.nutriente n ON n.id = inut.id_nutriente
    WHERE n.nombre = 'Grasa total' AND inut.cantidad_por_100g > 4
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_EN_GRASA_SATURADA'], tag_ids['ALTO_EN_GRASA_SATURADA']))
count = cur.rowcount
total_assigned += count
print(f"  ALTO_EN_GRASA_SATURADA: {count} ingredientes")

# Bajo en grasa saturada: <1.5g/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    LEFT JOIN (
        SELECT id_ingrediente, cantidad_por_100g 
        FROM nutricion.ingrediente_nutriente inut2
        JOIN nutricion.nutriente n2 ON n2.id = inut2.id_nutriente
        WHERE n2.nombre = 'Grasa total'
    ) grasa ON grasa.id_ingrediente = i.id
    WHERE (grasa.cantidad_por_100g IS NULL OR grasa.cantidad_por_100g < 1.5)
    AND i.id NOT IN (SELECT id_ingrediente FROM nutricion.ingrediente_etiqueta WHERE id_etiqueta = %s)
""", (tag_ids['BAJO_EN_GRASA_SATURADA'], tag_ids['BAJO_EN_GRASA_SATURADA']))
count = cur.rowcount
total_assigned += count
print(f"  BAJO_EN_GRASA_SATURADA: {count} ingredientes")

# 3. PROTEINA MAGRA
print("\n3. PROTEÍNA MAGRA:")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut_prot ON inut_prot.id_ingrediente = i.id
    JOIN nutricion.nutriente n_prot ON n_prot.id = inut_prot.id_nutriente
    LEFT JOIN (
        SELECT id_ingrediente, cantidad_por_100g 
        FROM nutricion.ingrediente_nutriente inut2
        JOIN nutricion.nutriente n2 ON n2.id = inut2.id_nutriente
        WHERE n2.nombre = 'Grasa total'
    ) grasa ON grasa.id_ingrediente = i.id
    WHERE n_prot.nombre = 'Proteína' AND inut_prot.cantidad_por_100g >= 10
    AND (grasa.cantidad_por_100g IS NULL OR grasa.cantidad_por_100g < 3)
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['PROTEINA_MAGRA'], tag_ids['PROTEINA_MAGRA']))
count = cur.rowcount
total_assigned += count
print(f"  PROTEINA_MAGRA: {count} ingredientes")

# 4. NATURAL_O_MINIMAMENTE_PROCESADO
print("\n4. NATURAL_O_MINIMAMENTE_PROCESADO:")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.subgrupo_alimentario sg ON sg.id = i.id_subgrupo_alimentario
    JOIN nutricion.grupo_alimentario g ON g.id = sg.id_grupo_alimentario
    WHERE g.nombre IN ('Frutas', 'Verduras', 'Hortalizas', 'Tubérculos', 'Carnes', 'Pescados', 'Huevos')
    AND i.nombre NOT ILIKE '%%procesado%%' AND i.nombre NOT ILIKE '%%embutido%%'
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['NATURAL_O_MINIMAMENTE_PROCESADO'], tag_ids['NATURAL_O_MINIMAMENTE_PROCESADO']))
count = cur.rowcount
total_assigned += count
print(f"  NATURAL_O_MINIMAMENTE_PROCESADO: {count} ingredientes")

# 5. ÍNDICE GLUCÉMICO (basado en carbohidratos y fibra)
print("\n5. ÍNDICE GLUCÉMICO:")
# Alto IG: alimentos refinados con >15g carbohidratos y poca fibra
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut_hc ON inut_hc.id_ingrediente = i.id
    JOIN nutricion.nutriente n_hc ON n_hc.id = inut_hc.id_nutriente
    LEFT JOIN (
        SELECT id_ingrediente, cantidad_por_100g 
        FROM nutricion.ingrediente_nutriente inut2
        JOIN nutricion.nutriente n2 ON n2.id = inut2.id_nutriente
        WHERE n2.nombre = 'Fibra dietética'
    ) fibra ON fibra.id_ingrediente = i.id
    WHERE n_hc.nombre = 'Carbohidratos' AND inut_hc.cantidad_por_100g > 15
    AND (fibra.cantidad_por_100g IS NULL OR fibra.cantidad_por_100g < 2)
    AND i.nombre ILIKE ANY(ARRAY['%%harina%%', '%%azucar%%', '%%arroz%%', '%%pan%%'])
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_INDICE_GLUCEMICO'], tag_ids['ALTO_INDICE_GLUCEMICO']))
count = cur.rowcount
total_assigned += count
print(f"  ALTO_INDICE_GLUCEMICO: {count} ingredientes")

# 6. POTASIO y FÓSFORO (usando datos nutricionales)
print("\n6. POTASIO:")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id
    JOIN nutricion.nutriente n ON n.id = inut.id_nutriente
    WHERE n.nombre = 'Potasio' AND inut.cantidad_por_100g > 300
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_EN_POTASIO'], tag_ids['ALTO_EN_POTASIO']))
count = cur.rowcount
total_assigned += count
print(f"  ALTO_EN_POTASIO: {count} ingredientes")

print("\n7. FÓSFORO:")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id
    JOIN nutricion.nutriente n ON n.id = inut.id_nutriente
    WHERE n.nombre = 'Fósforo' AND inut.cantidad_por_100g > 200
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_EN_FOSFORO'], tag_ids['ALTO_EN_FOSFORO']))
count = cur.rowcount
total_assigned += count
print(f"  ALTO_EN_FOSFORO: {count} ingredientes")

conn.commit()
print(f"\n=== TOTAL ASIGNACIONES NUEVAS: {total_assigned} ===")

# Verificar asignaciones finales
print("\n=== VERIFICACIÓN FINAL ===")
cur.execute("""
    SELECT e.codigo, COUNT(*) as total
    FROM nutricion.ingrediente_etiqueta ie
    JOIN nutricion.etiqueta_nutricional e ON e.id = ie.id_etiqueta
    WHERE e.codigo IN (
        'ALTA_FUENTE_DE_VITAMINA_D', 'MEDIA_FUENTE_DE_VITAMINA_D',
        'ALTO_EN_GRASA_SATURADA', 'BAJO_EN_GRASA_SATURADA',
        'PROTEINA_MAGRA', 'NATURAL_O_MINIMAMENTE_PROCESADO',
        'ALTO_INDICE_GLUCEMICO', 'BAJO_INDICE_GLUCEMICO',
        'ALTO_EN_POTASIO', 'BAJO_EN_POTASIO',
        'ALTO_EN_FOSFORO', 'BAJO_EN_FOSFORO'
    )
    GROUP BY e.codigo
    ORDER BY e.codigo
""")
for row in cur.fetchall():
    print(f"  {row['codigo']:35} | {row['total']:4} ingredientes")

conn.close()
