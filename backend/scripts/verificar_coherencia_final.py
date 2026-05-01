import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== VERIFICACION DE COHERENCIA DE DATOS ===\n')

# 1. Verificar que regla.id_accion existe en catalogo_accion
print('1. Verificando regla.id_accion -> catalogo_accion...')
cursor.execute("""
    SELECT r.id, r.id_accion 
    FROM heuristico.regla r
    LEFT JOIN heuristico.catalogo_accion ca ON ca.id = r.id_accion
    WHERE ca.id IS NULL
""")
inconsistent = cursor.fetchall()
if len(inconsistent) == 0:
    print('  OK: Todas las reglas tienen accion valida')
else:
    print(f'  ERROR: {len(inconsistent)} reglas con id_accion invalido')

# 2. Verificar que regla.id_tipo_objetivo existe en catalogo_objetivo_regla
print('\n2. Verificando regla.id_tipo_objetivo -> catalogo_objetivo_regla...')
cursor.execute("""
    SELECT r.id, r.id_tipo_objetivo 
    FROM heuristico.regla r
    LEFT JOIN heuristico.catalogo_objetivo_regla co ON co.id = r.id_tipo_objetivo
    WHERE co.id IS NULL
""")
inconsistent = cursor.fetchall()
if len(inconsistent) == 0:
    print('  OK: Todas las reglas tienen objetivo valido')
else:
    print(f'  ERROR: {len(inconsistent)} reglas con id_tipo_objetivo invalido')

# 3. Verificar que condicion.id_tipo_condicion existe en catalogo_tipo_condicion
print('\n3. Verificando condicion.id_tipo_condicion -> catalogo_tipo_condicion...')
cursor.execute("""
    SELECT c.id, c.id_tipo_condicion 
    FROM heuristico.condicion c
    LEFT JOIN heuristico.catalogo_tipo_condicion ctc ON ctc.id = c.id_tipo_condicion
    WHERE ctc.id IS NULL
""")
inconsistent = cursor.fetchall()
if len(inconsistent) == 0:
    print('  OK: Todas las condiciones tienen tipo valido')
else:
    print(f'  ERROR: {len(inconsistent)} condiciones con id_tipo_condicion invalido')

# 4. Verificar que condicion_regla.id_regla existe en regla
print('\n4. Verificando condicion_regla.id_regla -> regla...')
cursor.execute("""
    SELECT cr.id_regla, cr.id_condicion 
    FROM heuristico.condicion_regla cr
    LEFT JOIN heuristico.regla r ON r.id = cr.id_regla
    WHERE r.id IS NULL
""")
inconsistent = cursor.fetchall()
if len(inconsistent) == 0:
    print('  OK: Todas las relaciones tienen regla valida')
else:
    print(f'  ERROR: {len(inconsistent)} relaciones con id_regla invalido')

# 5. Verificar que condicion_regla.id_condicion existe en condicion
print('\n5. Verificando condicion_regla.id_condicion -> condicion...')
cursor.execute("""
    SELECT cr.id_regla, cr.id_condicion 
    FROM heuristico.condicion_regla cr
    LEFT JOIN heuristico.condicion c ON c.id = cr.id_condicion
    WHERE c.id IS NULL
""")
inconsistent = cursor.fetchall()
if len(inconsistent) == 0:
    print('  OK: Todas las relaciones tienen condicion valida')
else:
    print(f'  ERROR: {len(inconsistent)} relaciones con id_condicion invalido')

# 6. Verificar objetivos de regla (ingrediente, grupo, subgrupo, etiqueta)
print('\n6. Verificando objetivos de regla...')

