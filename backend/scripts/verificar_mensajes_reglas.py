import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== VERIFICANDO MENSAJES DE REGLAS ===\n')

# Ver todos los mensajes actuales
cursor.execute("""
    SELECT 
        r.id,
        c.nombre as condicion,
        a.codigo as accion,
        o.codigo as objetivo,
        r.mensaje_error
    FROM heuristico.regla r
    JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
    LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
    ORDER BY c.nombre, a.codigo
""")

print('Mensajes actuales por condicion:\n')
current_cond = None
for row in cursor.fetchall():
    if row[1] != current_cond:
        current_cond = row[1]
        if current_cond:
            print()
        print(f'--- {current_cond} ---')
    print(f'  [{row[0]}] {row[2]}/{row[3]}: {row[4][:80]}...' if len(row[4]) > 80 else f'  [{row[0]}] {row[2]}/{row[3]}: {row[4]}')

# Verificar que los mensajes tienen los simbolos formales
print('\n\n=== VERIFICANDO SIMBOLOS FORMALES ===\n')
cursor.execute("""
    SELECT r.id, r.mensaje_error
    FROM heuristico.regla r
    WHERE r.mensaje_error NOT LIKE '[ALERTA]%' 
      AND r.mensaje_error NOT LIKE '[ATENCION]%'
      AND r.mensaje_error NOT LIKE '[NORMAL]%'
""")
bad_messages = cursor.fetchall()

if len(bad_messages) == 0:
    print('Todos los mensajes tienen simbolos formales ([ALERTA], [ATENCION], [NORMAL])')
else:
    print(f'Se encontraron {len(bad_messages)} mensajes sin simbolo formal:')
    for row in bad_messages:
        print(f'  Regla {row[0]}: {row[1][:60]}...')

# Verificar que no hay emojis
print('\n=== VERIFICANDO NO EMOJIS ===\n')
emoji_found = False
cursor.execute('SELECT id, mensaje_error FROM heuristico.regla')
for row in cursor.fetchall():
    msg = row[1]
    # Check for common emojis (this is a simple check)
    if any(ord(char) > 127 for char in msg if char not in 'áéíóúñÁÉÍÓÚÑüÜçÇ'):
        print(f'  Regla {row[0]}: Contiene caracteres especiales')
        emoji_found = True

if not emoji_found:
    print('Ningun mensaje contiene emojis')

conn.close()
print('\nVERIFICACION COMPLETADA')
