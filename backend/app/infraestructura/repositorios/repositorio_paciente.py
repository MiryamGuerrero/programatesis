import sys
import os
import logging
from typing import Optional, List, Dict, Any, Tuple, Set
from datetime import date, datetime, timedelta

# Add backend to path
sys.path.append(os.path.abspath(os.path.join(os.getcwd(), 'backend')))

from app.core.db import db_cursor
from app.domain.modelos.paciente import PerfilPaciente
from app.domain.repositorios.interfaces import IRepositorioPaciente
from app.domain.servicios.servicio_oms import ServicioOMS

class RepositorioPacientePostgres(IRepositorioPaciente):
    
    def _calcular_edad_meses(self, fecha_nacimiento: date) -> int:
        return ServicioOMS.calcular_edad_meses(fecha_nacimiento, date.today())

    def _obtener_ids_lacteos(self) -> set[int]:
        return {98, 100, 101, 104, 105, 108, 111, 114, 117, 119}

    def obtener_por_id(self, id_paciente: str) -> Optional[PerfilPaciente]:
        with db_cursor() as cur:
            cur.execute("select id, nombre_completo, fecha_nacimiento, id_sexo, cedula from usuarios.paciente where id = %s and activo = true", (id_paciente,))
            row = cur.fetchone()
            if not row: return None
            
            # 1. Diagnósticos permanentes (Patologías)
            cur.execute("select id_condicion from clinico.diagnostico_paciente where id_paciente = %s and esta_activo = true", (id_paciente,))
            condiciones = [r[0] for r in cur.fetchall()]
            
            # 2. Condiciones de controles clínicos (Nutricionales, Talla, Temporales)
            # Buscamos el último control y sus condiciones activas
            cur.execute("""
                select cca.id_condicion 
                from clinico.control_condicion_activa cca
                join clinico.control_paciente cp on cp.id = cca.id_control
                where cp.id_paciente = %s and cca.esta_activa = true
                order by cp.fecha_control desc
            """, (id_paciente,))
            condiciones_ctrl = [r[0] for r in cur.fetchall()]
            
            # Unir sin duplicados
            todas_condiciones = list(set(condiciones + condiciones_ctrl))
            
            return PerfilPaciente(
                id_paciente=str(row[0]), 
                nombre=row[1], 
                fecha_nacimiento=row[2], 
                id_sexo=row[3], 
                cedula=row[4], 
                condiciones_activas=todas_condiciones
            )

    def listar_todos_pacientes(self) -> List[dict]:
        with db_cursor() as cur:
            sql = "select v.*, p.id_sexo from usuarios.vista_gestion_pacientes v join usuarios.paciente p on p.id = v.id order by v.nombre_completo"
            cur.execute(sql)
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def buscar_pacientes(self, consulta: str, limite: int = 50) -> List[dict]:
        with db_cursor() as cur:
            term = f"%{consulta}%" if consulta else "%"
            sql = """
                select v.*, p.id_sexo 
                from usuarios.vista_gestion_pacientes v 
                join usuarios.paciente p on p.id = v.id 
                where v.nombre_completo ilike %s or v.cedula ilike %s
                order by v.nombre_completo 
                limit %s
            """
            cur.execute(sql, (term, term, limite))
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def registrar_paciente_integral(self, payload: dict, id_usuario_creador: str = None) -> dict:
        from app.core.auth_onboarding import provision_auth_user_with_password_setup, delete_auth_user
        tutor = payload.get("tutor", {}); paciente = payload.get("paciente", {}); salud = payload.get("salud", {})
        cond_temporales = salud.get("condiciones_temporales", [])
        auth_user_id = None; temp_password = None
        
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # 1. Gestionar Tutor
                cur.execute("select id, auth_user_id from usuarios.usuario where cedula = %s or email = %s limit 1", (tutor.get("cedula"), tutor.get("email")))
                t_row = cur.fetchone()
                tutor_id = t_row[0] if t_row else None
                if not tutor_id:
                    auth_user_id, temp_password = provision_auth_user_with_password_setup(
                        email=tutor["email"], nombre_completo=tutor["nombre"], role_code="tutor", password=tutor.get("password")
                    )
                    cur.execute("insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion) values (%s, %s, %s, 4, true, %s, %s, %s) returning id", (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion")))
                    tutor_id = cur.fetchone()[0]
                else:
                    cur.execute("update usuarios.usuario set nombre_completo = %s, telefono = %s, direccion = %s where id = %s", (tutor["nombre"], tutor.get("telefono"), tutor.get("direccion"), tutor_id))
                
                # 2. Insertar Paciente
                cur.execute("""
                    insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_canton, id_parroquia, cedula, activo) 
                    values (%s, %s, %s, %s, %s, %s, true) returning id
                """, (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("id_canton", 1), paciente.get("id_parroquia"), paciente.get("cedula")))
                paciente_id = cur.fetchone()[0]
                
                # 3. Relación Tutor-Paciente
                cur.execute("insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal, activo) values (%s, %s, %s, true, true)", (tutor_id, paciente_id, tutor.get("id_parentesco")))
                
                # 4. Evaluación OMS
                fecha_nac = date.fromisoformat(paciente["fecha_nacimiento"])
                peso = float(salud.get("peso_kg") or 0)
                talla_cm = float(salud.get("talla_cm") or 0)
                
                # Usar la nueva lógica integral que maneja días y meses automáticamente
                evaluacion = ServicioOMS.evaluar_paciente_integral(
                    peso, talla_cm, int(paciente["id_sexo"]), fecha_nac, date.today()
                )
                edad_meses = evaluacion["edad_meses"]
                
                # 5. Insertar Control Inicial
                id_medico_interno = None
                if id_usuario_creador:
                    cur.execute("select id from usuarios.usuario where auth_user_id::text = %s or id::text = %s limit 1", (id_usuario_creador, id_usuario_creador))
                    m_row = cur.fetchone()
                    if m_row: id_medico_interno = m_row[0]

                # Mapeo completo de referencia.oms_clasificacion_zscore -> heuristico.condicion
                oms_to_heuristico = {
                    1: 100, 2: 101, 3: 110, 4: 111, 5: 104,
                    6: 105, 7: 118, 8: 119, 9: 110, 10: 122,
                    11: 123, 12: 124, 13: 125, 14: 112, 15: 117,
                    16: 27, 17: 28, 18: 29, 19: 30,
                }
                
                oms_id_bmi = evaluacion["bmi_edad"].get("id_clasificacion")
                heuristico_id = oms_to_heuristico.get(oms_id_bmi, 110) # Default Normal o eutrófico
                oms_id_hfa = evaluacion["talla_edad"].get("id_clasificacion")
                heuristico_id_talla = oms_to_heuristico.get(oms_id_hfa, 112) # Default Talla normal

                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, escala_inflamacion, 
                        nivel_fatiga, minutos_rigidez, valor_pcr, valor_vsg, articulaciones_inflamadas, 
                        articulaciones_dolorosas, en_brote, estado_enfermedad, nota_evolucion, id_medico, created_at, fecha_proxima_cita
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), %s) returning id
                """, (
                    paciente_id, peso, talla_cm, edad_meses, evaluacion["imc"], heuristico_id, 
                    f"{evaluacion['bmi_edad']['diagnostico']} | {evaluacion['talla_edad']['diagnostico']}",
                    int(salud.get("puntos_dolor") or 0), int(salud.get("escala_inflamacion") or 0), 
                    int(salud.get("fatiga") or 10), int(salud.get("minutos_rigidez") or 0), 
                    float(salud.get("valor_pcr") or 0), float(salud.get("valor_vsg") or 0), 
                    int(salud.get("articulaciones_inflamadas") or 0), int(salud.get("articulaciones_dolorosas") or 0), 
                    bool(salud.get("en_brote", False)), salud.get("estado_enfermedad", "Estable"), 
                    salud.get("observaciones"), id_medico_interno, salud.get("fecha_proxima_cita")
                ))
                control_id = cur.fetchone()[0]
                
                # 6. Condiciones Activas (Nutricionales + Talla)
                for c_id in [heuristico_id, heuristico_id_talla]:
                    if c_id and c_id > 0:
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, esta_activa) values (%s, %s, now(), true)", (control_id, c_id))

                # 7. Diagnóstico Base
                if salud.get("id_patologia_base"):
                    cur.execute("insert into clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo, observaciones) values (%s, %s, now(), true, true, %s)", (paciente_id, salud["id_patologia_base"], salud.get("observaciones")))
                
                # 8. Alergias
                subs = set(salud.get("alergias_subgrupos", []))
                if salud.get("es_intolerante_lactosa") == True: 
                    subs.update(self._obtener_ids_lacteos())
                
                for sid in subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (paciente_id, sid))
                
                # Lógica de expansión de alergias por ingredientes (estudio de la palabra)
                ingredientes_base_ids = salud.get("alergias_ingredientes", [])
                ingredientes_final_ids = set(ingredientes_base_ids)

                if ingredientes_base_ids:
                    # Obtener nombres de los ingredientes seleccionados para buscar similares
                    cur.execute("select nombre from nutricion.ingrediente where id = any(%s)", (list(ingredientes_base_ids),))
                    nombres_seleccionados = [r[0] for r in cur.fetchall()]
                    
                    for nombre in nombres_seleccionados:
                        # Buscamos ingredientes que contengan la palabra base (ej: 'fresa')
                        base_word = nombre.lower().strip()
                        if len(base_word) > 3: # Solo si la palabra es significativa
                            cur.execute("select id from nutricion.ingrediente where lower(nombre) like %s", (f"%{base_word}%",))
                            similares = [r[0] for r in cur.fetchall()]
                            ingredientes_final_ids.update(similares)

                for iid in ingredientes_final_ids:
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (paciente_id, iid))
                
                # 9. Condiciones Temporales
                for ct in salud.get("condiciones_temporales", []):
                    f_ini = ct.get('fecha_inicio') or date.today().isoformat()
                    f_fin = ct.get('fecha_fin')
                    
                    if not f_fin:
                        # Recuperar duración estándar si falta f_fin
                        cur.execute("select dias_duracion_estandar from heuristico.condicion where id = %s", (ct['id'],))
                        d_row = cur.fetchone()
                        dias = d_row[0] if d_row and d_row[0] else 7
                        f_fin = (date.fromisoformat(f_ini) + timedelta(days=dias)).isoformat()

                    cur.execute("""
                        insert into clinico.control_condicion_activa 
                        (id_control, id_condicion, fecha_inicio, fecha_fin, esta_activa) 
                        values (%s, %s, %s, %s, true)
                    """, (control_id, ct['id'], f_ini, f_fin))

                cur.execute("COMMIT")
                return {"id": str(paciente_id), "temp_password": temp_password}
            except Exception as e:
                cur.execute("ROLLBACK")
                if auth_user_id:
                    try: delete_auth_user(auth_user_id)
                    except: pass
                logging.error(f"Error en registrar_paciente_integral: {str(e)}", exc_info=True)
                raise Exception(f"Fallo en el registro integral: {str(e)}")

    def actualizar_paciente_integral(self, id_paciente: str, payload: dict) -> bool:
        tutor = payload.get("tutor", {}); paciente = payload.get("paciente", {}); salud = payload.get("salud", {})
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # 1. Actualizar Paciente (Datos Estáticos + Ubicación)
                cur.execute("""
                    update usuarios.paciente set 
                        nombre_completo = %s, fecha_nacimiento = %s, id_sexo = %s, 
                        id_canton = %s, id_parroquia = %s, cedula = %s, updated_at = now()
                    where id = %s
                """, (
                    paciente.get("nombre_completo"), paciente.get("fecha_nacimiento"), paciente.get("id_sexo"), 
                    paciente.get("id_canton"), paciente.get("id_parroquia"), paciente.get("cedula"), id_paciente
                ))

                # 2. Actualizar Tutor (Buscando la relación principal)
                cur.execute("select id_usuario_tutor from usuarios.tutor_paciente where id_paciente = %s and es_principal = true", (id_paciente,))
                t_row = cur.fetchone()
                if t_row and tutor:
                    tutor_id = t_row[0]
                    cur.execute("""
                        update usuarios.usuario set 
                            nombre_completo = %s, email = %s, cedula = %s, 
                            telefono = %s, direccion = %s, updated_at = now() 
                        where id = %s
                    """, (
                        tutor.get("nombre"), tutor.get("email"), tutor.get("cedula"), 
                        tutor.get("telefono"), tutor.get("direccion"), tutor_id
                    ))
                    # Actualizar parentesco en la relación
                    cur.execute("update usuarios.tutor_paciente set id_parentesco = %s where id_usuario_tutor = %s and id_paciente = %s", (tutor.get("id_parentesco"), tutor_id, id_paciente))
                
                # 3. Actualizar Diagnóstico Base
                if salud.get("id_patologia_base"):
                    cur.execute("""
                        update clinico.diagnostico_paciente set 
                            id_condicion = %s, observaciones = %s, updated_at = now()
                        where id_paciente = %s and esta_activo = true
                    """, (salud.get("id_patologia_base"), salud.get("observaciones"), id_paciente))
                
                # 4. Actualizar Alergias (Subgrupos e Ingredientes)
                # Primero limpiar anteriores
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                
                # Insertar subgrupos (incluyendo lógica de lactosa)
                subs = set(salud.get("alergias_subgrupos", []))
                if salud.get("es_intolerante_lactosa") == True:
                    subs.update(self._obtener_ids_lacteos())
                
                for sid in subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sid))
                
                # Insertar ingredientes
                for iid in salud.get("alergias_ingredientes", []):
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, iid))

                # 5. Actualizar Condiciones Temporales
                # Obtenemos el último control para asociarlas
                cur.execute("select id from clinico.control_paciente where id_paciente = %s order by fecha_control desc limit 1", (id_paciente,))
                ctrl_row = cur.fetchone()
                if ctrl_row:
                    id_control = ctrl_row[0]
                    # Limpiamos temporales previas de este control si las hay (opcional, mejor limpiar todas las temporales del paciente si se desea refrescar)
                    # Pero el modelo es por control. Vamos a insertar las nuevas.
                    for ct in salud.get("condiciones_temporales", []):
                        cur.execute("""
                            insert into clinico.control_condicion_activa 
                            (id_control, id_condicion, fecha_inicio, fecha_fin, esta_activa) 
                            values (%s, %s, %s, %s, true)
                            on conflict do nothing
                        """, (id_control, ct['id'], ct['fecha_inicio'], ct['fecha_fin']))

                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                logging.error(f"Error en actualizar_paciente_integral: {str(e)}", exc_info=True)
                raise e

    def obtener_expediente_completo(self, id_paciente: str) -> dict:
        with db_cursor() as cur:
            # 1. Datos Básicos del Paciente
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
            
            # 2. Tutor Principal
            cur.execute("""
                select u.id, u.nombre_completo, u.email, u.cedula, u.telefono, u.direccion, 
                       tp.id_parentesco, par.nombre as parentesco_nombre 
                from usuarios.tutor_paciente tp 
                join usuarios.usuario u on u.id = tp.id_usuario_tutor 
                join usuarios.parentesco par on par.id = tp.id_parentesco 
                where tp.id_paciente = %s and tp.es_principal = true limit 1
            """, (id_paciente,))
            res_tutor = cur.fetchone()
            tutor = dict(zip([d[0] for d in cur.description], res_tutor)) if res_tutor else {}
            
            # 3. Diagnóstico Base (Patología)
            cur.execute("""
                select dp.*, c.nombre as condicion_nombre 
                from clinico.diagnostico_paciente dp 
                join heuristico.condicion c on c.id = dp.id_condicion 
                where dp.id_paciente = %s and dp.esta_activo = true limit 1
            """, (id_paciente,))
            res_diag = cur.fetchone()
            diagnostico = dict(zip([d[0] for d in cur.description], res_diag)) if res_diag else {}
            
            # 4. Alergias (Subgrupos e Ingredientes)
            cur.execute("""
                select sg.id, sg.nombre 
                from clinico.alergia_paciente_subgrupo aps 
                join nutricion.subgrupo_alimentario sg on sg.id = aps.id_subgrupo_alimentario 
                where aps.id_paciente = %s and aps.activa = true
            """, (id_paciente,))
            alergias_sub = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]

            cur.execute("""
                select i.id, i.nombre 
                from clinico.alergia_paciente_ingrediente api 
                join nutricion.ingrediente i on i.id = api.id_ingrediente 
                where api.id_paciente = %s and api.activa = true
            """, (id_paciente,))
            alergias_ing = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            # Detectar intolerancia a la lactosa (si tiene subgrupos lácteos bloqueados)
            ids_lacteos_con_lactosa = {98, 100, 101, 104, 105, 108, 111, 114, 117, 119}
            tiene_bloqueo_lactosa = any(a['id'] in ids_lacteos_con_lactosa for a in alergias_sub)
            
            # 5. Historial de Controles Clínicos
            cur.execute("""
                select * from clinico.control_paciente 
                where id_paciente = %s 
                order by fecha_control asc
            """, (id_paciente,))
            controles_raw = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            controles = []
            for c in controles_raw:
                try:
                    # Enriquecemos cada control con su ideal OMS histórico para gráficas
                    # c["fecha_control"] es date, paciente["fecha_nacimiento"] es date
                    eval_hist = ServicioOMS.evaluar_paciente_integral(
                        float(c["peso_kg"]), float(c["talla_cm"]), 
                        paciente["id_sexo"], paciente["fecha_nacimiento"], c["fecha_control"]
                    )
                    c["peso_ideal"] = eval_hist["peso_ideal_estimado"]
                    c["talla_ideal"] = eval_hist["talla_ideal"]
                    c["z_score_bmi"] = eval_hist["bmi_edad"]["z_score"]
                except Exception as e:
                    logging.warning(f"Error enriqueciendo control histórico: {e}")
                    c["peso_ideal"] = 0; c["talla_ideal"] = 0; c["z_score_bmi"] = 0
                controles.append(c)

            ultimo_control = controles[-1] if controles else {}
            
            # 6. Síntomas Temporales y Catálogos para Interfaz
            cur.execute("""
                select cca.*, c.nombre as condicion_nombre 
                from clinico.control_condicion_activa cca
                join heuristico.condicion c on c.id = cca.id_condicion
                where cca.id_control = %s and c.id_tipo_condicion = 2
            """, (ultimo_control.get('id'),))
            condiciones_temporales = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            cur.execute("""
                select id, nombre, dias_duracion_estandar as duracion_dias_sugerida 
                from heuristico.condicion 
                where id_tipo_condicion = 2 and activa = true
            """)
            catalogo_temp = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            return {
                "paciente": paciente, 
                "tutor": tutor, 
                "diagnostico": diagnostico, 
                "es_intolerante_lactosa": tiene_bloqueo_lactosa,
                "alergias": {"subgrupos": alergias_sub, "ingredientes": alergias_ing}, 
                "ultimo_control": ultimo_control, 
                "historial_controles": controles, 
                "condiciones_temporales": condiciones_temporales,
                "catalogo_condiciones_temp": catalogo_temp
            }

    def registrar_control_mensual(self, id_paciente: str, datos: dict, id_medico: str) -> int:
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (id_paciente,))
                p = cur.fetchone()
                if not p: raise Exception("Paciente no encontrado")
                
                fecha_nac = p[0]
                id_sexo = p[1]
                peso = float(datos.get("peso_kg") or 0)
                talla = float(datos.get("talla_cm") or 0)
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(peso, talla, id_sexo, fecha_nac, date.today())

                oms_to_heuristico = {
                    1: 100, 2: 101, 3: 110, 4: 111, 5: 104,
                    6: 105, 7: 118, 8: 119, 9: 110, 10: 122,
                    11: 123, 12: 124, 13: 125, 14: 112, 15: 117,
                    16: 27, 17: 28, 18: 29, 19: 30,
                }
                heur_bmi = oms_to_heuristico.get(evaluacion["bmi_edad"].get("id_clasificacion"), 110)
                heur_hfa = oms_to_heuristico.get(evaluacion["talla_edad"].get("id_clasificacion"), 112)

                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, id_medico, created_at
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, now()) returning id
                """, (
                    id_paciente, peso, talla, evaluacion["edad_meses"], 
                    evaluacion["imc"], heur_bmi, 
                    evaluacion["diagnostico_combinado"], id_medico
                ))
                cid = cur.fetchone()[0]
                
                for c_id in [heur_bmi, heur_hfa]:
                    if c_id and c_id > 0:
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, esta_activa) values (%s, %s, now(), true)", (cid, c_id))

                cur.execute("COMMIT")
                return cid
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

    def actualizar_control_mensual_especifico(self, id_control: int, datos: dict) -> bool:
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("update clinico.control_paciente set peso_kg = %s, talla_cm = %s where id = %s", (datos.get("peso_kg"), datos.get("talla_cm"), id_control))
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

    def obtener_resumen_evolucion(self, id_paciente: str) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("""
                select fecha_control, peso_kg, talla_cm, imc_calculado, valor_pcr, valor_vsg, 
                       puntos_dolor, escala_inflamacion, nivel_fatiga
                from clinico.control_paciente 
                where id_paciente = %s 
                order by fecha_control asc
            """, (id_paciente,))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        from app.core.auth_onboarding import delete_auth_user
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                # 1. Identificar Tutores relacionados antes de borrar el paciente
                cur.execute("select u.id, u.auth_user_id from usuarios.tutor_paciente tp join usuarios.usuario u on u.id = tp.id_usuario_tutor where tp.id_paciente = %s", (id_paciente,))
                tutores = cur.fetchall()

                # 2. Limpieza de Nutrición (Esquema interaccion) - ORDEN CORRECTO POR FKs
                cur.execute("delete from interaccion.seguimiento_plan_item where id_plan_item in (select id from interaccion.plan_item where id_plan in (select id from interaccion.plan_nutricional where id_paciente = %s))", (id_paciente,))
                cur.execute("delete from interaccion.plan_item where id_plan in (select id from interaccion.plan_nutricional where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from interaccion.config_analisis_rechazo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.plan_nutricional where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.preferencia_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.preferencia_receta where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.recomendacion_puntual where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.evaluacion_receta where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.repositorio_receta_segura_item where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.repositorio_receta_segura_version where id_paciente = %s", (id_paciente,))

                # 3. Limpieza de Clínica
                cur.execute("delete from clinico.control_condicion_activa where id_control in (select id from clinico.control_paciente where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from clinico.control_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.diagnostico_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                
                # 4. Eliminar relación Tutor-Paciente y finalmente al Paciente
                cur.execute("delete from usuarios.tutor_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.paciente where id = %s", (id_paciente,))

                # 5. Limpieza de Tutores huérfanos
                for t_id, auth_id in tutores:
                    cur.execute("select count(*) from usuarios.tutor_paciente where id_usuario_tutor = %s", (t_id,))
                    if cur.fetchone()[0] == 0:
                        cur.execute("delete from usuarios.usuario where id = %s", (t_id,))
                        if auth_id:
                            try:
                                delete_auth_user(auth_id)
                            except Exception as ex_auth:
                                logging.warning(f"No se pudo borrar usuario de Auth {auth_id}: {ex_auth}")

                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                logging.error(f"Error en eliminar_paciente_integral: {str(e)}", exc_info=True)
                raise e
