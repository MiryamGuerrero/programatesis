import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== CORRIGIENDO MENSAJES SIN SIMBOLOS FORMALES ===\n')

# 1. Obtener todas las reglas sin simbolo formal
cursor.execute("""
    SELECT 
        r.id,
        r.mensaje_error,
        a.codigo as accion,
        o.codigo as objetivo,
        c.nombre as condicion
    FROM heuristico.regla r
    JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
    LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
    WHERE r.mensaje_error NOT LIKE '[ALERTA]%' 
      AND r.mensaje_error NOT LIKE '[ATENCI%'  -- Catch both with and without accent
      AND r.mensaje_error NOT LIKE '[NORMAL]%'
    ORDER BY r.id
""")
bad_messages = cursor.fetchall()

print(f'Encontradas {len(bad_messages)} reglas con mensaje sin simbolo formal:\n')

# 2. Actualizar cada mensaje segun la accion y condicion
updated = 0
for row in bad_messages:
    regla_id = row[0]
    old_msg = row[1]
    accion = row[2]
    objetivo = row[3]
    condicion = row[4]
    
    # Determinar el simbolo segun la accion
    if accion == 'ELIMINAR':
        simbolo = '[ALERTA]'
    elif accion == 'DISMINUIR':
        # Si es para obesidad/sobrepeso, es ALERTA; si es temporal, ATENCION
        if 'obesidad' in condicion.lower() or 'sobrepeso' in condicion.lower() or 'aij' in condicion.lower():
            simbolo = '[ALERTA]'
        else:
            simbolo = '[ATENCIÓN]'
    elif accion == 'PRIORIZAR':
        if 'normal' in condicion.lower():
            simbolo = '[NORMAL]'
        else:
            simbolo = '[ATENCIÓN]'
    else:
        simbolo = '[ATENCIÓN]'
    
    # Crear nuevo mensaje
    new_msg = simbolo + ' ' + old_msg
    
    # Actualizar en base de datos
    cursor.execute('UPDATE heuristico.regla SET mensaje_error = %s WHERE id = %s', (new_msg, regla_id))
    updated += 1
    
    if updated <= 10:  # Mostrar solo los primeros 10
        print(f'  Regla [{regla_id}]: {old_msg[:50]}... -> {new_msg[:60]}...')

if updated > 10:
    print(f'  ... y {updated - 10} mas actualizadas')

conn.commit()

print(f'\n=== VERIFICACION FINAL ===\n')
cursor.execute("""
    SELECT COUNT(*) 
    FROM heuristico.regla r
    WHERE r.mensaje_error NOT LIKE '[ALERTA]%' 
      AND r.mensaje_error NOT LIKE '[ATENCI%'
      AND r.mensaje_error NOT LIKE '[NORMAL]%'
""")
remaining = cursor.fetchone()[0]

if remaining == 0:
    print('Todos los mensajes tienen simbolos formales ahora')
else:
    print(f'Aun quedan {remaining} mensajes sin simbolo formal')

# Mostrar muestra de mensajes actualizados
print('\n=== MUESTRA DE MENSAJES ACTUALIZADOS ===\n')
cursor.execute("""
    SELECT 
        r.id,
        a.codigo as accion,
        CASE 
            WHEN r.id_ingrediente IS NOT NULL THEN 'INGREDIENTE'
            WHEN r.id_grupo_alimentario IS NOT NULL THEN 'GRUPO'
            WHEN r.id_subgrupo_alimentario IS NOT NULL THEN 'SUBGRUPO'
            WHEN r.id_etiqueta IS NOT NULL THEN 'ETIQUETA'
        END as objetivo,
        r.mensaje_error
    FROM heuristico.regla r
    JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    ORDER BY r.id
    LIMIT 15
""")

for row in cursor.fetchall():
    msg = row[3][:70] + '...' if len(row[3]) > 70 else row[3]
    print(f'  [{row[0]}] {row[1]}/{row[2]}: {msg}')

conn.close()
print('\nCORRECCION COMPLETADA')
