import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv
import os

load_dotenv('C:/Users/mirya/Desktop/ReumaNutri vf/programatesis/backend/.env')
DB_URL = os.getenv('DATABASE_URL')

conn = psycopg.connect(DB_URL, row_factory=dict_row)
cur = conn.cursor()

print("=== CONFIGURACIÓN DE REGLAS REALES PARA ARTRITIS Y LUPUS ===\n")

# 1. Limpiar reglas de prueba (opcional - comentado por seguridad)
print("1. LIMPIEZA DE REGLAS EXISTENTES:")
# NO ejecutar automáticamente - requiere confirmación
# cur.execute("DELETE FROM heuristico.condicion_regla")
# cur.execute("DELETE FROM heuristico.regla")
# conn.commit()
print("  (OMITIDO - se agregarán reglas nuevas sin borrar existentes)")

# 2. Obtener IDs necesarios
print("\n2. OBTENIENDO IDS DE CATÁLOGOS:")

# Acciones
cur.execute("SELECT id, codigo FROM heuristico.catalogo_accion")
acciones = {row['codigo']: row['id'] for row in cur.fetchall()}
print(f"  Acciones: {acciones}")

# Objetivos
cur.execute("SELECT id, codigo FROM heuristico.catalogo_objetivo_regla")
objetivos = {row['codigo']: row['id'] for row in cur.fetchall()}
print(f"  Objetivos: {objetivos}")

# Condiciones
cur.execute("SELECT id, nombre FROM heuristico.condicion WHERE nombre ILIKE '%artritis%' OR nombre ILIKE '%lupus%'")
condiciones = {row['nombre']: row['id'] for row in cur.fetchall()}
print(f"  Condiciones: {condiciones}")

# Etiquetas (obtener IDs por código)
etiqueta_codes = [
    'GRASAS_TRANS_ELEVADAS', 'ALTAMENTE_INFLAMATORIO', 'ULTRAPROCESADO',
    'CONTIENE_GRASAS_TRANS', 'PROINFLAMATORIO', 'MODERADAMENTE_INFLAMATORIO',
    'ALTO_EN_GRASAS', 'MUY_ALTO_EN_GRASAS', 'ALTO_EN_AZÚCAR_AÑADIDO',
    'CALORÍAS_VACÍAS', 'REFINADO', 'ALTAMENTE_ANTIINFLAMATORIO',
    'ANTIINFLAMATORIO', 'LIGERAMENTE_ANTIINFLAMATORIO', 'RICO_EN_OMEGA_3',
    'BALANCE_DE_OMEGAS_FAVORABLE', 'ALTA_FUENTE_DE_CALCIO',
    'ALTA_FUENTE_DE_FIBRA', 'ALTO_PODER_ANTIOXIDANTE',
    'ALTA_FUENTE_DE_PROTEÍNA', 'MEDIA_FUENTE_DE_PROTEÍNA',
    'MUY_ALTO_EN_SODIO', 'RIESGO_DE_RETENCIÓN_DE_LÍQUIDOS',
    'ALTO_EN_SODIO', 'MODERADO_EN_SODIO', 'BAJO_EN_SODIO',
    'RIESGO_MODERADO_DE_RETENCIÓN', 'EQUILIBRIO_DE_LÍQUIDOS_IDEAL',
    'ALTA_FUENTE_DE_VITAMINA_D', 'ALTO_EN_GRASA_SATURADA',
    'BAJO_EN_GRASA_SATURADA', 'NATURAL_O_MINIMAMENTE_PROCESADO',
    'ALTO_INDICE_GLUCEMICO', 'BAJO_INDICE_GLUCEMICO',
    'ALTO_EN_POTASIO', 'BAJO_EN_POTASIO', 'ALTO_EN_FOSFORO', 'BAJO_EN_FOSFORO'
]

placeholders = ','.join(['%s'] * len(etiqueta_codes))
cur.execute(f"""
    SELECT id, codigo FROM nutricion.etiqueta_nutricional 
    WHERE codigo IN ({placeholders})
""", etiqueta_codes)
etiquetas = {row['codigo']: row['id'] for row in cur.fetchall()}
print(f"  Etiquetas encontradas: {len(etiquetas)} de {len(etiqueta_codes)}")

# 3. Definir reglas para Artritis Idiopática Juvenil
print("\n3. CREANDO REGLAS PARA ARTRITIS IDIOPÁTICA JUVENIL:")

artritis_id = condiciones.get('Artritis Idiopatica Juvenil')
rules_created = 0

