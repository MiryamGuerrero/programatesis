from datetime import date
from uuid import uuid4
from app.core.db import db_cursor
from app.services.shared.cerebro.clasificacion_estado_nutricional_oms.oms_engine import calcular_imc, obtener_clasificacion_oms

def _obtener_id_usuario_interno(auth_id: str) -> str:
    if not auth_id: return None
    with db_cursor() as cur:
        cur.execute("SELECT id FROM usuarios.usuario WHERE auth_user_id = %s OR id::text = %s", (auth_id, auth_id))
        row = cur.fetchone()
        return str(row[0]) if row else None

def registrar_control_clinico(data: dict) -> int:
    """
    Registra o actualiza el control clínico. 
    Lógica MANUAL de verificación para evitar errores de ON CONFLICT.
    """
    paciente_id = data['id_paciente']
    hoy = date.today()
    
    id_medico_interno = _obtener_id_usuario_interno(data.get('id_medico'))
    id_nutri_interno = _obtener_id_usuario_interno(data.get('id_nutricionista'))
    
    with db_cursor() as cur:
        # 1. OMS
        cur.execute("SELECT id_sexo, fecha_nacimiento FROM usuarios.paciente WHERE id = %s", (paciente_id,))
        row_p = cur.fetchone()
        if not row_p: raise ValueError("Paciente no encontrado")
        sexo, fnac = row_p
        
        edad_meses = (hoy.year - fnac.year) * 12 + hoy.month - fnac.month
        if hoy.day < fnac.day: edad_meses -= 1

        peso = data.get('peso_kg')
        talla = data.get('talla_cm')
        
        imc, diag_oms, id_condicion_nutri = None, None, None
        if peso and talla and float(peso) > 0 and float(talla) > 0:
            imc = calcular_imc(float(peso), float(talla))
            res_oms = obtener_clasificacion_oms(sexo, edad_meses, imc)
            diag_oms = res_oms['clasificacion']
            cur.execute("SELECT id FROM heuristico.condicion WHERE nombre = %s AND id_tipo_condicion = 3", (diag_oms,))
            row_c = cur.fetchone()
            if row_c: id_condicion_nutri = row_c[0]

        # 2. Control Paciente (Búsqueda manual)
        cur.execute("SELECT id FROM clinico.control_paciente WHERE id_paciente = %s AND fecha_control = %s", (paciente_id, hoy))
        row_ctrl = cur.fetchone()

        if row_ctrl:
            id_control = row_ctrl[0]
            cur.execute("""
                UPDATE clinico.control_paciente SET
                    peso_kg = %s, talla_cm = %s, edad_meses = %s, imc_calculado = %s,
                    id_condicion_nutricional_resultado = %s, diagnostico_oms_texto = %s,
                    nivel_dolor_eva = %s, nivel_inflamacion = %s, nivel_fatiga = %s,
                    minutos_rigidez_matutina = %s, inflamacion_pcr = %s, hay_brote_activo = %s,
                    nota_evolucion = %s, id_medico = COALESCE(id_medico, %s), 
                    id_nutricionista = COALESCE(id_nutricionista, %s)
                WHERE id = %s
            """, (peso, talla, edad_meses, imc, id_condicion_nutri, diag_oms,
                  data.get('nivel_dolor_eva'), data.get('nivel_inflamacion'), data.get('nivel_fatiga'),
                  data.get('minutos_rigidez_matutina'), data.get('inflamacion_pcr'), data.get('hay_brote_activo'),
                  data.get('nota_evolucion'), id_medico_interno, id_nutri_interno, id_control))
        else:
            cur.execute("""
                INSERT INTO clinico.control_paciente (
                    id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, 
                    imc_calculado, id_condicion_nutricional_resultado, diagnostico_oms_texto,
                    nivel_dolor_eva, nivel_inflamacion, nivel_fatiga, minutos_rigidez_matutina,
                    inflamacion_pcr, hay_brote_activo, nota_evolucion, id_medico, id_nutricionista
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (paciente_id, hoy, peso, talla, edad_meses, imc, id_condicion_nutri, diag_oms,
                  data.get('nivel_dolor_eva'), data.get('nivel_inflamacion'), data.get('nivel_fatiga'),
                  data.get('minutos_rigidez_matutina'), data.get('inflamacion_pcr'), data.get('hay_brote_activo'),
                  data.get('nota_evolucion'), id_medico_interno, id_nutri_interno))
            id_control = cur.fetchone()[0]

        # 3. Sincronización de Condiciones (SIN ON CONFLICT)
        cur.execute("DELETE FROM clinico.control_condicion_activa WHERE id_control = %s", (id_control,))
        
        ids_enviados = set(data.get('id_condiciones_activas', []))
        if id_condicion_nutri: ids_enviados.add(id_condicion_nutri)

        if ids_enviados:
            cur.execute("""
                SELECT c.id, lower(t.codigo) as tipo
                FROM heuristico.condicion c
                JOIN heuristico.catalogo_tipo_condicion t ON t.id = c.id_tipo_condicion
                WHERE c.id = ANY(%s)
            """, (list(ids_enviados),))
            cond_map = {r[0]: r[1] for r in cur.fetchall()}

            for cid in ids_enviados:
                # 3a. Control actual
                cur.execute("INSERT INTO clinico.control_condicion_activa (id_control, id_condicion) VALUES (%s, %s)", (id_control, cid))
                
                # 3b. Diagnóstico permanente (Clínica o Nutricional)
                if cond_map.get(cid) in ['clinica', 'nutricional']:
                    cur.execute("SELECT id FROM clinico.diagnostico_paciente WHERE id_paciente = %s AND id_condicion = %s", (paciente_id, cid))
                    if cur.fetchone():
                        cur.execute("UPDATE clinico.diagnostico_paciente SET activa = true, fecha_diagnostico = CURRENT_DATE WHERE id_paciente = %s AND id_condicion = %s", (paciente_id, cid))
                    else:
                        cur.execute("""
                            INSERT INTO clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, activa)
                            VALUES (%s, %s, CURRENT_DATE, %s, true)
                        """, (paciente_id, cid, (cond_map.get(cid) == 'clinica')))

                # 3c. Temporal
                if cond_map.get(cid) == 'temporal':
                    cur.execute("SELECT id FROM clinico.restriccion_temporal_paciente WHERE id_paciente = %s AND id_condicion = %s AND activa = true", (paciente_id, cid))
                    if not cur.fetchone():
                        cur.execute("""
                            INSERT INTO clinico.restriccion_temporal_paciente (id_paciente, id_condicion, fecha_inicio, fecha_fin, activa, accion_codigo, motivo)
                            VALUES (%s, %s, CURRENT_DATE, CURRENT_DATE + interval '15 days', true, 'ELIMINAR', 'Agregado desde control clínico')
                        """, (paciente_id, cid))

        # 4. Alergias en Control
        al_ing = data.get('alergias_ingredientes', [])
        al_sub = data.get('alergias_subgrupos', [])
        print(f"[DEBUG GESTION] Registrando control para {paciente_id} con {len(al_ing)} alergias ing y {len(al_sub)} alergias sub")
        
        for id_ing in al_ing:
            cur.execute("""
                INSERT INTO clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, activa, fecha_registro, observacion) 
                VALUES (%s, %s, true, CURRENT_DATE, 'Actualizado en Control')
                ON CONFLICT (id_paciente, id_ingrediente) DO UPDATE SET activa = true
            """, (paciente_id, id_ing))
        for id_sub in al_sub:
            cur.execute("""
                INSERT INTO clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, activa, fecha_registro, observacion) 
                VALUES (%s, %s, true, CURRENT_DATE, 'Actualizado en Control')
                ON CONFLICT (id_paciente, id_subgrupo_alimentario) DO UPDATE SET activa = true
            """, (paciente_id, id_sub))

        cur.execute("UPDATE usuarios.paciente SET fecha_ultimo_control = %s WHERE id = %s", (hoy, paciente_id))
        print(f"[DEBUG GESTION] Control {id_control} finalizado exitosamente")
        return id_control

def registrar_paciente_full(data: dict) -> str:
    with db_cursor() as cur:
        # Tutor
        tutor_id = data.get('id_tutor')
        if not tutor_id:
            cur.execute("SELECT id FROM usuarios.usuario WHERE cedula = %s", (data.get('tutor_cedula'),))
            row_t = cur.fetchone()
            if row_t: tutor_id = row_t[0]
            else:
                tutor_id = uuid4()
                cur.execute("""
                    INSERT INTO usuarios.usuario (id, cedula, nombre_completo, email, id_rol) 
                    VALUES (%s, %s, %s, %s, (SELECT id FROM usuarios.rol WHERE lower(codigo)='tutor'))
                """, (tutor_id, data.get('tutor_cedula'), data.get('tutor_nombre'), data.get('tutor_email')))
        
        # Paciente
        cur.execute("""
            INSERT INTO usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_provincia, enfermedad_principal) 
            VALUES (%s, %s, %s, %s, %s) RETURNING id
        """, (data['nombre'], data['fecha_nacimiento'], data['id_sexo'], data.get('id_provincia'), data.get('enfermedad_principal')))
        paciente_id = cur.fetchone()[0]
        
        cur.execute("INSERT INTO usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal) VALUES (%s, %s, %s, true)", (tutor_id, paciente_id, data.get('id_parentesco')))

        # Alergias (Manual check)
        al_ing = data.get('alergias_ingredientes', [])
        al_sub = data.get('alergias_subgrupos', [])
        print(f"[DEBUG GESTION] Registrando paciente {paciente_id} con {len(al_ing)} alergias ing y {len(al_sub)} alergias sub")
        
        for id_ing in al_ing:
            cur.execute("""
                INSERT INTO clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, activa, fecha_registro, observacion) 
                VALUES (%s, %s, true, CURRENT_DATE, 'Ingreso')
                ON CONFLICT (id_paciente, id_ingrediente) DO UPDATE SET activa = true
            """, (paciente_id, id_ing))
        for id_sub in al_sub:
            cur.execute("""
                INSERT INTO clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, activa, fecha_registro, observacion) 
                VALUES (%s, %s, true, CURRENT_DATE, 'Ingreso')
                ON CONFLICT (id_paciente, id_subgrupo_alimentario) DO UPDATE SET activa = true
            """, (paciente_id, id_sub))
        
        print(f"[DEBUG GESTION] Paciente {data['nombre']} registrado exitosamente")
        return str(paciente_id)

def get_patient_management_catalogs() -> dict:
    with db_cursor() as cur:
        cur.execute("SELECT id, descripcion FROM usuarios.catalogo_sexo")
        sexos = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        cur.execute("SELECT id, nombre FROM usuarios.provincia ORDER BY nombre")
        provincias = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        cur.execute("SELECT id, nombre FROM usuarios.parentesco ORDER BY id")
        parentescos = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        cur.execute("SELECT id, nombre FROM heuristico.condicion WHERE id_tipo_condicion = 1 AND activa = true ORDER BY nombre")
        condiciones_clinicas = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        cur.execute("SELECT id, nombre FROM nutricion.subgrupo_alimentario ORDER BY nombre")
        subgrupos = [{"id": r[0], "nombre": r[1]} for r in cur.fetchall()]
        return {"sexos": sexos, "provincias": provincias, "parentescos": parentescos, "condiciones_clinicas": condiciones_clinicas, "subgrupos": subgrupos}

def eliminar_paciente_full(paciente_id: str) -> bool:
    with db_cursor() as cur:
        cur.execute("DELETE FROM interaccion.plan_item WHERE id_plan IN (SELECT id FROM interaccion.plan_nutricional WHERE id_paciente = %s)", (paciente_id,))
        cur.execute("DELETE FROM clinico.alergia_paciente_ingrediente WHERE id_paciente = %s", (paciente_id,))
        cur.execute("DELETE FROM clinico.alergia_paciente_subgrupo WHERE id_paciente = %s", (paciente_id,))
        cur.execute("DELETE FROM clinico.diagnostico_paciente WHERE id_paciente = %s", (paciente_id,))
        cur.execute("DELETE FROM clinico.control_paciente WHERE id_paciente = %s", (paciente_id,))
        cur.execute("DELETE FROM usuarios.tutor_paciente WHERE id_paciente = %s", (paciente_id,))
        cur.execute("DELETE FROM usuarios.paciente WHERE id = %s", (paciente_id,))
        return cur.rowcount > 0

def buscar_pacientes_gestion(query: str = "") -> list[dict]:
    sql = """
        SELECT p.id, p.nombre_completo, p.fecha_nacimiento, s.descripcion as sexo, 
               p.enfermedad_principal, p.fecha_ultimo_control, u.nombre_completo as tutor, u.telefono as tel
        FROM usuarios.paciente p
        JOIN usuarios.catalogo_sexo s ON s.id = p.id_sexo
        LEFT JOIN usuarios.tutor_paciente tp ON tp.id_paciente = p.id AND tp.es_principal = true
        LEFT JOIN usuarios.usuario u ON u.id = tp.id_usuario_tutor
        WHERE p.nombre_completo ILIKE %s
        ORDER BY p.nombre_completo ASC
    """
    with db_cursor() as cur:
        cur.execute(sql, (f"%{query}%",))
        return [{"id": str(r[0]), "nombre": r[1], "fecha_nacimiento": str(r[2]), "sexo": r[3], "enfermedad": r[4], "ultimo_control": str(r[5]) if r[5] else "Nunca", "tutor": r[6], "tutor_telefono": r[7]} for r in cur.fetchall()]

def buscar_tutor_por_cedula(cedula: str) -> dict:
    sql = "SELECT id, nombre_completo, email, telefono, direccion FROM usuarios.usuario WHERE TRIM(cedula) = TRIM(%s) AND id_rol = (SELECT id FROM usuarios.rol WHERE lower(codigo)='tutor')"
    with db_cursor() as cur:
        cur.execute(sql, (cedula,))
        r = cur.fetchone()
        if r: return {"id": str(r[0]), "nombre": r[1], "email": r[2], "telefono": r[3], "direccion": r[4], "existe": True}
        return {"existe": False}

def guardar_alergias_y_temporales_full(paciente_id: str, ingredientes: list[int], grupos: list[int], temporales: list[dict]):
    with db_cursor() as cur:
        cur.execute("DELETE FROM clinico.alergia_paciente_ingrediente WHERE id_paciente = %s", (paciente_id,))
        for id_ing in ingredientes: 
            cur.execute("INSERT INTO clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, activa, fecha_registro) VALUES (%s, %s, true, CURRENT_DATE)", (paciente_id, id_ing))
        cur.execute("DELETE FROM clinico.alergia_paciente_subgrupo WHERE id_paciente = %s", (paciente_id,))
        for id_sub in grupos: 
            cur.execute("INSERT INTO clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, activa, fecha_registro) VALUES (%s, %s, true, CURRENT_DATE)", (paciente_id, id_sub))
        cur.execute("UPDATE clinico.restriccion_temporal_paciente SET activa = false WHERE id_paciente = %s", (paciente_id,))
        for temp in temporales: 
            cur.execute("""
                INSERT INTO clinico.restriccion_temporal_paciente (id_paciente, id_condicion, fecha_inicio, fecha_fin, activa, accion_codigo, motivo) 
                VALUES (%s, %s, CURRENT_DATE, %s, true, 'ELIMINAR', 'Restricción por condición temporal')
            """, (paciente_id, temp['id'], temp['fecha_fin']))