# 6.1. INGREDIENTE (objetivo=1)
cursor.execute("""
    SELECT r.id, r.id_ingrediente 
    FROM heuristico.regla r
    WHERE r.id_tipo_objetivo = 1 AND r.id_ingrediente IS NOT NULL
""")
ing_reglas = cursor.fetchall()
print(f'  Reglas con objetivo INGREDIENTE: {len(ing_reglas)}')
if len(ing_reglas) > 0:
    cursor.execute("""
        SELECT r.id, r.id_ingrediente, i.nombre
        FROM heuristico.regla r
        LEFT JOIN nutricion.ingrediente i ON i.id = r.id_ingrediente
        WHERE r.id_tipo_objetivo = 1 AND i.id IS NULL
    """)
    invalid = cursor.fetchall()
    if len(invalid) == 0:
        print('    OK: Todos los ingredientes existen')
    else:
        print(f'    ERROR: {len(invalid)} ingredientes no existen')

# 6.2. GRUPO (objetivo=2)
cursor.execute("""
    SELECT r.id, r.id_grupo_alimentario 
    FROM heuristico.regla r
    WHERE r.id_tipo_objetivo = 2 AND r.id_grupo_alimentario IS NOT NULL
""")
grupo_reglas = cursor.fetchall()
print(f'  Reglas con objetivo GRUPO: {len(grupo_reglas)}')
if len(grupo_reglas) > 0:
    cursor.execute("""
        SELECT r.id, r.id_grupo_alimentario, g.nombre
        FROM heuristico.regla r
        LEFT JOIN nutricion.grupo_alimentario g ON g.id = r.id_grupo_alimentario
        WHERE r.id_tipo_objetivo = 2 AND g.id IS NULL
    """)
    invalid = cursor.fetchall()
    if len(invalid) == 0:
        print('    OK: Todos los grupos existen')
    else:
        print(f'    ERROR: {len(invalid)} grupos no existen')

# 6.3. ETIQUETA (objetivo=3)
cursor.execute("""
    SELECT r.id, r.id_etiqueta 
    FROM heuristico.regla r
    WHERE r.id_tipo_objetivo = 3 AND r.id_etiqueta IS NOT NULL
""")
etiqueta_reglas = cursor.fetchall()
print(f'  Reglas con objetivo ETIQUETA: {len(etiqueta_reglas)}')
if len(etiqueta_reglas) > 0:
    cursor.execute("""
        SELECT r.id, r.id_etiqueta, e.nombre_visible
        FROM heuristico.regla r
        LEFT JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
        WHERE r.id_tipo_objetivo = 3 AND e.id IS NULL
    """)
    invalid = cursor.fetchall()
    if len(invalid) == 0:
        print('    OK: Todas las etiquetas existen')
    else:
        print(f'    ERROR: {len(invalid)} etiquetas no existen')

# 6.4. SUBGRUPO (objetivo=4)
cursor.execute("""
    SELECT r.id, r.id_subgrupo_alimentario 
    FROM heuristico.regla r
    WHERE r.id_tipo_objetivo = 4 AND r.id_subgrupo_alimentario IS NOT NULL
""")
subgrupo_reglas = cursor.fetchall()
print(f'  Reglas con objetivo SUBGRUPO: {len(subgrupo_reglas)}')
if len(subgrupo_reglas) > 0:
    cursor.execute("""
        SELECT r.id, r.id_subgrupo_alimentario, s.nombre
        FROM heuristico.regla r
        LEFT JOIN nutricion.subgrupo_alimentario s ON s.id = r.id_subgrupo_alimentario
        WHERE r.id_tipo_objetivo = 4 AND s.id IS NULL
    """)
    invalid = cursor.fetchall()
    if len(invalid) == 0:
        print('    OK: Todos los subgrupos existen')
    else:
        print(f'    ERROR: {len(invalid)} subgrupos no existen')

# 7. Verificar que no hay reglas sin objetivo
print('\n7. Verificando reglas sin objetivo...')
cursor.execute("""
    SELECT id 
    FROM heuristico.regla r
    WHERE r.id_ingrediente IS NULL 
      AND r.id_grupo_alimentario IS NULL 
      AND r.id_subgrupo_alimentario IS NULL 
      AND r.id_etiqueta IS NULL 
      AND r.id_receta IS NULL
""")
no_objetivo = cursor.fetchall()
if len(no_objetivo) == 0:
    print('  OK: Todas las reglas tienen objetivo asignado')
