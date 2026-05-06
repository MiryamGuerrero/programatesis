import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== ANÁLISIS COMPLETO DE BASE DE DATOS ===\n")

# 1. Listar todos los esquemas
print("1. ESQUEMAS DISPONIBLES:")
cur.execute("""
    SELECT schema_name 
    FROM information_schema.schemata 
    WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
    AND schema_name NOT LIKE 'pg_%'
    ORDER BY schema_name
""")
schemas = [row['schema_name'] for row in cur.fetchall()]
for s in schemas:
    print(f"   {s}")

# 2. Para cada esquema, listar tablas y columnas
table_info = []
for schema in schemas:
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = %s
        ORDER BY table_name
    """, (schema,))
    tables = [row['table_name'] for row in cur.fetchall()]
    
    for table in tables:
        # Obtener columnas
        cur.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns 
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
        """, (schema, table))
        columns = cur.fetchall()
        
        # Obtener conteo de registros
        try:
            cur.execute(f'SELECT COUNT(*) as total FROM "{schema}"."{table}"')
            count = cur.fetchone()['total']
        except:
            count = -1
        
        table_info.append({
            'schema': schema,
            'table': table,
            'columns': columns,
            'count': count
        })

print("\n2. TABLAS POR ESQUEMA (resumen):")
current_schema = None
for info in table_info:
    if current_schema != info['schema']:
        current_schema = info['schema']
        print(f"\n   ESQUEMA: {current_schema}")
    print(f"      {info['table']:40} | {info['count']:>6} registros | {len(info['columns']):>2} columnas")

# 3. Identificar posibles redundancias (mismos nombres de tablas en distintos esquemas)
print("\n3. POSIBLES REDUNDANCIAS (mismos nombres en distintos esquemas):")
table_names = {}
for info in table_info:
    name = info['table']
    if name not in table_names:
        table_names[name] = []
    table_names[name].append(f"{info['schema']}.{info['table']}")

for name, occurrences in table_names.items():
    if len(occurrences) > 1:
        print(f"   [!] {name} existe en: {', '.join(occurrences)}")

# 4. Analizar columnas que podrían ser redundantes
print("\n4. ANÁLISIS DE COLUMNAS REDUNDANTES:")
# Buscar columnas con nombres similares dentro de la misma tabla
for info in table_info:
    col_names = [c['column_name'] for c in info['columns']]
    # Verificar si hay columnas que parecen duplicadas (ej: id_xxx y xxx_id)
    # Simplificado: solo listar columnas
    pass

# 5. Verificar reglas huérfanas o inconsistentes
print("\n5. VERIFICACIÓN DE CONSISTENCIA EN REGLAS:")
# 5.1 Reglas sin relación con condición
cur.execute("""
    SELECT COUNT(*) as total 
    FROM heuristico.regla r
    LEFT JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    WHERE cr.id IS NULL
""")
orphan_rules = cur.fetchone()['total']
print(f"   Reglas sin condición asociada: {orphan_rules}")

# 5.2 Condiciones sin reglas
cur.execute("""
    SELECT c.id, c.nombre, COUNT(cr.id_regla) as num_reglas
    FROM heuristico.condicion c
    LEFT JOIN heuristico.condicion_regla cr ON cr.id_condicion = c.id
    GROUP BY c.id, c.nombre
    HAVING COUNT(cr.id_regla) = 0
""")
conds_no_rules = cur.fetchall()
if conds_no_rules:
    print(f"   Condiciones sin reglas: {len(conds_no_rules)}")
    for row in conds_no_rules:
        print(f"      - {row['nombre']}")

# 5.3 Verificar contradicciones: misma etiqueta con acciones opuestas para misma condición
print("\n6. BÚSQUEDA DE CONTRADICCIONES (misma etiqueta, acciones opuestas):")
cur.execute("""
    SELECT c.nombre as condicion, e.codigo as etiqueta,
           a.codigo as accion, COUNT(*) as total
    FROM heuristico.regla r
    JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    JOIN heuristico.condicion c ON c.id = cr.id_condicion
    JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
    WHERE r.id_etiqueta IS NOT NULL
    GROUP BY c.id, c.nombre, e.codigo, a.codigo
    ORDER BY c.nombre, e.codigo, a.codigo
""")
results = cur.fetchall()
# Detectar etiquetas con múltiples acciones para misma condición
from collections import defaultdict
cond_etiq_actions = defaultdict(set)
for row in results:
    key = (row['condicion'], row['etiqueta'])
    cond_etiq_actions[key].add(row['accion'])

contradictions = []
for (cond, etiq), actions in cond_etiq_actions.items():
    if len(actions) > 1:
        contradictions.append((cond, etiq, actions))

if contradictions:
    print(f"   ⚠️  Encontradas {len(contradictions)} contradicciones potenciales:")
    for cond, etiq, actions in contradictions[:10]:
        print(f"      - {cond}: {etiq} -> {actions}")
else:
    print("   ✅ No se encontraron contradicciones directas")

# 7. Verificar tablas vacías o poco usadas
print("\n7. TABLAS VACÍAS O POCO USADAS:")
for info in table_info:
    if info['count'] == 0:
        print(f"   - {info['schema']}.{info['table']}: VACÍA")
    elif info['count'] == -1:
        print(f"   - {info['schema']}.{info['table']}: ERROR al contar")

# 8. Analizar uso de columnas opcionales (muchos NULLs)
print("\n8. ANÁLISIS DE COLUMNAS CON MUCHOS NULLs:")
# Solo para tablas principales
main_tables = ['heuristico.regla', 'nutricion.ingrediente', 'nutricion.receta']
for table in main_tables:
    schema, tabla = table.split('.')
    cur.execute(f"""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = '{schema}' AND table_name = '{tabla}'
        AND is_nullable = 'YES'
        ORDER BY ordinal_position
    """)
    nullable_cols = [row['column_name'] for row in cur.fetchall()]
    
    if nullable_cols:
        print(f"\n   {table}:")
        for col in nullable_cols[:5]:  # Solo primeras 5
            try:
                cur.execute(f"""
                    SELECT 
                        (COUNT(*) - COUNT("{col}")) as nulls,
                        COUNT(*) as total,
                        ROUND((COUNT(*) - COUNT("{col}")) * 100.0 / COUNT(*), 2) as pct_null
                    FROM {table}
                """)
                stats = cur.fetchone()
                if stats['pct_null'] > 50:
                    print(f"      ⚠️  {col}: {stats['pct_null']}% NULL ({stats['nulls']}/{stats['total']})")
            except:
                pass

print("\n=== RESUMEN DE HALLAZGOS ===")
print("""
⚠️  Puntos a revisar:
1. Tablas redundantes entre esquemas
2. Reglas huérfanas (sin condición)
3. Condiciones sin reglas asociadas
4. Contradicciones: misma etiqueta con acciones opuestas para misma condición
5. Tablas vacías que podrían eliminarse
6. Columnas con >50% de NULLs (candidatas a simplificación)

✅ Siguiente paso:
   - Eliminar tablas/vistas que no se usan
   - Limpiar reglas huérfanas
   - Asegurar que CLINICA y NUTRICIONAL no se contradigan
   - Simplificar estructura donde sea posible
""")

conn.close()
