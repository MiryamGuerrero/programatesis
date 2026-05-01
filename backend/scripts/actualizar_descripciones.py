import psycopg2

conn = psycopg2.connect(
    host='db.yuasobxhctmukvozmrta.supabase.co',
    database='postgres',
    user='postgres',
    password='AyT0kw4euSkcacOA',
    port=5432
)
cursor = conn.cursor()

print('=== ACTUALIZANDO DESCRIPCIONES DE CONDICIONES ===\n')

# 1. CONDICIONES NUTRICIONALES (Z-SCORE)
print('1. Actualizando descripciones nutricionales...\n')

# Z < -3: Tallla baja severa, Bajo peso severo, Delgadez severa
updates_nutricional = [
    (23, 'Talla baja severa: Z-score < -3. Requiere intervencion nutricional urgente para recuperar crecimiento.'),
    (27, 'Talla baja severa: Z-score < -3. Requiere intervencion nutricional urgente para recuperar crecimiento.'),
    (107, 'Delgadez severa: Z-score < -3. Desnutricion grave con riesgo de compromiso inmunologico.'),
    (100, 'Bajo peso severo: Z-score < -3. Desnutricion severa con riesgo de morbilidad.'),
    
    # Z -3 a -2: Talla baja, Bajo peso, Delgadez
    (24, 'Talla baja: Z-score -3 a -2. Requiere aumento de ingesta calorica y proteica para recuperar crecimiento.'),
    (28, 'Bajo peso: Z-score -3 a -2. Requiere aumento de ingesta calorica y proteica para recuperar peso.'),
    (106, 'Delgadez: Z-score -3 a -2. Desnutricion moderada que requiere aumento de ingesta nutricional.'),
    (101, 'Desnutricion Moderada: Estado nutricional comprometido que requiere aumento de ingesta proteico-calorica.'),
    
    # Z -2 a +1: Normal, Peso normal, Talla adecuada
    (29, 'Peso normal: Z-score -2 a +1. Estado nutricional optimo que requiere mantenimiento de dieta equilibrada.'),
    (103, 'Normal: Z-score -2 a +1. Estado nutricional adecuado para la edad y sexo.'),
    (25, 'Talla adecuada para la edad: Z-score -2 a +3. Crecimiento normal, requiere mantenimiento de dieta equilibrada.'),
    (102, 'Riesgo de Desnutricion: Estado nutricional limite que requiere vigilancia y prevencion.'),
    
    # Z +1 a +2: Sobrepeso, Peso elevado
    (104, 'Sobrepeso: Z-score +1 a +2. Exceso de peso que requiere disminucion de grasas y carbohidratos refinados.'),
    (30, 'Peso elevado para la edad: Z-score > +2. Riesgo de obesidad, requiere control de ingesta calorica.'),
    (105, 'Obesidad: Z-score > +2. Exceso de peso severo que requiere intervencion nutricional inmediata.'),
    
    # Z > +3: Talla muy alta
    (26, 'Talla muy alta para la edad: Z-score > +3. Crecimiento acelerado que requiere monitoreo y adecuacion de calcio.')
]

for cond_id, desc in updates_nutricional:
    cursor.execute('UPDATE heuristico.condicion SET descripcion = %s WHERE id = %s', (desc, cond_id))
    print(f'  Actualizada condicion [{cond_id}]: {desc[:60]}...')

# 2. CONDICIONES TEMPORALES (que no tienen descripcion)
print('\n2. Actualizando descripciones temporales...\n')

updates_temporales = [
    (15, 'Infeccion respiratoria por virus. Requiere hidratacion y dieta blanda por 3-5 dias.'),
    (16, 'Diarrea aguda con riesgo de deshidratacion. Requiere dieta astringente y rehidratacion oral inmediata.'),
    (17, 'Nauseas y vomitos de origen gastrointestinal. Requiere dieta fraccionada suave por 24-48 horas.'),
    (18, 'Estrenimiento temporal por cambios dieteticos. Requiere aumento de fibra y liquidos por 48-72 horas.'),
    (19, 'Infeccion de garganta (faringitis/amigdalitis). Requiere dieta suave y liquidos templados por 5-7 dias.'),
    (20, 'Fiebre de origen infeccioso. Requiere hidratacion constante (2.5-3L/dia) y monitoreo por 24-48 horas.'),
    (21, 'Falta de apetito por enfermedad aguda. Requiere dieta fraccionada densa en nutrientes por 3-5 dias.'),
    (22, 'Brote articular agudo de enfermedad reumatica. Requiere eliminacion de inflamatorios y aumento de antiinflamatorios inmediatamente.')
]

for cond_id, desc in updates_temporales:
    cursor.execute('UPDATE heuristico.condicion SET descripcion = %s WHERE id = %s', (desc, cond_id))
    print(f'  Actualizada condicion [{cond_id}]: {desc[:60]}...')

conn.commit()

print('\n=== VERIFICACION FINAL ===\n')
cursor.execute("""
    SELECT c.id, c.nombre, c.descripcion, tc.nombre as tipo
    FROM heuristico.condicion c
    JOIN heuristico.catalogo_tipo_condicion tc ON tc.id = c.id_tipo_condicion
    WHERE c.activa = true
    ORDER BY tc.id, c.id
""")

print('TODAS LAS CONDICIONES CON DESCRIPCION:\n')
current_tipo = None
for row in cursor.fetchall():
    if row[3] != current_tipo:
        current_tipo = row[3]
        print(f'\n--- {current_tipo} ---')
    
    desc = row[2][:80] + '...' if row[2] and len(row[2]) > 80 else row[2]
    print(f'  [{row[0]}] {row[1]}')
    print(f'      {desc}')

# Verificar que no queden sin descripcion
cursor.execute("""
    SELECT COUNT(*) 
    FROM heuristico.condicion 
    WHERE (descripcion IS NULL OR descripcion = '') AND activa = true
""")
sin_desc = cursor.fetchone()[0]

print(f'\n=== RESUMEN ===')
print(f'Condiciones sin descripcion restantes: {sin_desc}')

conn.close()
print('\n✅ ACTUALIZACION DE DESCRIPCIONES COMPLETADA')
