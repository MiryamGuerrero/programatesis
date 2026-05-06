import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== ASIGNACIÓN DE 12 NUEVAS ETIQUETAS A INGREDIENTES ===\n")

# IDs de nutrientes (según estructura)
# 10: Grasa total (g)
# 11: AGS (g) - Ácidos Grasos Saturados
# 4: Proteínas (g)
# 5: H. de Carbono (g)
# 9: Fibra vegetal (g)
# 18: Vit. D (µg)
# 30: Calcio (mg)
# 31: Fósforo (mg)
# 37: Potasio (mg)

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

# 1. VITAMINA D
print("1. VITAMINA D:")
# Alta fuente: >15mcg/100g (usando Vit. D id=18)
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id
    WHERE inut.id_nutriente = 18 AND inut.valor_por_100g > 15
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTA_FUENTE_DE_VITAMINA_D'], tag_ids['ALTA_FUENTE_DE_VITAMINA_D']))
count1 = cur.rowcount
total_assigned += count1
print(f"  ALTA_FUENTE_DE_VITAMINA_D: {count1} ingredientes")

# Media fuente: 5-15mcg/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id
    WHERE inut.id_nutriente = 18 AND inut.valor_por_100g BETWEEN 5 AND 15
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['MEDIA_FUENTE_DE_VITAMINA_D'], tag_ids['MEDIA_FUENTE_DE_VITAMINA_D']))
count2 = cur.rowcount
total_assigned += count2
print(f"  MEDIA_FUENTE_DE_VITAMINA_D: {count2} ingredientes")

# 2. GRASA SATURADA (AGS id=11)
print("\n2. GRASA SATURADA:")
# Alto en grasa saturada: >4g/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id
    WHERE inut.id_nutriente = 11 AND inut.valor_por_100g > 4
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_EN_GRASA_SATURADA'], tag_ids['ALTO_EN_GRASA_SATURADA']))
count3 = cur.rowcount
total_assigned += count3
print(f"  ALTO_EN_GRASA_SATURADA: {count3} ingredientes")

# Bajo en grasa saturada: <1.5g/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    LEFT JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id AND inut.id_nutriente = 11
    WHERE (inut.valor_por_100g IS NULL OR inut.valor_por_100g < 1.5)
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['BAJO_EN_GRASA_SATURADA'], tag_ids['BAJO_EN_GRASA_SATURADA']))
count4 = cur.rowcount
total_assigned += count4
print(f"  BAJO_EN_GRASA_SATURADA: {count4} ingredientes")

# 3. PROTEÍNA MAGRA
print("\n3. PROTEÍNA MAGRA:")
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut_prot ON inut_prot.id_ingrediente = i.id AND inut_prot.id_nutriente = 4
    LEFT JOIN nutricion.ingrediente_nutriente inut_grasa ON inut_grasa.id_ingrediente = i.id AND inut_grasa.id_nutriente = 10
    WHERE inut_prot.valor_por_100g >= 10 AND (inut_grasa.valor_por_100g IS NULL OR inut_grasa.valor_por_100g < 3)
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['PROTEINA_MAGRA'], tag_ids['PROTEINA_MAGRA']))
count5 = cur.rowcount
total_assigned += count5
print(f"  PROTEINA_MAGRA: {count5} ingredientes")

