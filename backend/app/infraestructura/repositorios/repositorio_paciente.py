from typing import Optional, List, Dict, Any, Tuple, Set
from datetime import date, datetime, timedelta
from ...core.db import db_cursor
from ...domain.modelos.paciente import PerfilPaciente
from ...domain.repositorios.interfaces import IRepositorioPaciente
from ...domain.servicios.servicio_oms import ServicioOMS

class RepositorioPacientePostgres(IRepositorioPaciente):
    
    def _calcular_edad_meses(self, fecha_nacimiento: date) -> int:
        _, meses = ServicioOMS.calcular_edad_detallada(fecha_nacimiento)
        return meses

    def _obtener_ids_lacteos(self) -> Set[int]:
        """Subgrupos que contienen lactosa y deben bloquearse para intolerantes."""
        return {
            98,   # Leches animales (con lactosa)
            100,  # Natas y cremas de leche (con lactosa)
            101,  # Yogures animales (con lactosa)
            104,  # Leches fermentadas animales (con lactosa)
            105,  # Quesos frescos (con lactosa)
            108,  # Quesos procesados y en lonchas (con lactosa)
            111,  # Mantequillas (lacteo, con lactosa)
            114,  # Salsas con lacteos (con lactosa)
            117,  # Chocolates con leche (con lactosa)
            119,  # Dulces con lacteos (con lactosa)
        }

    def obtener_por_id(self, id_paciente: str) -> Optional[PerfilPaciente]:
        with db_cursor() as cur:
            cur.execute("select id, nombre_completo, fecha_nacimiento, id_sexo, cedula from usuarios.paciente where id = %s and activo = true", (id_paciente,))
            row = cur.fetchone()
            if not row: return None
            cur.execute("select id_condicion from clinico.diagnostico_paciente where id_paciente = %s and esta_activo = true union select id_condicion from clinico.control_condicion_activa where id_control = (select id from clinico.control_paciente where id_paciente = %s order by fecha_control desc limit 1)", (id_paciente, id_paciente))
            condiciones = [r[0] for r in cur.fetchall()]
            return PerfilPaciente(id_paciente=str(row[0]), nombre=row[1], fecha_nacimiento=row[2], id_sexo=row[3], cedula=row[4], condiciones_activas=condiciones)

    def buscar_pacientes(self, consulta: str, limite: int = 50) -> List[dict]:
        with db_cursor() as cur:
            term = f"%{consulta}%"
            sql = """
                select id, nombre_completo, cedula, enfermedad_principal, edad_anios, severidad, condicion_nutricional
                from usuarios.vista_gestion_pacientes
                where (nombre_completo ilike %s or cedula ilike %s or id::text ilike %s)
                limit %s
            """
            cur.execute(sql, (term, term, term, limite))
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def listar_todos_pacientes(self) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select v.*, p.id_sexo
                from usuarios.vista_gestion_pacientes v
                join usuarios.paciente p on p.id = v.id
                order by v.nombre_completo
            """
            cur.execute(sql)
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def obtener_expediente_completo(self, id_paciente: str) -> dict:
        with db_cursor() as cur:
            cur.execute("""
                select p.*, s.descripcion as sexo_nombre, 
                       c.nombre as canton_nombre, 
                       parr.nombre as parroquia_nombre 
                from usuarios.paciente p 
                left join usuarios.catalogo_sexo s on s.id = p.id_sexo 
                left join usuarios.canton c on c.id = p.id_canton 
                left join usuarios.parroquia parr on parr.id = p.id_parroquia 
                where p.id = %s
            """, (id_paciente,))
            pac_row = cur.fetchone()
            if not pac_row: return {"error": "No existe"}
            pac_cols = [d[0] for d in cur.description]
            paciente = dict(zip(pac_cols, pac_row))
            # Obtener enfermedad principal del diagnóstico activo
            cur.execute("select c.nombre from clinico.diagnostico_paciente dp join heuristico.condicion c on c.id = dp.id_condicion where dp.id_paciente = %s and dp.esta_activo = true limit 1", (id_paciente,))
            res_enf = cur.fetchone()
            paciente["enfermedad_principal"] = res_enf[0] if res_enf else "AIJ"
            
            cur.execute("select u.nombre_completo, u.email, u.cedula, u.telefono, u.direccion, tp.id_parentesco, par.nombre as parentesco_nombre from usuarios.tutor_paciente tp join usuarios.usuario u on u.id = tp.id_usuario_tutor join usuarios.parentesco par on par.id = tp.id_parentesco where tp.id_paciente = %s and tp.es_principal = true limit 1", (id_paciente,))
            res_tutor = cur.fetchone()
            tutor = dict(zip([d[0] for d in cur.description], res_tutor)) if res_tutor else {}
            
            cur.execute("select dp.*, c.nombre as condicion_nombre from clinico.diagnostico_paciente dp join heuristico.condicion c on c.id = dp.id_condicion where dp.id_paciente = %s and dp.esta_activo = true limit 1", (id_paciente,))
            res_diag = cur.fetchone()
            diagnostico = dict(zip([d[0] for d in cur.description], res_diag)) if res_diag else {}
            
            cur.execute("select sg.id, sg.nombre from clinico.alergia_paciente_subgrupo aps join nutricion.subgrupo_alimentario sg on sg.id = aps.id_subgrupo_alimentario where aps.id_paciente = %s and aps.activa = true", (id_paciente,))
            alergias_sub = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # Detectar intolerancia a lactosa basada en subgrupos de lacteos
            SUBGRUPOS_CON_LACTOSA = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119}
            ids_sub_alergias = {s['id'] for s in alergias_sub}
            es_intolerante_lactosa = bool(ids_sub_alergias & SUBGRUPOS_CON_LACTOSA)
            
            cur.execute("select i.id, i.nombre from clinico.alergia_paciente_ingrediente api join nutricion.ingrediente i on i.id = api.id_ingrediente where api.id_paciente = %s and api.activa = true", (id_paciente,))
            alergias_ing = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            cur.execute("select *, (fecha_proxima_cita - current_date) as dias_para_cita from clinico.control_paciente where id_paciente = %s order by fecha_control asc", (id_paciente,))
            controles_raw = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # Enriquecemos cada control con su ideal OMS histórico
            controles = []
            for c in controles_raw:
                try:
                    eval_hist = ServicioOMS.evaluar_paciente_integral(
                        float(c["peso_kg"]), float(c["talla_cm"]), 
                        paciente["id_sexo"], c["edad_meses"]
                    )
                    c["peso_ideal"] = eval_hist["peso_ideal_estimado"]
                    c["talla_ideal"] = eval_hist["talla_edad"]["ideal"]
                    c["z_score_bmi"] = eval_hist["bmi_edad"]["z_score"]
                except:
                    c["peso_ideal"] = 0
                    c["talla_ideal"] = 0
                controles.append(c)

            ultimo_control = controles[-1] if controles else {}
            
            cur.execute("""
                select cca.*, c.nombre as condicion_nombre 
                from clinico.control_condicion_activa cca
                join heuristico.condicion c on c.id = cca.id_condicion
                where cca.id_control = %s
            """, (ultimo_control.get('id'),))
            condiciones_vigentes = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            restricciones_temporales = [c for c in condiciones_vigentes if c.get('fecha_fin') is not None]
            cur.execute("select id, nombre from heuristico.condicion where id_tipo_condicion = 2 and activa = true")
            catalogo_temp = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            return {
                "paciente": paciente, "tutor": tutor, "diagnostico": diagnostico, 
                "alergias": {"subgrupos": alergias_sub, "ingredientes": alergias_ing}, 
                "es_intolerante_lactosa": es_intolerante_lactosa,
                "ultimo_control": ultimo_control, "historial_controles": controles, 
                "condiciones_vigentes": condiciones_vigentes, "restricciones_temporales": restricciones_temporales,
                "catalogo_condiciones_temp": catalogo_temp
            }

    def registrar_paciente_integral(self, payload: dict, id_usuario_creador: str = None) -> dict:
        from app.core.auth_onboarding import provision_auth_user_with_password_setup, delete_auth_user
        tutor = payload.get("tutor", {}); paciente = payload.get("paciente", {}); salud = payload.get("salud", {})
        cond_temporales = salud.get("condiciones_temporales", [])
        auth_user_id = None
        temp_password = None
        
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # Gestionar Tutor
                cur.execute("select id, auth_user_id from usuarios.usuario where cedula = %s or email = %s limit 1", (tutor.get("cedula"), tutor.get("email")))
                t_row = cur.fetchone()
                tutor_id = t_row[0] if t_row else None
                if not tutor_id:
                    auth_user_id, temp_password = provision_auth_user_with_password_setup(
                        email=tutor["email"], 
                        nombre_completo=tutor["nombre"], 
                        role_code="tutor",
                        password=tutor.get("password")
                    )
                    cur.execute("insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion) values (%s, %s, %s, 4, true, %s, %s, %s) returning id", (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion")))
                    tutor_id = cur.fetchone()[0]
                else:
                    # Upsert: Actualizar datos del tutor existente si se proporcionan
                    cur.execute("update usuarios.usuario set nombre_completo = %s, telefono = %s, direccion = %s where id = %s", (tutor["nombre"], tutor.get("telefono"), tutor.get("direccion"), tutor_id))
                
                # Insertar Paciente
                cur.execute("insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_canton, id_parroquia, cedula, activo) values (%s, %s, %s, %s, %s, %s, true) returning id", (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("id_canton", 1), paciente.get("id_parroquia"), paciente.get("cedula")))
                paciente_id = cur.fetchone()[0]
                cur.execute("insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal) values (%s, %s, %s, true)", (tutor_id, paciente_id, tutor["id_parentesco"]))
                
                fecha_nac_raw = paciente.get("fecha_nacimiento")
                if not fecha_nac_raw: raise ValueError("Fecha de nacimiento requerida")
                fecha_nac = date.fromisoformat(fecha_nac_raw)
                
                id_sexo = int(paciente.get("id_sexo", 1))
                edad_meses = self._calcular_edad_meses(fecha_nac)
                peso = float(salud.get("peso_kg") or 0)
                talla_cm = float(salud.get("talla_cm") or 0)
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla_cm, id_sexo, edad_meses)
                id_bmi = evaluacion["bmi_edad"]["id_condicion"]
                id_hfa = evaluacion["talla_edad"]["id_condicion"]
                texto_coherente = f"{evaluacion['bmi_edad']['diagnostico']} | {evaluacion['talla_edad']['diagnostico']}"
                
                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, escala_inflamacion, 
                        nivel_fatiga, minutos_rigidez, valor_pcr, valor_vsg, articulaciones_inflamadas, 
                        articulaciones_dolorosas, en_brote, estado_enfermedad, nota_evolucion, id_medico, created_at, fecha_proxima_cita
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), %s) returning id
                """, (
                    paciente_id, peso, talla_cm, edad_meses, evaluacion["imc"], id_bmi, texto_coherente, 
                    int(salud.get("puntos_dolor") or 0), int(salud.get("escala_inflamacion") or 0), 
                    int(salud.get("fatiga") or 10), int(salud.get("minutos_rigidez") or 0), 
                    float(salud.get("valor_pcr") or 0), float(salud.get("valor_vsg") or 0), 
                    int(salud.get("articulaciones_inflamadas") or 0), int(salud.get("articulaciones_dolorosas") or 0), 
                    bool(salud.get("en_brote", False)), salud.get("estado_enfermedad", "Estable"), 
                    salud.get("observaciones"), id_usuario_creador, salud.get("fecha_proxima_cita")
                ))
                control_id = cur.fetchone()[0]
                
                if id_bmi > 0: cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, id_bmi))
                if id_hfa > 0: cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, id_hfa))

                for ct in cond_temporales:
                    cid = ct.get("id")
                    if not cid: continue
                    f_ini = ct.get("fecha_inicio") or date.today().isoformat()
                    f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (control_id, cid, f_ini, f_fin))
                
                id_patologia = salud.get("id_patologia_base")
                if id_patologia:
                    cur.execute("insert into clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo, observaciones) values (%s, %s, now(), true, true, %s)", (paciente_id, id_patologia, salud.get("observaciones")))
                
                # Alergias (Evitar redundancia)
                alergias_subs = set(salud.get("alergias_subgrupos", []))
                if salud.get("es_intolerante_lactosa"): 
                    alergias_subs.update(self._obtener_ids_lacteos())
                
                # Filtrar ingredientes para no guardar los que ya pertenecen a un subgrupo prohibido
                ingredientes_raw = salud.get("alergias_ingredientes", [])
                ingredientes_finales = []
                if ingredientes_raw:
                    # Consultar subgrupos de estos ingredientes
                    cur.execute("select id, id_subgrupo_alimentario from nutricion.ingrediente where id = any(%s)", (ingredientes_raw,))
                    for i_id, i_sub in cur.fetchall():
                        if i_sub not in alergias_subs:
                            ingredientes_finales.append(i_id)

                for sub_id in alergias_subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (paciente_id, sub_id))
                for ing_id in ingredientes_finales:
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (paciente_id, ing_id))
                
                cur.execute("COMMIT")
                return {"id": str(paciente_id), "temp_password": temp_password}
            except Exception as e:
                cur.execute("ROLLBACK")
                if auth_user_id:
                    try: delete_auth_user(auth_user_id)
                    except: pass
                raise e

    def actualizar_paciente_integral(self, id_paciente: str, payload: dict) -> bool:
        tutor = payload.get("tutor", {}); paciente = payload.get("paciente", {}); salud = payload.get("salud", {})
        cond_temporales = salud.get("condiciones_temporales", [])
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("update usuarios.paciente set nombre_completo = %s, fecha_nacimiento = %s, id_sexo = %s, id_canton = %s, id_parroquia = %s, cedula = %s where id = %s", (paciente.get("nombre_completo"), paciente.get("fecha_nacimiento"), paciente.get("id_sexo"), paciente.get("id_canton"), paciente.get("id_parroquia"), paciente.get("cedula"), id_paciente))
                
                cur.execute("select id_usuario_tutor from usuarios.tutor_paciente where id_paciente = %s and es_principal = true", (id_paciente,))
                t_row = cur.fetchone()
                if t_row and tutor:
                    cur.execute("update usuarios.usuario set nombre_completo = %s, email = %s, cedula = %s, telefono = %s, direccion = %s where id = %s", (tutor.get("nombre"), tutor.get("email"), tutor.get("cedula"), tutor.get("telefono"), tutor.get("direccion"), t_row[0]))
                    cur.execute("update usuarios.tutor_paciente set id_parentesco = %s where id_usuario_tutor = %s and id_paciente = %s", (tutor.get("id_parentesco"), t_row[0], id_paciente))

                cur.execute("update clinico.diagnostico_paciente set id_condicion = %s, observaciones = %s where id_paciente = %s and esta_activo = true", (salud.get("id_patologia_base"), salud.get("observaciones"), id_paciente))

                cur.execute("select id from clinico.control_paciente where id_paciente = %s order by fecha_control desc limit 1", (id_paciente,))
                ctrl_row = cur.fetchone()
                if ctrl_row:
                    control_id = ctrl_row[0]
                    peso = float(salud.get("peso_kg", 0)); talla_cm = float(salud.get("talla_cm", 0))
                    cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (id_paciente,))
                    pac_info = cur.fetchone()
                    evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla_cm, pac_info[1], self._calcular_edad_meses(pac_info[0]))
                    
                    texto_coherente = f"{evaluacion['bmi_edad']['diagnostico']} | {evaluacion['talla_edad']['diagnostico']}"
                    
                    cur.execute("""
                        update clinico.control_paciente set 
                        peso_kg = %s, talla_cm = %s, imc_calculado = %s, 
                        id_condicion_nutricional_resultado = %s, estado_nutricional = %s,
                        puntos_dolor = %s, escala_inflamacion = %s, nivel_fatiga = %s, 
                        minutos_rigidez = %s, valor_pcr = %s, valor_vsg = %s, articulaciones_inflamadas = %s,
                        articulaciones_dolorosas = %s, en_brote = %s, estado_enfermedad = %s,
                        fecha_proxima_cita = %s, nota_evolucion = %s
                        where id = %s
                    """, (peso, talla_cm, evaluacion["imc"], evaluacion["bmi_edad"]["id_condicion"], texto_coherente, salud.get("puntos_dolor", 0), salud.get("escala_inflamacion", 0), salud.get("fatiga", 10), salud.get("minutos_rigidez", 0), salud.get("valor_pcr", 0), salud.get("valor_vsg", 0), salud.get("articulaciones_inflamadas", 0), salud.get("articulaciones_dolorosas", 0), salud.get("en_brote", False), salud.get("estado_enfermedad", "Estable"), salud.get("fecha_proxima_cita"), salud.get("observaciones"), control_id))

                    cur.execute("delete from clinico.control_condicion_activa where id_control = %s", (control_id,))
                    if evaluacion["bmi_edad"]["id_condicion"] > 0: cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, evaluacion["bmi_edad"]["id_condicion"]))
                    if evaluacion["talla_edad"]["id_condicion"] > 0: cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, evaluacion["talla_edad"]["id_condicion"]))

                    for ct in cond_temporales:
                        cid = ct.get("id"); f_ini = ct.get("fecha_inicio") or date.today().isoformat()
                        f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (control_id, cid, f_ini, f_fin))

                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                alergias_subs = set(salud.get("alergias_subgrupos", []))
                if salud.get("es_intolerante_lactosa"): alergias_subs.update(self._obtener_ids_lacteos())
                for sub_id in alergias_subs: cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sub_id))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                for Paradox_id in salud.get("alergias_ingredientes", []): cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (id_paciente, Paradox_id))
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e

    def registrar_control_mensual(self, id_paciente: str, datos: dict, id_medico: str) -> int:
        def safe_float(v, default=0.0):
            try:
                if v is None or str(v).strip() == "": return default
                return float(v)
            except: return default
        def safe_int(v, default=0):
            try:
                if v is None or str(v).strip() == "": return default
                return int(v)
            except: return default

        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("select id from clinico.control_paciente where id_paciente = %s and fecha_control::date = current_date", (id_paciente,))
                if cur.fetchone(): raise ValueError("YA_EXISTE_CONTROL_HOY")

                cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (id_paciente,))
                pinfo = cur.fetchone()
                evaluacion = ServicioOMS.evaluar_paciente_integral(safe_float(datos.get("peso_kg")), safe_float(datos.get("talla_cm")), pinfo[1], self._calcular_edad_meses(pinfo[0]))
                texto_coherente = f"{evaluacion['bmi_edad']['diagnostico']} | {evaluacion['talla_edad']['diagnostico']}"
                
                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, escala_inflamacion, 
                        nivel_fatiga, minutos_rigidez, valor_pcr, valor_vsg, articulaciones_inflamadas, 
                        articulaciones_dolorosas, en_brote, estado_enfermedad, nota_evolucion, id_medico, 
                        fecha_proxima_cita, created_at
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now()) returning id
                """, (id_paciente, safe_float(datos.get("peso_kg")), safe_float(datos.get("talla_cm")), self._calcular_edad_meses(pinfo[0]), evaluacion["imc"], evaluacion["bmi_edad"]["id_condicion"] or 0, texto_coherente, safe_int(datos.get("puntos_dolor")), safe_int(datos.get("escala_inflamacion")), safe_int(datos.get("fatiga", 10)), safe_int(datos.get("minutos_rigidez")), safe_float(datos.get("valor_pcr")), safe_float(datos.get("valor_vsg")), safe_int(datos.get("articulaciones_inflamadas")), safe_int(datos.get("articulaciones_dolorosas")), bool(datos.get("en_brote", False)), datos.get("estado_enfermedad", "Estable"), datos.get("nota_evolucion"), id_medico, datos.get("fecha_proxima_cita")))
                
                cid = cur.fetchone()[0]
                if (evaluacion["bmi_edad"]["id_condicion"] or 0) > 0: cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (cid, evaluacion["bmi_edad"]["id_condicion"]))
                if (evaluacion["talla_edad"]["id_condicion"] or 0) > 0: cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (cid, evaluacion["talla_edad"]["id_condicion"]))

                for ct in datos.get("condiciones_temporales", []):
                    f_ini = ct.get("fecha_inicio") or date.today().isoformat()
                    f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (cid, ct["id"], f_ini, f_fin))
                
                cur.execute("COMMIT")
                return cid
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e

    def actualizar_control_mensual_especifico(self, id_control: int, datos: dict) -> bool:
        def safe_float(v, default=0.0):
            try:
                if v is None or str(v).strip() == "": return default
                return float(v)
            except: return default
        def safe_int(v, default=0):
            try:
                if v is None or str(v).strip() == "": return default
                return int(v)
            except: return default

        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # Obtener info del paciente para recalcular OMS
                cur.execute("""
                    select p.fecha_nacimiento, p.id_sexo, c.fecha_control 
                    from clinico.control_paciente c
                    join usuarios.paciente p on p.id = c.id_paciente
                    where c.id = %s
                """, (id_control,))
                pinfo = cur.fetchone()
                if not pinfo: raise ValueError("Control no encontrado")
                
                # Calcular edad a la fecha del control, no hoy
                fecha_control = pinfo[2].date() if isinstance(pinfo[2], datetime) else pinfo[2]
                _, meses = ServicioOMS.calcular_edad_detallada(pinfo[0], fecha_control=fecha_control)
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(
                    safe_float(datos.get("peso_kg")), 
                    safe_float(datos.get("talla_cm")), 
                    pinfo[1], 
                    meses
                )
                texto_coherente = f"{evaluacion['bmi_edad']['diagnostico']} | {evaluacion['talla_edad']['diagnostico']}"
                
                cur.execute("""
                    update clinico.control_paciente set 
                    peso_kg = %s, talla_cm = %s, imc_calculado = %s, 
                    id_condicion_nutricional_resultado = %s, estado_nutricional = %s, 
                    puntos_dolor = %s, escala_inflamacion = %s, nivel_fatiga = %s, 
                    minutos_rigidez = %s, valor_pcr = %s, valor_vsg = %s, 
                    articulaciones_inflamadas = %s, articulaciones_dolorosas = %s, 
                    en_brote = %s, estado_enfermedad = %s, nota_evolucion = %s,
                    fecha_proxima_cita = %s
                    where id = %s
                """, (
                    safe_float(datos.get("peso_kg")), safe_float(datos.get("talla_cm")), 
                    evaluacion["imc"], evaluacion["bmi_edad"]["id_condicion"] or 0, texto_coherente, 
                    safe_int(datos.get("puntos_dolor")), safe_int(datos.get("escala_inflamacion")), 
                    safe_int(datos.get("fatiga", 10)), safe_int(datos.get("minutos_rigidez")), 
                    safe_float(datos.get("valor_pcr")), safe_float(datos.get("valor_vsg")), 
                    safe_int(datos.get("articulaciones_inflamadas")), safe_int(datos.get("articulaciones_dolorosas")), 
                    bool(datos.get("en_brote", False)), datos.get("estado_enfermedad", "Estable"), 
                    datos.get("nota_evolucion"), datos.get("fecha_proxima_cita"), id_control
                ))
                
                # Actualizar condiciones nutricionales activas para ese control
                cur.execute("delete from clinico.control_condicion_activa where id_control = %s and id_condicion in (select id from heuristico.condicion where id_tipo_condicion = 3)", (id_control,))
                id_cond_bmi = evaluacion["bmi_edad"].get("id_condicion")
                id_cond_talla = evaluacion["talla_edad"].get("id_condicion")
                if id_cond_bmi and id_cond_bmi > 0:
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, %s)", (id_control, id_cond_bmi, fecha_control))
                if id_cond_talla and id_cond_talla > 0:
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, %s)", (id_control, id_cond_talla, fecha_control))

                # Actualizar condiciones temporales
                cur.execute("delete from clinico.control_condicion_activa where id_control = %s and fecha_fin is not null", (id_control,))
                for ct in datos.get("condiciones_temporales", []):
                    f_ini = ct.get("fecha_inicio") or fecha_control.isoformat()
                    f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (id_control, ct["id"], f_ini, f_fin))
                
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e

    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        """
        ELIMINACIÓN INTEGRAL CORREGIDA (ESQUEMA INTERACCION)
        """
        from app.core.auth_onboarding import delete_auth_user
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # 1. Identificar Tutor
                cur.execute("select u.id, u.auth_user_id from usuarios.tutor_paciente tp join usuarios.usuario u on u.id = tp.id_usuario_tutor where tp.id_paciente = %s", (id_paciente,))
                tutores = cur.fetchall()

                # 2. Limpieza de CLINICA
                cur.execute("delete from clinico.control_condicion_activa where id_control in (select id from clinico.control_paciente where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from clinico.control_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.diagnostico_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                
                # 3. Limpieza de NUTRICION (Esquema INTERACCION)
                # Borrar seguimientos de consumo
                cur.execute("""
                    delete from interaccion.seguimiento_plan_item 
                    where id_plan_item in (
                        select id from interaccion.plan_item 
                        where id_plan in (select id from interaccion.plan_nutricional where id_paciente = %s)
                    )
                """, (id_paciente,))
                
                # Borrar items de los planes
                cur.execute("delete from interaccion.plan_item where id_plan in (select id from interaccion.plan_nutricional where id_paciente = %s)", (id_paciente,))
                
                # Borrar planes
                cur.execute("delete from interaccion.plan_nutricional where id_paciente = %s", (id_paciente,))

                # 4. Preferencias y Recomendaciones
                cur.execute("delete from interaccion.preferencia_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.preferencia_receta where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.recomendacion_puntual where id_paciente = %s", (id_paciente,))

                # 5. Paciente y Relación
                cur.execute("delete from usuarios.tutor_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.paciente where id = %s", (id_paciente,))

                # 6. Limpieza de Tutores huérfanos
                for t_id, auth_id in tutores:
                    cur.execute("select count(*) from usuarios.tutor_paciente where id_usuario_tutor = %s", (t_id,))
                    if cur.fetchone()[0] == 0:
                        cur.execute("delete from usuarios.usuario where id = %s", (t_id,))
                        if auth_id:
                            try: delete_auth_user(auth_id)
                            except: pass

                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e
