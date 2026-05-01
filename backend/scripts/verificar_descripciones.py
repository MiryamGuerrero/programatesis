import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== VERIFICANDO DESCRIPCIONES EN TABLA CONDICION ===\n')

# 1. Ver todas las condiciones y sus descripciones
cursor.execute("""
    SELECT c.id, c.nombre, c.descripcion, tc.nombre as tipo
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    ORDER BY tc.id, c.id
""")
rows = cursor.fetchall()

print('Condiciones actuales:')
current_tipo = None
for row in rows:
    if row[3] != current_tipo:
        current_tipo = row[3]
        print(f'\n--- {current_tipo} ---')
    
    desc = row[2] if row[2] else 'SIN DESCRIPCION'
    print(f'  [{row[0]}] {row[1]}: {desc}')

# 2. Identificar condiciones sin descripcion
print('\n=== CONDICIONES SIN DESCRIPCION ===')
cursor.execute("""
    SELECT c.id, c.nombre, tc.nombre as tipo
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    WHERE c.descripcion IS NULL OR c.descripcion = ''
    ORDER BY tc.id, c.id
""")
sin_desc = cursor.fetchall()

if len(sin_desc) == 0:
    print('Todas las condiciones tienen descripcion')
else:
    print(f'Se encontraron {len(sin_desc)} condiciones sin descripcion:')
    for row in sin_desc:
        print(f'  [{row[0]}] {row[1]} ({row[2]})')

conn.close()
print('\nVERIFICACION COMPLETADA')
