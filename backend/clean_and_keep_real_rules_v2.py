import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== LIMPIEZA: MANTENER SOLO REGLAS REALES ===\n")

# 1. Obtener IDs de reglas reales (artritis y lupus)
print("1. Obteniendo reglas reales (artritis/lupus)...")
cur.execute("""
    SELECT DISTINCT r.id
    FROM heuristico.regla r
    JOIN heuristico.condicion_regla cr ON cr.id_regla = r.id
    JOIN heuristico.condicion c ON c.id = cr.id_condicion
    WHERE c.nombre IN ('Artritis Idiopatica Juvenil', 'Lupus Eritematoso Sistemico')
""")
real_rules = cur.fetchall()
real_rule_ids = [row['id'] for row in real_rules]
print(f"   Reglas reales encontradas: {len(real_rule_ids)}")

# 2. Borrar TODAS las reglas y relaciones, luego reinsertar solo las reales
print("\n2. Limpiando tablas...")
cur.execute("DELETE FROM heuristico.condicion_regla")
deleted_relations = cur.rowcount
print(f"   Relaciones borradas: {deleted_relations}")

cur.execute("DELETE FROM heuristico.regla")
deleted_rules = cur.rowcount
print(f"   Reglas borradas: {deleted_rules}")

conn.commit()
print("   Tablas limpias.")

# 3. Reinsertar solo las reglas reales para artritis
print("\n3. Recreando reglas para Artritis Idiopatica Juvenil...")
artritis_id = 6  # ID de Artritis Idiopatica Juvenil
acciones_map = {'ELIMINAR': 1, 'DISMINUIR': 2, 'PRIORIZAR': 3}
objetivo_id = 3  # ETIQUETA

reglas_artritis = [
    # ELIMINAR
    ('GRASAS_TRANS_ELEVADAS', 'ELIMINAR', 'Grasas trans elevadas - Artritis', True),
    ('ALTAMENTE_INFLAMATORIO', 'ELIMINAR', 'Altamente inflamatorio - Artritis', True),
    ('ULTRAPROCESADO', 'ELIMINAR', 'Ultraprocesado - Artritis', True),
    # DISMINUIR
    ('CONTIENE_GRASAS_TRANS', 'DISMINUIR', 'Contiene grasas trans - Artritis', False),
    ('PROINFLAMATORIO', 'DISMINUIR', 'Proinflamatorio - Artritis', False),
    ('MODERADAMENTE_INFLAMATORIO', 'DISMINUIR', 'Moderadamente inflamatorio - Artritis', False),
    ('ALTO_EN_GRASAS', 'DISMINUIR', 'Alto en grasas - Artritis', False),
    ('MUY_ALTO_EN_GRASAS', 'DISMINUIR', 'Muy alto en grasas - Artritis', False),
    ('ALTO_EN_AZUCAR_ANADIDO', 'DISMINUIR', 'Alto en azúcar añadido - Artritis', False),
    ('CALORIAS_VACIAS', 'DISMINUIR', 'Calorías vacías - Artritis', False),
    ('REFINADO', 'DISMINUIR', 'Refinado - Artritis', False),
    # PRIORIZAR
    ('ALTAMENTE_ANTIINFLAMATORIO', 'PRIORIZAR', 'Altamente antiinflamatorio - Artritis', False),
    ('ANTIINFLAMATORIO', 'PRIORIZAR', 'Antiinflamatorio - Artritis', False),
    ('LIGERAMENTE_ANTIINFLAMATORIO', 'PRIORIZAR', 'Ligeramente antiinflamatorio - Artritis', False),
    ('RICO_EN_OMEGA_3', 'PRIORIZAR', 'Rico en omega 3 - Artritis', False),
    ('BALANCE_DE_OMEGAS_FAVORABLE', 'PRIORIZAR', 'Balance de omegas favorable - Artritis', False),
    ('ALTA_FUENTE_DE_CALCIO', 'PRIORIZAR', 'Alta fuente de calcio - Artritis', False),
    ('ALTA_FUENTE_DE_FIBRA', 'PRIORIZAR', 'Alta fuente de fibra - Artritis', False),
    ('ALTO_PODER_ANTIOXIDANTE', 'PRIORIZAR', 'Alto poder antioxidante - Artritis', False),
    ('ALTA_FUENTE_DE_PROTEINA', 'PRIORIZAR', 'Alta fuente de proteína - Artritis', False),
    ('MEDIA_FUENTE_DE_PROTEINA', 'PRIORIZAR', 'Media fuente de proteína - Artritis', False)
]

# Obtener IDs de etiquetas
etiqueta_codes = [r[0] for r in reglas_artritis]
placeholders = ','.join(['%s'] * len(etiqueta_codes))
cur.execute(f"SELECT id, codigo FROM nutricion.etiqueta_nutricional WHERE codigo IN ({placeholders})", etiqueta_codes)
etiquetas_map = {row['codigo']: row['id'] for row in cur.fetchall()}

rules_created = 0
for etiqueta_codigo, accion, mensaje, estricta in reglas_artritis:
    if etiqueta_codigo in etiquetas_map:
        cur.execute("""
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
            VALUES (%s, %s, %s, %s, %s, 'CLINICA')
            RETURNING id
        """, (acciones_map[accion], objetivo_id, etiquetas_map[etiqueta_codigo], f'[ARTRITIS] {mensaje}', estricta))
        regla_id = cur.fetchone()['id']
        
        cur.execute("""
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
            VALUES (%s, %s)
        """, (artritis_id, regla_id))
        rules_created += 1

print(f"   Reglas artritis creadas: {rules_created}")

# 4. Recrear reglas para Lupus
print("\n4. Recreando reglas para Lupus Eritematoso Sistemico...")
lupus_id = 7  # ID de Lupus Eritematoso Sistemico