else:
    print(f'  ERROR: {len(no_objetivo)} reglas SIN objetivo')

# 8. Verificar coherencia de acciones (no contradicciones)
print('\n8. Verificando contradicciones (misma condicion + objetivo opuesto)...')
cursor.execute("""
    SELECT 
        cr.id_condicion,
        c.nombre as condicion,
        r.id_tipo_objetivo,
        o.codigo as objetivo,
        r.id_ingrediente,
        r.id_grupo_alimentario,
        r.id_subgrupo_alimentario,
        r.id_etiqueta,
        a.codigo as accion
    FROM heuristico.condicion_regla cr
    JOIN heuristico.condicion c ON c.id = cr.id_condicion
    JOIN heuristico.regla r ON r.id = cr.id_regla
    JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
    ORDER BY cr.id_condicion, r.id_tipo_objetivo
""")
rows = cursor.fetchall()
# Agrupar por condicion + objetivo para ver si hay ELIMINAR y PRIORIZAR para el mismo objetivo
from collections import defaultdict
contradicciones = defaultdict(list)
for row in rows:
    key = (row[0], row[2], row[3], row[4], row[5], row[6], row[7])  # condicion + tipo_objetivo + ids
    contradicciones[key].append(row[8])  # accion

found_contradiction = False
for key, acciones in contradicciones.items():
    if 'ELIMINAR' in acciones and 'PRIORIZAR' in acciones:
        print(f'  CONTRADICCION: Condicion {key[0]}, Objetivo {key[1]}, Acciones: {acciones}')
        found_contradiction = True
    elif 'DISMINUIR' in acciones and 'PRIORIZAR' in acciones:
        print(f'  CONTRADICCION: Condicion {key[0]}, Objetivo {key[1]}, Acciones: {acciones}')
        found_contradiction = True

if not found_contradiction:
    print('  OK: No se encontraron contradicciones')

# 9. Resumen final
print('\n=== RESUMEN FINAL ===')
cursor.execute('SELECT COUNT(*) FROM heuristico.catalogo_accion')
print(f'catalogo_accion: {cursor.fetchone()[0]} registros')
cursor.execute('SELECT COUNT(*) FROM heuristico.catalogo_objetivo_regla')
print(f'catalogo_objetivo_regla: {cursor.fetchone()[0]} registros')
cursor.execute('SELECT COUNT(*) FROM heuristico.catalogo_tipo_condicion')
print(f'catalogo_tipo_condicion: {cursor.fetchone()[0]} registros')
cursor.execute('SELECT COUNT(*) FROM heuristico.condicion')
print(f'condicion: {cursor.fetchone()[0]} registros')
cursor.execute('SELECT COUNT(*) FROM heuristico.condicion_regla')
print(f'condicion_regla: {cursor.fetchone()[0]} relaciones')
cursor.execute('SELECT COUNT(*) FROM heuristico.regla')
print(f'regla: {cursor.fetchone()[0]} reglas')

print('\n=== DISTRIBUCION DE REGLAS POR OBJETIVO ===')
cursor.execute("""
    SELECT o.codigo, COUNT(*) 
    FROM heuristico.regla r
    JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
    GROUP BY o.codigo
    ORDER BY o.codigo
""")
for row in cursor.fetchall():
    print(f'  {row[0]}: {row[1]} reglas')

print('\n=== DISTRIBUCION DE REGLAS POR ACCION ===')
cursor.execute("""
    SELECT a.codigo, COUNT(*) 
    FROM heuristico.regla r
    JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    GROUP BY a.codigo
    ORDER BY a.codigo
""")
for row in cursor.fetchall():
    print(f'  {row[0]}: {row[1]} reglas')

conn.close()
print('\nVERIFICACION COMPLETADA')
