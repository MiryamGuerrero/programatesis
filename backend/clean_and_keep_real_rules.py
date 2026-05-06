import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== LIMPIEZA: MANTENER SOLO REGLAS REALES ===\n")

# 1. Ver cuántas reglas totales hay
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
total_antes = cur.fetchone()['total']
print(f"1. Total reglas antes: {total_antes}")

# 2. Ver cuáles son las reglas nuevas (artritis y lupus)
cur.execute("""
    SELECT r.id, c.nombre as condicion
    FROM heuristico.regla r
    JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    JOIN heuristico.condicion c ON c.id = cr.id_condicion
    WHERE c.nombre IN ('Artritis Idiopatica Juvenil', 'Lupus Eritematoso Sistemico')
""")
real_rules = cur.fetchall()
real_rule_ids = [row['id'] for row in real_rules]
print(f"2. Reglas reales (artritis/lupus): {len(real_rule_ids)}")
for row in real_rules[:5]:
    print(f"   {row['id']}: {row['condicion']}")

# 3. Borrar relaciones de reglas que NO son reales
if real_rule_ids:
    placeholders = ','.join(['%s'] * len(real_rule_ids))
    
    print(f"\n3. Borrando relaciones de reglas NO reales...")
    cur.execute(f"""
        DELETE FROM heuristico.condicion_regla 
        WHERE id_regla NOT IN ({placeholders})
    """)
    deleted_relations = cur.rowcount
    print(f"   Relaciones borradas: {deleted_relations}")
    
    print(f"\n4. Borrando reglas NO reales...")
    cur.execute(f"""
        DELETE FROM heuristico.regla 
        WHERE id NOT IN ({placeholders})
    """)
    deleted_rules = cur.rowcount
    print(f"   Reglas borradas: {deleted_rules}")

conn.commit()

# 5. Verificar resultado final
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
total_despues = cur.fetchone()['total']
print(f"\n5. Total reglas después: {total_despues}")

cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion_regla")
total_relaciones = cur.fetchone()['total']
print(f"   Total relaciones condicion-regla: {total_relaciones}")

# 6. Mostrar reglas finales
print(f"\n6. REGLAS FINALES:")
cur.execute("""
    SELECT r.id, c.nombre as condicion, o.codigo as objetivo, 
           a.codigo as accion, e.codigo as etiqueta
    FROM heuristico.regla r
    JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    JOIN heuristico.condicion c ON c.id = cr.id_condicion
    LEFT JOIN heuristico.catalogo_objetivo_regla o ON o.id = r.id_tipo_objetivo
    LEFT JOIN heuristico.catalogo_accion a ON a.id = r.id_accion
    LEFT JOIN nutricion.etiqueta_nutricional e ON e.id = r.id_etiqueta
    ORDER BY c.nombre, a.codigo
""")
for row in cur.fetchall():
    print(f"   {row['id']}: {row['condicion']} -> {row['accion']} {row['etiqueta']}")

conn.close()

print("\n=== LIMPIEZA COMPLETADA ===")
print("Solo quedan las reglas reales para Artritis y Lupus.")
