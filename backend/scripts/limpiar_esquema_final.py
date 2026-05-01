import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== ANALISIS DE TABLAS EN ESQUEMA HEURISTICO ===')
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'heuristico' 
    ORDER BY table_name
""")
tables = cursor.fetchall()
print('Tablas encontradas:')
for t in tables:
    print('  - ' + t[0])

# Tablas que deben quedar segun criterio:
# catalogo_accion, catalogo_objetivo_regla, catalogo_tipo_condicion, condicion, condicion_regla, regla
keep_tables = [
    'catalogo_accion',
    'catalogo_objetivo_regla',
    'catalogo_tipo_condicion',
    'condicion',
    'condicion_regla',
    'regla'
]

print('\n=== TABLAS A MANTENER ===')
for t in keep_tables:
    print('  ' + t)

print('\n=== TABLAS A ELIMINAR ===')
tables_to_drop = [t[0] for t in tables if t[0] not in keep_tables]
for t in tables_to_drop:
    print('  ' + t)

print('\n=== ELIMINANDO TABLAS INNECESARIAS ===')
for table in tables_to_drop:
    try:
        cursor.execute('DROP TABLE IF EXISTS heuristico."' + table + '" CASCADE')
        print('  Eliminada: ' + table)
    except Exception as e:
        print('  Error eliminando ' + table + ': ' + str(e))

conn.commit()

print('\n=== VERIFICACION FINAL ===')
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'heuristico' 
    ORDER BY table_name
""")
final_tables = cursor.fetchall()
print('Tablas restantes en heuristico:')
for t in final_tables:
    print('  ' + t[0])

# Verificar que las tablas necesarias tienen datos coherentes
print('\n=== VERIFICACION DE COHERENCIA DE DATOS ===')
for table in ['catalogo_accion', 'catalogo_objetivo_regla', 'catalogo_tipo_condicion', 'condicion', 'condicion_regla', 'regla']:
    cursor.execute('SELECT COUNT(*) FROM heuristico."' + table + '"')
    count = cursor.fetchone()[0]
    print('  ' + table + ': ' + str(count) + ' registros')

conn.close()
print('\nLIMPIEZA DE ESQUEMA COMPLETADA')
