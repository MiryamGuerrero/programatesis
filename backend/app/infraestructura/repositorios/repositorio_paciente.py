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
        return {20, 21, 22, 23, 66, 79, 39}

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
                select id, nombre_completo, cedula, enfermedad_principal, edad_anios, severidad, condicion_nutricional, ultimo_control
                from usuarios.vista_gestion_pacientes
                order by nombre_completo
            """
            cur.execute(sql)
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def obtener_expediente_completo(self, id_paciente: str) -> dict:
        with db_cursor() as cur:
            cur.execute("select p.*, s.descripcion as sexo_nombre, prov.nombre as provincia_nombre from usuarios.paciente p left join usuarios.catalogo_sexo s on s.id = p.id_sexo left join usuarios.provincia prov on prov.id = p.id_provincia where p.id = %s", (id_paciente,))
            pac_row = cur.fetchone()
            if not pac_row: return {"error": "No existe"}
            pac_cols = [d[0] for d in cur.description]
            paciente = dict(zip(pac_cols, pac_row))
            # Obtener enfermedad principal del diagnóstico activo
            cur.execute("select c.nombre from clinico.diagnostico_paciente dp join heuristico.condicion c on c.id = dp.id_condicion where dp.id_paciente = %s and dp.esta_activo = true limit 1", (id_paciente,))
            res_enf = cur.fetchone()
            paciente["enfermedad_principal"] = res_enf[0] if res_enf else "AIJ"
            
            cur.execute("select u.nombre_completo, u.email, u.cedula, tp.id_parentesco, par.nombre as parentesco_nombre from usuarios.tutor_paciente tp join usuarios.usuario u on u.id = tp.id_usuario_tutor join usuarios.parentesco par on par.id = tp.id_parentesco where tp.id_paciente = %s and tp.es_principal = true limit 1", (id_paciente,))
            res_tutor = cur.fetchone()
            tutor = dict(zip([d[0] for d in cur.description], res_tutor)) if res_tutor else {}
            
            cur.execute("select dp.*, c.nombre as condicion_nombre from clinico.diagnostico_paciente dp join heuristico.condicion c on c.id = dp.id_condicion where dp.id_paciente = %s and dp.esta_activo = true limit 1", (id_paciente,))
            res_diag = cur.fetchone()
            diagnostico = dict(zip([d[0] for d in cur.description], res_diag)) if res_diag else {}
            
            cur.execute("select sg.id, sg.nombre from clinico.alergia_paciente_subgrupo aps join nutricion.subgrupo_alimentario sg on sg.id = aps.id_subgrupo_alimentario where aps.id_paciente = %s and aps.activa = true", (id_paciente,))
            alergias_sub = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            cur.execute("select i.id, i.nombre from clinico.alergia_paciente_ingrediente api join nutricion.ingrediente i on i.id = api.id_ingrediente where api.id_paciente = %s and api.activa = true", (id_paciente,))
            alergias_ing = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            cur.execute("select *, (fecha_proxima_cita - current_date) as dias_para_cita from clinico.control_paciente where id_paciente = %s order by fecha_control asc", (id_paciente,))
            controles = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
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
                "ultimo_control": ultimo_control, "historial_controles": controles, 
                "condiciones_vigentes": condiciones_vigentes, "restricciones_temporales": restricciones_temporales,
                "catalogo_condiciones_temp": catalogo_temp
            }

    def registrar_paciente_integral(self, payload: dict, id_usuario_creador: str = None) -> dict:
        from app.core.auth_onboarding import provision_auth_user_with_password_setup, delete_auth_user
        tutor = payload["tutor"]; paciente = payload["paciente"]; salud = payload["salud"]
        cond_temporales = salud.get("condiciones_temporales", [])
        auth_user_id = None
        temp_password = None
        
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # Gestionar Tutor
                cur.execute("select id, auth_user_id from usuarios.usuario where cedula = %s limit 1", (tutor["cedula"],))
                t_row = cur.fetchone()
                tutor_id = t_row[0] if t_row else None
                if not tutor_id:
                    auth_user_id, temp_password = provision_auth_user_with_password_setup(email=tutor["email"], nombre_completo=tutor["nombre"], role_code="tutor")
                    cur.execute("insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id) values (%s, %s, %s, 4, true, %s) returning id", (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id))
                    tutor_id = cur.fetchone()[0]
                
                # Insertar Paciente (Modelo Limpio)
                cur.execute("insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_provincia, cedula, activo) values (%s, %s, %s, %s, %s, true) returning id", (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("id_provincia", 5), paciente.get("cedula")))
                paciente_id = cur.fetchone()[0]
                cur.execute("insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal) values (%s, %s, %s, true)", (tutor_id, paciente_id, tutor["id_parentesco"]))
                
                # Datos Clínicos Iniciales
                fecha_nac = date.fromisoformat(paciente["fecha_nacimiento"])
                edad_meses = self._calcular_edad_meses(fecha_nac)
                peso = float(salud["peso_kg"]); talla_cm = float(salud["talla_cm"])
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla_cm, paciente["id_sexo"], edad_meses)
                
                imc = evaluacion["imc"]
                id_oms = evaluacion["bmi_edad"]["id_condicion"]
                texto_oms = evaluacion["bmi_edad"]["diagnostico"]
                
                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, escala_inflamacion, 
                        nivel_fatiga, minutos_rigidez, valor_pcr, valor_vsg, articulaciones_inflamadas, 
                        articulaciones_dolorosas, en_brote, estado_enfermedad, nota_evolucion, id_medico, created_at, fecha_proxima_cita
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), %s) returning id
                """, (paciente_id, peso, salud["talla_cm"], edad_meses, imc, id_oms, texto_oms, salud.get("puntos_dolor", 0), salud.get("escala_inflamacion", 0), salud.get("fatiga", 10), salud.get("minutos_rigidez", 0), salud.get("valor_pcr", 0), salud.get("valor_vsg", 0), salud.get("articulaciones_inflamadas", 0), salud.get("articulaciones_dolorosas", 0), salud.get("en_brote", False), salud.get("estado_enfermedad", "Estable"), salud.get("observaciones"), id_usuario_creador, salud.get("fecha_proxima_cita")))
                control_id = cur.fetchone()[0]
                
                # Condición Nutricional (Solo Inicio)
                cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, id_oms))
                # También registrar talla baja si aplica
                if evaluacion["talla_edad"]["codigo"] in ("TALLA_BAJA", "TALLA_BAJA_SEVERA"):
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, evaluacion["talla_edad"]["id"]))

                # Síntomas Temporales (Con Fecha Inicio/Fin)
                for ct in cond_temporales:
                    f_ini = ct.get("fecha_inicio") or date.today().isoformat()
                    f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (control_id, ct["id"], f_ini, f_fin))
                
                cur.execute("insert into clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo, observaciones) values (%s, %s, now(), true, true, %s)", (paciente_id, salud["id_patologia_base"], salud.get("observaciones")))
                
                # Alergias e Intolerancia
                es_intolerante = salud.get("es_intolerante_lactosa", False)
                alergias_subs = set(salud.get("alergias_subgrupos", []))
                if es_intolerante: alergias_subs.update(self._obtener_ids_lacteos())
                for sub_id in alergias_subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (paciente_id, sub_id))
                for ing_id in salud.get("alergias_ingredientes", []):
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
        tutor = payload["tutor"]; paciente = payload["paciente"]; salud = payload["salud"]
        cond_temporales = salud.get("condiciones_temporales", [])
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("update usuarios.paciente set nombre_completo = %s, fecha_nacimiento = %s, id_sexo = %s, cedula = %s where id = %s", (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("cedula"), id_paciente))
                
                cur.execute("select id_usuario_tutor from usuarios.tutor_paciente where id_paciente = %s and es_principal = true", (id_paciente,))
                t_row = cur.fetchone()
                if t_row:
                    cur.execute("update usuarios.usuario set nombre_completo = %s, email = %s, cedula = %s where id = %s", (tutor["nombre"], tutor["email"], tutor["cedula"], t_row[0]))
                    cur.execute("update usuarios.tutor_paciente set id_parentesco = %s where id_usuario_tutor = %s and id_paciente = %s", (tutor["id_parentesco"], t_row[0], id_paciente))

                cur.execute("update clinico.diagnostico_paciente set id_condicion = %s, observaciones = %s where id_paciente = %s and esta_activo = true", (salud["id_patologia_base"], salud.get("observaciones"), id_paciente))

                cur.execute("select id from clinico.control_paciente where id_paciente = %s order by fecha_control desc limit 1", (id_paciente,))
                ctrl_row = cur.fetchone()
                if ctrl_row:
                    control_id = ctrl_row[0]
                    peso = float(salud["peso_kg"]); talla_cm = float(salud["talla_cm"])
                    
                    cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (id_paciente,))
                    pac_info = cur.fetchone()
                    edad_meses = self._calcular_edad_meses(pac_info[0])
                    
                    evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla_cm, pac_info[1], edad_meses)
                    
                    imc = evaluacion["imc"]
                    id_oms = evaluacion["bmi_edad"]["id_condicion"]
                    texto_oms = evaluacion["bmi_edad"]["diagnostico"]
                    
                    cur.execute("""
                        update clinico.control_paciente set 
                        peso_kg = %s, talla_cm = %s, imc_calculado = %s, 
                        id_condicion_nutricional_resultado = %s, estado_nutricional = %s,
                        puntos_dolor = %s, escala_inflamacion = %s, nivel_fatiga = %s, 
                        minutos_rigidez = %s, valor_pcr = %s, valor_vsg = %s, articulaciones_inflamadas = %s,
                        articulaciones_dolorosas = %s, en_brote = %s, estado_enfermedad = %s,
                        fecha_proxima_cita = %s, nota_evolucion = %s
                        where id = %s
                    """, (peso, salud["talla_cm"], imc, id_oms, texto_oms, salud.get("puntos_dolor", 0), salud.get("escala_inflamacion", 0), salud.get("fatiga", 10), salud.get("minutos_rigidez", 0), salud.get("valor_pcr", 0), salud.get("valor_vsg", 0), salud.get("articulaciones_inflamadas", 0), salud.get("articulaciones_dolorosas", 0), salud.get("en_brote", False), salud.get("estado_enfermedad", "Estable"), salud.get("fecha_proxima_cita"), salud.get("observaciones"), control_id))

                    cur.execute("delete from clinico.control_condicion_activa where id_control = %s", (control_id,))
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, id_oms))
                    if evaluacion["talla_edad"]["codigo"] in ("TALLA_BAJA", "TALLA_BAJA_SEVERA"):
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, evaluacion["talla_edad"]["id"]))

                    for ct in cond_temporales:
                        f_ini = ct.get("fecha_inicio") or date.today().isoformat()
                        f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (control_id, ct["id"], f_ini, f_fin))

                cur.execute("update clinico.alergia_paciente_subgrupo set activa = false, fecha_fin = now() where id_paciente = %s", (id_paciente,))
                es_intolerante = salud.get("es_intolerante_lactosa", False)
                alergias_subs = set(salud.get("alergias_subgrupos", []))
                if es_intolerante: alergias_subs.update(self._obtener_ids_lacteos())
                for sub_id in alergias_subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sub_id))
                cur.execute("update clinico.alergia_paciente_ingrediente set activa = false, fecha_fin = now() where id_paciente = %s", (id_paciente,))
                for ing_id in salud.get("alergias_ingredientes", []):
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (id_paciente, ing_id))
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e

    def registrar_control_mensual(self, id_paciente: str, datos: dict, id_medico: str) -> int:
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (id_paciente,))
                pac_info = cur.fetchone()
                edad_meses = self._calcular_edad_meses(pac_info[0])
                peso = float(datos["peso_kg"]); talla_cm = float(datos["talla_cm"])
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla_cm, pac_info[1], edad_meses)
                
                imc = evaluacion["imc"]
                id_oms = evaluacion["bmi_edad"]["id_condicion"]
                texto_oms = evaluacion["bmi_edad"]["diagnostico"]
                
                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, escala_inflamacion, 
                        nivel_fatiga, minutos_rigidez, valor_pcr, valor_vsg, articulaciones_inflamadas, 
                        articulaciones_dolorosas, en_brote, estado_enfermedad, nota_evolucion, id_medico, 
                        fecha_proxima_cita, created_at
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now()) returning id
                """, (id_paciente, peso, datos["talla_cm"], edad_meses, imc, id_oms, texto_oms, datos.get("puntos_dolor", 0), datos.get("escala_inflamacion", 0), datos.get("fatiga", 10), datos.get("minutos_rigidez", 0), datos.get("valor_pcr", 0), datos.get("valor_vsg", 0), datos.get("articulaciones_inflamadas", 0), datos.get("articulaciones_dolorosas", 0), datos.get("en_brote", False), datos.get("estado_enfermedad", "Estable"), datos.get("nota_evolucion"), id_medico, datos.get("fecha_proxima_cita")))
                control_id = cur.fetchone()[0]
                cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, id_oms))
                if evaluacion["talla_edad"]["codigo"] in ("TALLA_BAJA", "TALLA_BAJA_SEVERA"):
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio) values (%s, %s, now())", (control_id, evaluacion["talla_edad"]["id"]))

                # Manejar condiciones temporales (pueden venir como lista de IDs o lista de objetos con fechas)
                conds = datos.get("condiciones_temporales", [])
                if not conds and datos.get("id_condiciones_activas"):
                    conds = [{"id": cid} for cid in datos["id_condiciones_activas"]]

                for ct in conds:
                    f_ini = ct.get("fecha_inicio") or date.today().isoformat()
                    f_fin = ct.get("fecha_fin") or (date.fromisoformat(f_ini) + timedelta(days=7)).isoformat()
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin) values (%s, %s, %s, %s)", (control_id, ct["id"], f_ini, f_fin))
                cur.execute("COMMIT")
                return control_id
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e

    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        from app.core.auth_onboarding import delete_auth_user
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # 1. Obtener el Tutor y su Auth ID antes de borrar
                cur.execute("""
                    select u.id, u.auth_user_id 
                    from usuarios.tutor_paciente tp 
                    join usuarios.usuario u on u.id = tp.id_usuario_tutor 
                    where tp.id_paciente = %s
                """, (id_paciente,))
                tutor_data = cur.fetchone()
                
                # 2. Limpieza de historial clínico y paciente
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.diagnostico_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.control_condicion_activa where id_control in (select id from clinico.control_paciente where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from clinico.control_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.tutor_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.paciente where id = %s", (id_paciente,))
                
                # 3. Borrado Inteligente del Tutor (Solo si no tiene más pacientes vinculados)
                if tutor_data:
                    tutor_id, auth_user_id = tutor_data
                    cur.execute("select count(*) from usuarios.tutor_paciente where id_usuario_tutor = %s", (tutor_id,))
                    restantes = cur.fetchone()[0]
                    if restantes == 0:
                        cur.execute("delete from usuarios.usuario where id = %s", (tutor_id,))
                        if auth_user_id:
                            try: delete_auth_user(auth_user_id)
                            except: pass # Evitar que un error en Supabase Auth detenga el commit SQL
                
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                raise e
