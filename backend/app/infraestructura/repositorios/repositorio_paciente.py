from typing import Optional, List, Dict, Any, Tuple
from datetime import date, datetime, timedelta
from ...core.db import db_cursor
from ...domain.modelos.paciente import PerfilPaciente
from ...domain.repositorios.interfaces import IRepositorioPaciente

class RepositorioPacientePostgres(IRepositorioPaciente):
    
    def _clasificar_oms(self, imc: float) -> Tuple[int, str]:
        if imc < 13.0: return (107, "Delgadez Severa")
        if imc < 14.5: return (106, "Delgadez")
        if imc < 16.0: return (101, "Desnutrición Moderada")
        if imc < 18.5: return (102, "Riesgo de Desnutrición")
        if imc < 25.0: return (103, "Eutrófico (Normal)")
        if imc < 30.0: return (104, "Sobrepeso")
        return (105, "Obesidad")

    def obtener_por_id(self, id_paciente: str) -> Optional[PerfilPaciente]:
        with db_cursor() as cur:
            cur.execute("select id, nombre_completo, fecha_nacimiento, id_sexo, cedula from usuarios.paciente where id = %s and activo = true", (id_paciente,))
            row = cur.fetchone()
            if not row: return None
            cur.execute("select id_condicion from clinico.diagnostico_paciente where id_paciente = %s and activa = true union select id_condicion from clinico.control_condicion_activa where id_control = (select id from clinico.control_paciente where id_paciente = %s order by fecha_control desc limit 1)", (id_paciente, id_paciente))
            condiciones = [r[0] for r in cur.fetchall()]
            return PerfilPaciente(id_paciente=str(row[0]), nombre=row[1], fecha_nacimiento=row[2], id_sexo=row[3], cedula=row[4], condiciones_activas=condiciones)

    def buscar_pacientes(self, consulta: str, limite: int = 50) -> List[dict]:
        with db_cursor() as cur:
            term = f"%{consulta}%"
            sql = """
                select id, nombre_completo, fecha_nacimiento, id_sexo, cedula,
                extract(year from age(now(), fecha_nacimiento)) as edad_anios
                from usuarios.paciente 
                where (nombre_completo ilike %s or cedula ilike %s or id::text ilike %s) and activo = true
                limit %s
            """
            cur.execute(sql, (term, term, term, limite))
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def listar_todos_pacientes(self) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select p.id, p.nombre_completo, p.fecha_nacimiento, p.cedula, 
                s.descripcion as sexo, p.activo,
                extract(year from age(now(), p.fecha_nacimiento)) as edad_anios,
                (select fecha_control from clinico.control_paciente where id_paciente = p.id order by fecha_control desc limit 1) as ultimo_control,
                (select diagnostico_oms_texto from clinico.control_paciente where id_paciente = p.id order by fecha_control desc limit 1) as estado_nutricional
                from usuarios.paciente p 
                left join usuarios.catalogo_sexo s on s.id = p.id_sexo 
                where p.activo = true 
                order by p.nombre_completo
            """
            cur.execute(sql)
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def obtener_expediente_completo(self, id_paciente: str) -> dict:
        with db_cursor() as cur:
            cur.execute("select p.*, s.descripcion as sexo_nombre, prov.nombre as provincia_nombre from usuarios.paciente p left join usuarios.catalogo_sexo s on s.id = p.id_sexo left join usuarios.provincia prov on prov.id = p.id_provincia where p.id = %s", (id_paciente,))
            pac_row = cur.fetchone()
            if not pac_row: return {"error": "No existe"}
            paciente = dict(zip([d[0] for d in cur.description], pac_row))
            cur.execute("select u.nombre_completo, u.email, u.cedula, tp.id_parentesco, par.nombre as parentesco_nombre from usuarios.tutor_paciente tp join usuarios.usuario u on u.id = tp.id_usuario_tutor join usuarios.parentesco par on par.id = tp.id_parentesco where tp.id_paciente = %s and tp.es_principal = true limit 1", (id_paciente,))
            res_tutor = cur.fetchone()
            tutor = dict(zip([d[0] for d in cur.description], res_tutor)) if res_tutor else {}
            cur.execute("select dp.*, c.nombre as condicion_nombre from clinico.diagnostico_paciente dp join heuristico.condicion c on c.id = dp.id_condicion where dp.id_paciente = %s and dp.activa = true limit 1", (id_paciente,))
            res_diag = cur.fetchone()
            diagnostico = dict(zip([d[0] for d in cur.description], res_diag)) if res_diag else {}
            cur.execute("select sg.id, sg.nombre from clinico.alergia_paciente_subgrupo aps join nutricion.subgrupo_alimentario sg on sg.id = aps.id_subgrupo_alimentario where aps.id_paciente = %s and aps.activa = true", (id_paciente,))
            alergias_sub = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            cur.execute("select i.id, i.nombre from clinico.alergia_paciente_ingrediente api join nutricion.ingrediente i on i.id = api.id_ingrediente where api.id_paciente = %s and api.activa = true", (id_paciente,))
            alergias_ing = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            cur.execute("select *, (fecha_proxima_cita - current_date) as dias_para_cita from clinico.control_paciente where id_paciente = %s order by fecha_control asc", (id_paciente,))
            controles = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            ultimo_control = controles[-1] if controles else {}
            cur.execute("select id, nombre from heuristico.condicion where id_tipo_condicion = 2 and activa = true")
            catalogo_temp = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            return {"paciente": paciente, "tutor": tutor, "diagnostico": diagnostico, "alergias": {"subgrupos": alergias_sub, "ingredientes": alergias_ing}, "ultimo_control": ultimo_control, "historial_controles": controles, "catalogo_condiciones_temp": catalogo_temp}

    def registrar_paciente_integral(self, payload: dict, id_usuario_creador: str = None) -> str:
        tutor = payload["tutor"]
        paciente = payload["paciente"]
        salud = payload["salud"]
        cond_temporales = salud.get("condiciones_temporales", [])
        with db_cursor() as cur:
            try:
                if id_usuario_creador:
                    cur.execute("select count(*) from usuarios.usuario where id = %s", (id_usuario_creador,))
                    if cur.fetchone()[0] == 0:
                        cur.execute("insert into usuarios.usuario (id, nombre_completo, email, id_rol, activo) values (%s, %s, %s, 2, true)", (id_usuario_creador, payload.get("medico_nombre", "Médico"), payload.get("medico_email", "medico@reuma.app")))
                cur.execute("select id from usuarios.usuario where cedula = %s limit 1", (tutor["cedula"],))
                t_row = cur.fetchone()
                tutor_id = t_row[0] if t_row else None
                if not tutor_id:
                    cur.execute("insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo) values (%s, %s, %s, 4, true) returning id", (tutor["nombre"], tutor["email"], tutor["cedula"]))
                    tutor_id = cur.fetchone()[0]
                cur.execute("insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_provincia, cedula, activo, enfermedad_principal) values (%s, %s, %s, %s, %s, true, %s) returning id", (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("id_provincia", 5), paciente.get("cedula"), salud.get("enfermedad_nombre")))
                paciente_id = cur.fetchone()[0]
                cur.execute("insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal) values (%s, %s, %s, true)", (tutor_id, paciente_id, tutor["id_parentesco"]))
                peso = float(salud["peso_kg"])
                talla_m = float(salud["talla_cm"]) / 100
                imc = round(peso / (talla_m * talla_m), 2)
                id_oms, texto_oms = self._clasificar_oms(imc)
                cur.execute("insert into clinico.control_paciente (id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, id_condicion_nutricional_resultado, diagnostico_oms_id, diagnostico_oms_texto, nivel_dolor_eva, nivel_inflamacion, nivel_fatiga, minutos_rigidez_matutina, inflamacion_pcr, hay_brote_activo, id_medico, created_at, fecha_proxima_cita) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), %s) returning id", (paciente_id, peso, salud["talla_cm"], salud.get("edad_meses", 0), imc, id_oms, id_oms, texto_oms, salud.get("dolor_eva"), salud.get("inflamacion"), salud.get("fatiga"), salud.get("rigidez_min"), salud.get("pcr"), salud.get("brote_activo"), id_usuario_creador, salud.get("fecha_proxima_cita")))
                control_id = cur.fetchone()[0]
                for ct in cond_temporales:
                    # SOLO VINCULAMOS LA CONDICIÓN AL CONTROL. El motor de reglas hará el resto.
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion) values (%s, %s)", (control_id, ct["id"]))
                cur.execute("insert into clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, activa, observaciones) values (%s, %s, now(), true, true, %s)", (paciente_id, salud["id_patologia_base"], salud.get("observaciones")))
                for sub_id in salud.get("alergias_subgrupos", []):
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (paciente_id, sub_id))
                for ing_id in salud.get("alergias_ingredientes", []):
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (paciente_id, ing_id))
                return str(paciente_id)
            except Exception as e:
                raise e

    def actualizar_paciente_integral(self, id_paciente: str, payload: dict) -> bool:
        tutor = payload["tutor"]
        paciente = payload["paciente"]
        salud = payload["salud"]
        cond_temporales = salud.get("condiciones_temporales", [])
        with db_cursor() as cur:
            try:
                # 1. Datos del Paciente
                cur.execute("update usuarios.paciente set nombre_completo = %s, fecha_nacimiento = %s, id_sexo = %s, cedula = %s, enfermedad_principal = %s where id = %s", 
                            (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("cedula"), salud.get("enfermedad_nombre"), id_paciente))
                
                # 2. Datos del Tutor Principal
                cur.execute("select id_usuario_tutor from usuarios.tutor_paciente where id_paciente = %s and es_principal = true", (id_paciente,))
                t_row = cur.fetchone()
                if t_row:
                    cur.execute("update usuarios.usuario set nombre_completo = %s, email = %s, cedula = %s where id = %s", 
                                (tutor["nombre"], tutor["email"], tutor["cedula"], t_row[0]))
                    cur.execute("update usuarios.tutor_paciente set id_parentesco = %s where id_usuario_tutor = %s and id_paciente = %s", 
                                (tutor["id_parentesco"], t_row[0], id_paciente))

                # 3. Patología Base (Diagnóstico)
                cur.execute("update clinico.diagnostico_paciente set id_condicion = %s, observaciones = %s where id_paciente = %s and activa = true", 
                            (salud["id_patologia_base"], salud.get("observaciones"), id_paciente))

                # 4. Actualizar ÚLTIMO CONTROL (Métricas clínicas)
                cur.execute("select id from clinico.control_paciente where id_paciente = %s order by fecha_control desc limit 1", (id_paciente,))
                ctrl_row = cur.fetchone()
                if ctrl_row:
                    control_id = ctrl_row[0]
                    peso = float(salud["peso_kg"])
                    talla_m = float(salud["talla_cm"]) / 100
                    imc = round(peso / (talla_m * talla_m), 2)
                    id_oms, texto_oms = self._clasificar_oms(imc)
                    
                    cur.execute("""
                        update clinico.control_paciente set 
                        peso_kg = %s, talla_cm = %s, imc_calculado = %s, 
                        id_condicion_nutricional_resultado = %s, diagnostico_oms_id = %s, diagnostico_oms_texto = %s,
                        nivel_dolor_eva = %s, nivel_inflamacion = %s, nivel_fatiga = %s, 
                        minutos_rigidez_matutina = %s, inflamacion_pcr = %s, hay_brote_activo = %s,
                        fecha_proxima_cita = %s, nota_evolucion = %s
                        where id = %s
                    """, (peso, salud["talla_cm"], imc, id_oms, id_oms, texto_oms, 
                          salud.get("dolor_eva"), salud.get("inflamacion"), salud.get("fatiga"),
                          salud.get("rigidez_min"), salud.get("pcr"), salud.get("brote_activo"),
                          salud.get("fecha_proxima_cita"), salud.get("observaciones"), control_id))

                    # 5. Condiciones Temporales (Borrar y Reinsertar para el control actual)
                    cur.execute("delete from clinico.control_condicion_activa where id_control = %s", (control_id,))
                    for ct in cond_temporales:
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion) values (%s, %s)", (control_id, ct["id"]))

                # 6. Alergias (Subgrupos e Ingredientes) - Se actualizan para el PACIENTE
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                for sub_id in salud.get("alergias_subgrupos", []):
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sub_id))
                
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                for ing_id in salud.get("alergias_ingredientes", []):
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, ing_id))

                return True
            except Exception as e:
                raise e

    def registrar_control_mensual(self, id_paciente: str, datos: dict, id_medico: str) -> int:
        with db_cursor() as cur:
            try:
                peso = float(datos["peso_kg"])
                talla_m = float(datos["talla_cm"]) / 100
                imc = round(peso / (talla_m * talla_m), 2)
                id_oms, texto_oms = self._clasificar_oms(imc)
                cur.execute("insert into clinico.control_paciente (id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, id_condicion_nutricional_resultado, diagnostico_oms_id, diagnostico_oms_texto, nivel_dolor_eva, nivel_inflamacion, nivel_fatiga, minutos_rigidez_matutina, inflamacion_pcr, hay_brote_activo, nota_evolucion, id_medico, fecha_proxima_cita, created_at) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now()) returning id", (id_paciente, peso, datos["talla_cm"], datos.get("edad_meses", 0), imc, id_oms, id_oms, texto_oms, datos.get("dolor_eva"), datos.get("inflamacion"), datos.get("fatiga"), datos.get("rigidez_min"), datos.get("pcr"), datos.get("brote_activo"), datos.get("nota_evolucion"), id_medico, datos.get("fecha_proxima_cita")))
                control_id = cur.fetchone()[0]
                for c_id in datos.get("id_condiciones_activas", []):
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion) values (%s, %s)", (control_id, c_id))
                return control_id
            except Exception as e:
                raise e

    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        with db_cursor() as cur:
            try:
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.diagnostico_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.restriccion_temporal_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.control_condicion_activa where id_control in (select id from clinico.control_paciente where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from clinico.control_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.tutor_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.paciente where id = %s", (id_paciente,))
                return True
            except Exception as e:
                raise e
