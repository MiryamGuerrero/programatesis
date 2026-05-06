import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== CONFIGURACIÓN DE REGLAS REALES PARA LUPUS ===\n")

# 1. Obtener IDs necesarios
print("1. OBTENIENDO IDS:")

# Acciones
cur.execute("SELECT id, codigo FROM heuristico.catalogo_accion")
acciones = {row['codigo']: row['id'] for row in cur.fetchall()}

# Objetivos
cur.execute("SELECT id, codigo FROM heuristico.catalogo_objetivo_regla")
objetivos = {row['codigo']: row['id'] for row in cur.fetchall()}

# Condición lupus
cur.execute("SELECT id FROM heuristico.condicion WHERE nombre = 'Lupus Eritematoso Sistemico'")
lupus_id = cur.fetchone()['id']

# Etiquetas
etiqueta_codes = [
    'MUY_ALTO_EN_SODIO', 'RIESGO_DE_RETENCION_DE_LÍQUIDOS', 'GRASAS_TRANS_ELEVADAS',
    'ALTAMENTE_INFLAMATORIO', 'ULTRAPROCESADO', 'ALTO_EN_SODIO', 'MODERADO_EN_SODIO',
    'RIESGO_MODERADO_DE_RETENCION', 'CONTIENE_GRASAS_TRANS', 'ALTO_EN_GRASAS',
    'MUY_ALTO_EN_GRASAS', 'ALTO_EN_AZÚCAR_AÑADIDO', 'CALORÍAS_VACÍAS', 'REFINADO',
    'PROINFLAMATORIO', 'MODERADAMENTE_INFLAMATORIO', 'BAJO_EN_SODIO',
    'EQUILIBRIO_DE_LÍQUIDOS_IDEAL', 'ALTAMENTE_ANTIINFLAMATORIO', 'ANTIINFLAMATORIO',
    'RICO_EN_OMEGA_3', 'BALANCE_DE_OMEGAS_FAVORABLE', 'ALTA_FUENTE_DE_FIBRA',
    'ALTO_PODER_ANTIOXIDANTE', 'ALTA_FUENTE_DE_CALCIO', 'ALTA_FUENTE_DE_VITAMINA_D'
]

placeholders = ','.join(['%s'] * len(etiqueta_codes))
cur.execute(f"""
    SELECT id, codigo FROM nutricion.etiqueta_nutricional 
    WHERE codigo IN ({placeholders})
""", etiqueta_codes)
etiquetas = {row['codigo']: row['id'] for row in cur.fetchall()}

print(f"   Acciones: {len(acciones)}")
print(f"   Objetivos: {len(objetivos)}")
print(f"   Lupus ID: {lupus_id}")
print(f"   Etiquetas encontradas: {len(etiquetas)}")

# 2. Crear reglas ELIMINAR para lupus
print("\n2. CREANDO REGLAS ELIMINAR:")
eliminar_lupus = [
    ('MUY_ALTO_EN_SODIO', 'Muy alto en sodio - Lupus'),
    ('RIESGO_DE_RETENCION_DE_LÍQUIDOS', 'Riesgo de retención - Lupus'),
    ('GRASAS_TRANS_ELEVADAS', 'Grasas trans elevadas - Lupus'),
    ('ALTAMENTE_INFLAMATORIO', 'Altamente inflamatorio - Lupus'),
    ('ULTRAPROCESADO', 'Ultraprocesado - Lupus')
]

