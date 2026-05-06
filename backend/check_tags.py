import psycopg
from psycopg.rows import dict_row

conn = psycopg.connect('postgresql://postgres:AyT0kw4euSkcacOA@db.yuasobxhctmukvozmrta.supabase.co:5432/postgres', row_factory=dict_row)
cur = conn.cursor()

# Buscar tablas relacionadas con etiquetas
cur.execute("""
    SELECT table_schema, table_name 
    FROM information_schema.tables 
    WHERE table_name LIKE '%etiqueta%' 
    OR table_name LIKE '%tag%'
    ORDER BY table_schema, table_name
""")
tables = cur.fetchall()
print('=== TABLAS RELACIONADAS CON ETIQUETAS ===')
for t in tables:
    print(f"{t['table_schema']}.{t['table_name']}")

# Verificar estructura de ingrediente_etiqueta
print('\n=== ESTRUCTURA: nutricion.ingrediente_etiqueta ===')
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_schema = 'nutricion' AND table_name = 'ingrediente_etiqueta'
    ORDER BY ordinal_position
""")
cols = cur.fetchall()
for c in cols:
    print(f"  {c['column_name']}: {c['data_type']}")

# Buscar tabla similar para recetas
print('\n=== BUSCANDO TABLAS DE RECETAS ===')
cur.execute("""
    SELECT table_schema, table_name 
    FROM information_schema.tables 
    WHERE table_name LIKE '%receta%' 
    ORDER BY table_schema, table_name
""")
receta_tables = cur.fetchall()
for t in receta_tables:
    print(f"{t['table_schema']}.{t['table_name']}")

# Verificar si existe receta_etiqueta
print('\n=== VERIFICANDO SI EXISTE receta_etiqueta ===')
cur.execute("""
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'nutricion' AND table_name = 'receta_etiqueta'
    )
""")
exists = cur.fetchone()['exists']
print(f"¿Existe nutricion.receta_etiqueta? {exists}")

conn.close()