reglas_lupus = [
    # ELIMINAR
    ('MUY_ALTO_EN_SODIO', 'ELIMINAR', 'Muy alto en sodio - Lupus', True),
    ('RIESGO_DE_RETENCION_DE_LIQUIDOS', 'ELIMINAR', 'Riesgo retención líquidos - Lupus', True),
    ('GRASAS_TRANS_ELEVADAS', 'ELIMINAR', 'Grasas trans elevadas - Lupus', True),
    ('ALTAMENTE_INFLAMATORIO', 'ELIMINAR', 'Altamente inflamatorio - Lupus', True),
    ('ULTRAPROCESADO', 'ELIMINAR', 'Ultraprocesado - Lupus', True),
    # DISMINUIR
    ('ALTO_EN_SODIO', 'DISMINUIR', 'Alto en sodio - Lupus', False),
    ('MODERADO_EN_SODIO', 'DISMINUIR', 'Moderado en sodio - Lupus', False),
    ('RIESGO_MODERADO_DE_RETENCION', 'DISMINUIR', 'Riesgo moderado retención - Lupus', False),
    ('CONTIENE_GRASAS_TRANS', 'DISMINUIR', 'Contiene grasas trans - Lupus', False),
    ('ALTO_EN_GRASAS', 'DISMINUIR', 'Alto en grasas - Lupus', False),
    ('MUY_ALTO_EN_GRASAS', 'DISMINUIR', 'Muy alto en grasas - Lupus', False),
    ('ALTO_EN_AZUCAR_ANADIDO', 'DISMINUIR', 'Alto en azúcar añadido - Lupus', False),
    ('CALORIAS_VACIAS', 'DISMINUIR', 'Calorías vacías - Lupus', False),
    ('REFINADO', 'DISMINUIR', 'Refinado - Lupus', False),
    ('PROINFLAMATORIO', 'DISMINUIR', 'Proinflamatorio - Lupus', False),
    ('MODERADAMENTE_INFLAMATORIO', 'DISMINUIR', 'Moderadamente inflamatorio - Lupus', False),
    # PRIORIZAR
    ('BAJO_EN_SODIO', 'PRIORIZAR', 'Bajo en sodio - Lupus', False),
    ('EQUILIBRIO_DE_LIQUIDOS_IDEAL', 'PRIORIZAR', 'Equilibrio líquidos - Lupus', False),
    ('ALTAMENTE_ANTIINFLAMATORIO', 'PRIORIZAR', 'Altamente antiinflamatorio - Lupus', False),
    ('ANTIINFLAMATORIO', 'PRIORIZAR', 'Antiinflamatorio - Lupus', False),
    ('RICO_EN_OMEGA_3', 'PRIORIZAR', 'Rico en omega 3 - Lupus', False),
    ('BALANCE_DE_OMEGAS_FAVORABLE', 'PRIORIZAR', 'Balance omegas favorable - Lupus', False),
    ('ALTA_FUENTE_DE_FIBRA', 'PRIORIZAR', 'Alta fuente de fibra - Lupus', False),
    ('ALTO_PODER_ANTIOXIDANTE', 'PRIORIZAR', 'Alto poder antioxidante - Lupus', False),
    ('ALTA_FUENTE_DE_CALCIO', 'PRIORIZAR', 'Alta fuente de calcio - Lupus', False),
    ('ALTA_FUENTE_DE_VITAMINA_D', 'PRIORIZAR', 'Alta fuente de vit D - Lupus', False)
]

# Obtener IDs de etiquetas para lupus
etiqueta_codes_lupus = [r[0] for r in reglas_lupus]
placeholders = ','.join(['%s'] * len(etiqueta_codes_lupus))
cur.execute(f"SELECT id, codigo FROM nutricion.etiqueta_nutricional WHERE codigo IN ({placeholders})", etiqueta_codes_lupus)
etiquetas_map_lupus = {row['codigo']: row['id'] for row in cur.fetchall()}

rules_lupus_created = 0
for etiqueta_codigo, accion, mensaje, estricta in reglas_lupus:
    if etiqueta_codigo in etiquetas_map_lupus:
        cur.execute("""
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
            VALUES (%s, %s, %s, %s, %s, 'CLINICA')
            RETURNING id
        """, (acciones_map[accion], objetivo_id, etiquetas_map_lupus[etiqueta_codigo], f'[LUPUS] {mensaje}', estricta))
        regla_id = cur.fetchone()['id']
        
        cur.execute("""
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
            VALUES (%s, %s)
        """, (lupus_id, regla_id))
        rules_lupus_created += 1

print(f"   Reglas lupus creadas: {rules_lupus_created}")

conn.commit()

# 5. Verificación final
print("\n5. VERIFICACIÓN FINAL:")
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
total_reglas = cur.fetchone()['total']
print(f"   Total reglas: {total_reglas}")

cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion_regla")
total_relaciones = cur.fetchone()['total']
print(f"   Total relaciones: {total_relaciones}")

print("\n   Reglas por condición:")
cur.execute("""
    SELECT c.nombre, COUNT(cr.id_regla) as total
    FROM heuristico.condicion c
    LEFT JOIN heuristico.condicion_regla cr ON cr.id_condicion = c.id
    WHERE c.nombre IN ('Artritis Idiopatica Juvenil', 'Lupus Eritematoso Sistemico')
    GROUP BY c.nombre
""")
for row in cur.fetchall():
    print(f"     {row['nombre']}: {row['total']} reglas")

conn.close()
print("\n=== LIMPIEZA COMPLETADA ===")
print("Solo quedan las reglas reales para Artritis y Lupus.")