rules_created = 0
for etiqueta_codigo, mensaje in eliminar_lupus:
    if etiqueta_codigo in etiquetas:
        cur.execute("""
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (acciones['ELIMINAR'], objetivos['ETIQUETA'], etiquetas[etiqueta_codigo], 
                 f'[LUPUS] {mensaje}', True, 'CLINICA'))
        regla_id = cur.fetchone()['id']
        
        cur.execute("""
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
            VALUES (%s, %s)
        """, (lupus_id, regla_id))
        rules_created += 1
        print(f"   -> ELIMINAR: {etiqueta_codigo}")

# 3. Crear reglas DISMINUIR para lupus
print("\n3. CREANDO REGLAS DISMINUIR:")
disminuir_lupus = [
    ('ALTO_EN_SODIO', 'Alto en sodio - Lupus'),
    ('MODERADO_EN_SODIO', 'Moderado en sodio - Lupus'),
    ('RIESGO_MODERADO_DE_RETENCION', 'Riesgo moderado de retención - Lupus'),
    ('CONTIENE_GRASAS_TRANS', 'Contiene grasas trans - Lupus'),
    ('ALTO_EN_GRASAS', 'Alto en grasas - Lupus'),
    ('MUY_ALTO_EN_GRASAS', 'Muy alto en grasas - Lupus'),
    ('ALTO_EN_AZÚCAR_AÑADIDO', 'Alto en azúcar añadido - Lupus'),
    ('CALORÍAS_VACÍAS', 'Calorías vacías - Lupus'),
    ('REFINADO', 'Refinado - Lupus'),
    ('PROINFLAMATORIO', 'Proinflamatorio - Lupus'),
    ('MODERADAMENTE_INFLAMATORIO', 'Moderadamente inflamatorio - Lupus')
]

for etiqueta_codigo, mensaje in disminuir_lupus:
    if etiqueta_codigo in etiquetas:
        cur.execute("""
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (acciones['DISMINUIR'], objetivos['ETIQUETA'], etiquetas[etiqueta_codigo], 
                 f'[LUPUS] {mensaje}', False, 'CLINICA'))
        regla_id = cur.fetchone()['id']
        
        cur.execute("""
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
            VALUES (%s, %s)
        """, (lupus_id, regla_id))
        rules_created += 1
        print(f"   -> DISMINUIR: {etiqueta_codigo}")

# 4. Crear reglas PRIORIZAR para lupus
print("\n4. CREANDO REGLAS PRIORIZAR:")
priorizar_lupus = [
    ('BAJO_EN_SODIO', 'Bajo en sodio - Lupus'),
    ('EQUILIBRIO_DE_LÍQUIDOS_IDEAL', 'Equilibrio de líquidos - Lupus'),
    ('ALTAMENTE_ANTIINFLAMATORIO', 'Altamente antiinflamatorio - Lupus'),
    ('ANTIINFLAMATORIO', 'Antiinflamatorio - Lupus'),
    ('RICO_EN_OMEGA_3', 'Rico en omega 3 - Lupus'),
    ('BALANCE_DE_OMEGAS_FAVORABLE', 'Balance de omegas favorable - Lupus'),
    ('ALTA_FUENTE_DE_FIBRA', 'Alta fuente de fibra - Lupus'),
    ('ALTO_PODER_ANTIOXIDANTE', 'Alto poder antioxidante - Lupus'),
    ('ALTA_FUENTE_DE_CALCIO', 'Alta fuente de calcio - Lupus'),
    ('ALTA_FUENTE_DE_VITAMINA_D', 'Alta fuente de vitamina D - Lupus')
]

for etiqueta_codigo, mensaje in priorizar_lupus:
    if etiqueta_codigo in etiquetas:
        cur.execute("""
            INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (acciones['PRIORIZAR'], objetivos['ETIQUETA'], etiquetas[etiqueta_codigo], 
                 f'[LUPUS] {mensaje}', False, 'CLINICA'))
        regla_id = cur.fetchone()['id']
        
        cur.execute("""
            INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
            VALUES (%s, %s)
        """, (lupus_id, regla_id))
        rules_created += 1
        print(f"   -> PRIORIZAR: {etiqueta_codigo}")

conn.commit()
print(f"\n=== RESUMEN ===")
print(f"Total reglas lupus creadas: {rules_created}")
print(f"Total reglas en la base: {17 + rules_created}")

# Verificar total de reglas
cur.execute("SELECT COUNT(*) as total FROM heuristico.regla")
total_reglas = cur.fetchone()['total']
print(f"Total actual en tabla regla: {total_reglas}")

# Verificar relaciones
cur.execute("SELECT COUNT(*) as total FROM heuristico.condicion_regla")
total_relaciones = cur.fetchone()['total']
print(f"Total relaciones condicion-regla: {total_relaciones}")

conn.close()
print("\n=== CONFIGURACIÓN COMPLETADA ===")