if artritis_id:
    # Reglas ELIMINAR para artritis
    eliminar_artritis = [
        ('GRASAS_TRANS_ELEVADAS', 'Grasas trans elevadas - Artritis'),
        ('ALTAMENTE_INFLAMATORIO', 'Altamente inflamatorio - Artritis'),
        ('ULTRAPROCESADO', 'Ultraprocesado - Artritis')
    ]
    
    for etiqueta_codigo, mensaje in eliminar_artritis:
        if etiqueta_codigo in etiquetas:
            cur.execute("""
                INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (acciones['ELIMINAR'], objetivos['ETIQUETA'], etiquetas[etiqueta_codigo], 
                 f'[ARTRITIS] {mensaje}', True, 'CLINICA'))
            regla_id = cur.fetchone()['id']
            
            # Relacionar con condición
            cur.execute("""
                INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
                VALUES (%s, %s)
            """, (artritis_id, regla_id))
            rules_created += 1
            print(f"  -> ELIMINAR: {etiqueta_codigo}")
    
    # Reglas DISMINUIR para artritis
    disminuir_artritis = [
        ('CONTIENE_GRASAS_TRANS', 'Contiene grasas trans - Artritis'),
        ('PROINFLAMATORIO', 'Proinflamatorio - Artritis'),
        ('MODERADAMENTE_INFLAMATORIO', 'Moderadamente inflamatorio - Artritis'),
        ('ALTO_EN_GRASAS', 'Alto en grasas - Artritis'),
        ('MUY_ALTO_EN_GRASAS', 'Muy alto en grasas - Artritis'),
        ('ALTO_EN_AZÚCAR_AÑADIDO', 'Alto en azúcar añadido - Artritis'),
        ('CALORÍAS_VACÍAS', 'Calorías vacías - Artritis'),
        ('REFINADO', 'Refinado - Artritis')
    ]
    
    for etiqueta_codigo, mensaje in disminuir_artritis:
        if etiqueta_codigo in etiquetas:
            cur.execute("""
                INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (acciones['DISMINUIR'], objetivos['ETIQUETA'], etiquetas[etiqueta_codigo], 
                 f'[ARTRITIS] {mensaje}', False, 'CLINICA'))
            regla_id = cur.fetchone()['id']
            
            cur.execute("""
                INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
                VALUES (%s, %s)
            """, (artritis_id, regla_id))
            rules_created += 1
            print(f"  -> DISMINUIR: {etiqueta_codigo}")
    
    # Reglas PRIORIZAR para artritis
    priorizar_artritis = [
        ('ALTAMENTE_ANTIINFLAMATORIO', 'Altamente antiinflamatorio - Artritis'),
        ('ANTIINFLAMATORIO', 'Antiinflamatorio - Artritis'),
        ('LIGERAMENTE_ANTIINFLAMATORIO', 'Ligeramente antiinflamatorio - Artritis'),
        ('RICO_EN_OMEGA_3', 'Rico en omega 3 - Artritis'),
        ('BALANCE_DE_OMEGAS_FAVORABLE', 'Balance de omegas favorable - Artritis'),
        ('ALTA_FUENTE_DE_CALCIO', 'Alta fuente de calcio - Artritis'),
        ('ALTA_FUENTE_DE_FIBRA', 'Alta fuente de fibra - Artritis'),
        ('ALTO_PODER_ANTIOXIDANTE', 'Alto poder antioxidante - Artritis'),
        ('ALTA_FUENTE_DE_PROTEÍNA', 'Alta fuente de proteína - Artritis'),
        ('MEDIA_FUENTE_DE_PROTEÍNA', 'Media fuente de proteína - Artritis')
    ]
    
    for etiqueta_codigo, mensaje in priorizar_artritis:
        if etiqueta_codigo in etiquetas:
            cur.execute("""
                INSERT INTO heuristico.regla (id_accion, id_tipo_objetivo, id_etiqueta, mensaje_error, es_estricta, origen_regla)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (acciones['PRIORIZAR'], objetivos['ETIQUETA'], etiquetas[etiqueta_codigo], 
                 f'[ARTRITIS] {mensaje}', False, 'CLINICA'))
            regla_id = cur.fetchone()['id']
            
            cur.execute("""
                INSERT INTO heuristico.condicion_regla (id_condicion, id_regla)
                VALUES (%s, %s)
            """, (artritis_id, regla_id))
            rules_created += 1
            print(f"  -> PRIORIZAR: {etiqueta_codigo}")

print(f"  Total reglas artritis creadas: {rules_created}")

conn.commit()
print("\n=== REGLAS PARA ARTRITIS COMPLETADAS ===")