# 4. NATURAL_O_MINIMAMENTE_PROCESADO
print("\n4. NATURAL_O_MINIMAMENTE_PROCESADO:")
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
""", (tag_ids['NATURAL_O_MINIMAMENTE_PROCESADO'], tag_ids['NATURAL_O_MINIMAMENTE_PROCESADO']))
count6 = cur.rowcount
total_assigned += count6
print(f"  NATURAL_O_MINIMAMENTE_PROCESADO: {count6} ingredientes")

# 5. ÍNDICE GLUCÉMICO (aproximado por carbohidratos y fibra)
print("\n5. ÍNDICE GLUCÉMICO:")
# Alto IG: >15g carbohidratos y <2g fibra (aproximación)
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut_hc ON inut_hc.id_ingrediente = i.id AND inut_hc.id_nutriente = 5
    LEFT JOIN nutricion.ingrediente_nutriente inut_fib ON inut_fib.id_ingrediente = i.id AND inut_fib.id_nutriente = 9
    WHERE inut_hc.valor_por_100g > 15 AND (inut_fib.valor_por_100g IS NULL OR inut_fib.valor_por_100g < 2)
    AND (i.nombre ILIKE '%%harina%%' OR i.nombre ILIKE '%%azucar%%' OR i.nombre ILIKE '%%arroz%%' OR i.nombre ILIKE '%%pan%%' OR i.nombre ILIKE '%%pastel%%')
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_INDICE_GLUCEMICO'], tag_ids['ALTO_INDICE_GLUCEMICO']))
count7 = cur.rowcount
total_assigned += count7
print(f"  ALTO_INDICE_GLUCEMICO: {count7} ingredientes")

# 6. POTASIO (id=37)
print("\n6. POTASIO:")
# Alto en potasio: >300mg/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id AND inut.id_nutriente = 37
    WHERE inut.valor_por_100g > 300
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_EN_POTASIO'], tag_ids['ALTO_EN_POTASIO']))
count8 = cur.rowcount
total_assigned += count8
print(f"  ALTO_EN_POTASIO: {count8} ingredientes")

# Bajo en potasio: <100mg/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    LEFT JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id AND inut.id_nutriente = 37
    WHERE (inut.valor_por_100g IS NULL OR inut.valor_por_100g < 100)
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['BAJO_EN_POTASIO'], tag_ids['BAJO_EN_POTASIO']))
count9 = cur.rowcount
total_assigned += count9
print(f"  BAJO_EN_POTASIO: {count9} ingredientes")

# 7. FÓSFORO (id=31)
print("\n7. FÓSFORO:")
# Alto en fósforo: >200mg/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id AND inut.id_nutriente = 31
    WHERE inut.valor_por_100g > 200
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['ALTO_EN_FOSFORO'], tag_ids['ALTO_EN_FOSFORO']))
count10 = cur.rowcount
total_assigned += count10
print(f"  ALTO_EN_FOSFORO: {count10} ingredientes")

# Bajo en fósforo: <50mg/100g
cur.execute("""
    INSERT INTO nutricion.ingrediente_etiqueta (id_ingrediente, id_etiqueta)
    SELECT i.id, %s
    FROM nutricion.ingrediente i
    LEFT JOIN nutricion.ingrediente_nutriente inut ON inut.id_ingrediente = i.id AND inut.id_nutriente = 31
    WHERE (inut.valor_por_100g IS NULL OR inut.valor_por_100g < 50)
    AND NOT EXISTS (
        SELECT 1 FROM nutricion.ingrediente_etiqueta ie 
        WHERE ie.id_ingrediente = i.id AND ie.id_etiqueta = %s
    )
""", (tag_ids['BAJO_EN_FOSFORO'], tag_ids['BAJO_EN_FOSFORO']))
count11 = cur.rowcount
total_assigned += count11
print(f"  BAJO_EN_FOSFORO: {count11} ingredientes")

conn.commit()
print(f"\n=== TOTAL ASIGNACIONES NUEVAS: {total_assigned} ===")

# Verificación final
print("\n=== VERIFICACIÓN FINAL ===")
placeholders = ','.join(['%s'] * 12)
new_tag_codes = list(tag_ids.keys())
cur.execute(f"""
    SELECT e.codigo, COUNT(*) as total
    FROM nutricion.ingrediente_etiqueta ie
    JOIN nutricion.etiqueta_nutricional e ON e.id = ie.id_etiqueta
    WHERE e.codigo IN ({placeholders})
    GROUP BY e.codigo
    ORDER BY e.codigo
""", new_tag_codes)
for row in cur.fetchall():
    print(f"  {row['codigo']:35} | {row['total']:4} ingredientes")

conn.close()
