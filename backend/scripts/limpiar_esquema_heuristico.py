import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== TABLAS EN ESQUEMA HEURISTICO ===\n')
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'heuristico' 
    ORDER BY table_name
""")
tables = cursor.fetchall()
print('Tablas encontradas:')
for t in tables:
    print(f'  - {t[0]}')

print('\n=== TABLAS QUE DEBEN QUEDAR (SEGUN CRITERIO) ===')
tablas_permitidas = [
    'catalogo_accion',
    'catalogo_objetivo_regla', 
    'catalogo_tipo_condicion',
    'condicion_regla',
    'regla'
]
for t in tablas_permitidas:
    print(f'  ✅ {t}')

print('\n=== TABLAS QUE SE ELIMINARAN ===')
tablas_eliminar = [t[0] for t in tables if t[0] not in tablas_permitidas]
for t in tablas_eliminar:
    print(f'  ❌ {t}')

print('\n=== ELIMINANDO TABLAS INNECESARIAS ===')
for table in tablas_eliminar:
    try:
        cursor.execute(f'DROP TABLE IF EXISTS heuristico."{table}" CASCADE')
        print(f'  ✅ Eliminada: {table}')
    except Exception as e:
        print(f'  ⚠️ Error eliminando {table}: {e}')

conn.commit()

print('\n=== VERIFICACION FINAL ===')
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'heuristico' 
    ORDER BY table_name
""")
tables_final = cursor.fetchall()
print('Tablas restantes en heuristico:')
for t in tables_final:
    print(f'  ✅ {t[0]}')

conn.close()
print('\n✅ LIMPIEZA DE ESQUEMA HEURISTICO COMPLETADA')
