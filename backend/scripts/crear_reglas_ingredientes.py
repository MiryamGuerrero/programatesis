import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== REGLAS CON INGREDIENTE (objetivo 1) ===\n')

# 1. Buscar ingredientes especificos
print('1. Buscando embutidos...')
cursor.execute("SELECT id, nombre FROM nutricion.ingrediente WHERE nombre ILIKE '%salchicha%' OR nombre ILIKE '%chorizo%' OR nombre ILIKE '%salame%' OR nombre ILIKE '%embutido%' LIMIT 3")
embutidos = cursor.fetchall()
print(f'Embutidos encontrados: {len(embutidos)}')
for ing in embutidos:
    print(f'  ID {ing[0]}: {ing[1]}')
    # AIJ - ELIMINAR embutidos especificos
    cursor.execute('''
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, origen_regla, mensaje_error, es_estricta)
        VALUES (1, 1, %s, 'CLINICA', 'ELIMINAR embutidos: altos en sodio y grasas saturadas', false)
        RETURNING id
    ''', (ing[0],))
    regla_id = cursor.fetchone()[0]
    cursor.execute('INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, 6)', (regla_id,))
    print(f'    Regla {regla_id}: AIJ -> ELIMINAR {ing[1]}')

# 2. Buscar azucar
print('\n2. Buscando azucar...')
cursor.execute("SELECT id, nombre FROM nutricion.ingrediente WHERE nombre ILIKE '%azucar%' OR nombre ILIKE '%azúcar%' LIMIT 2")
azucar = cursor.fetchall()
print(f'Azucar encontrada: {len(azucar)}')
for ing in azucar:
    print(f'  ID {ing[0]}: {ing[1]}')
    # Para AIJ, Lupus, Obesidad, Sobrepeso
    for cond_id, cond_nombre in [(6, 'AIJ'), (7, 'Lupus'), (30, 'Obesidad'), (105, 'Obesidad'), (104, 'Sobrepeso')]:
        cursor.execute('''
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, origen_regla, mensaje_error, es_estricta)
            VALUES (2, 1, %s, 'NUTRICIONAL', 'DISMINUIR azucar refinada drasticamente', false)
            RETURNING id
        ''', (ing[0],))
        regla_id = cursor.fetchone()[0]
        cursor.execute('INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)', (regla_id, cond_id))
        print(f'    Regla {regla_id}: {cond_nombre} -> DISMINUIR {ing[1]}')

# 3. Buscar sal
print('\n3. Buscando sal...')
cursor.execute("SELECT id, nombre FROM nutricion.ingrediente WHERE nombre ILIKE '%sal%' AND nombre NOT ILIKE '%salmon%' AND nombre NOT ILIKE '%salchicha%' LIMIT 2")
sal = cursor.fetchall()
print(f'Sal encontrada: {len(sal)}')
for ing in sal:
    print(f'  ID {ing[0]}: {ing[1]}')
    # Para obesidad (retencion de liquidos)
    for cond_id in [30, 105]:
        cursor.execute('''
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, origen_regla, mensaje_error, es_estricta)
            VALUES (2, 1, %s, 'NUTRICIONAL', 'DISMINUIR sal para reducir retencion de liquidos', false)
            RETURNING id
        ''', (ing[0],))
        regla_id = cursor.fetchone()[0]
        cursor.execute('INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)', (regla_id, cond_id))
        print(f'    Regla {regla_id}: Obesidad -> DISMINUIR {ing[1]}')

# 4. Buscar pescado azul especifico para AIJ
print('\n4. Buscando pescado azul...')
cursor.execute("SELECT id, nombre FROM nutricion.ingrediente WHERE nombre ILIKE '%salmon%' OR nombre ILIKE '%atun%' OR nombre ILIKE '%sardina%' LIMIT 3")
pescados = cursor.fetchall()
print(f'Pescados encontrados: {len(pescados)}')
for ing in pescados:
    print(f'  ID {ing[0]}: {ing[1]}')
    # AIJ - PRIORIZAR pescado azul
    cursor.execute('''
        INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, origen_regla, mensaje_error, es_estricta)
        VALUES (3, 1, %s, 'CLINICA', 'PRIORIZAR pescado azul: rico en Omega-3 antiinflamatorio', false)
        RETURNING id
    ''', (ing[0],))
    regla_id = cursor.fetchone()[0]
    cursor.execute('INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, 6)', (regla_id,))
    print(f'    Regla {regla_id}: AIJ -> PRIORIZAR {ing[1]}')

# 5. Buscar frutos secos para desnutricion
print('\n5. Buscando frutos secos...')
cursor.execute("SELECT id, nombre FROM nutricion.ingrediente WHERE nombre ILIKE '%nuez%' OR nombre ILIKE '%almendra%' OR nombre ILIKE '%cacahuete%' LIMIT 3")
frutos = cursor.fetchall()
print(f'Frutos secos encontrados: {len(frutos)}')
for ing in frutos:
    print(f'  ID {ing[0]}: {ing[1]}')
    # Desnutricion - PRIORIZAR frutos secos (calorias y grasas buenas)
    for cond_id in [23, 27, 107, 100, 24, 28, 106, 101]:
        cursor.execute('''
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_ingrediente, origen_regla, mensaje_error, es_estricta)
            VALUES (3, 1, %s, 'NUTRICIONAL', 'AUMENTAR frutos secos: densidad calorica y grasas saludables', false)
            RETURNING id
        ''', (ing[0],))
        regla_id = cursor.fetchone()[0]
        cursor.execute('INSERT INTO heuristico.condicion_regla (id_regla, id_condicion) VALUES (%s, %s)', (regla_id, cond_id))
        print(f'    Regla {regla_id}: Desnutricion -> AUMENTAR {ing[1]}')

conn.commit()

print('\n=== VERIFICACION FINAL ===\n')
cursor.execute('SELECT COUNT(*) FROM heuristico.regla')
print(f'Total reglas: {cursor.fetchone()[0]}')

cursor.execute('SELECT o.codigo, COUNT(*) FROM heuristico.regla r JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo GROUP BY o.codigo')
print('\nPor tipo de objetivo:')
for row in cursor.fetchall():
    print(f'  {row[0]}: {row[1]}')

cursor.execute('SELECT a.codigo, COUNT(*) FROM heuristico.regla r JOIN heuristico.catalogo_accion a ON a.id = r.id_accion GROUP BY a.codigo')
print('\nPor accion:')
for row in cursor.fetchall():
    print(f'  {row[0]}: {row[1]}')

conn.close()
print('\n✅ REGLAS CON INGREDIENTE CREADAS EXITOSAMENTE')
