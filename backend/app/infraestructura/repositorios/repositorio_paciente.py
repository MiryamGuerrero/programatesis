import sys
import os
import logging
from typing import Optional, List, Dict, Any, Tuple, Set
from datetime import date, datetime, timedelta

from app.core.db import db_cursor
from app.domain.modelos.paciente import PerfilPaciente
from app.domain.repositorios.interfaces import IRepositorioPaciente
from app.domain.servicios.servicio_oms import ServicioOMS
from app.domain.servicios.restricciones_alimentarias import (
    RESTRICCIONES_ALIMENTARIAS,
    SUBGRUPOS_CON_LACTOSA,
    normalizar_codigos_restriccion,
    resolver_codigo_restriccion,
)

class RepositorioPacientePostgres(IRepositorioPaciente):
    
    def _calcular_edad_meses(self, fecha_nacimiento: date) -> int:
        return ServicioOMS.calcular_edad_meses(fecha_nacimiento, date.today())

    def _obtener_ids_lacteos(self) -> set[int]:
        return set(SUBGRUPOS_CON_LACTOSA)

    def _expandir_restricciones_alimentarias(self, cur, codigos: set[str]) -> tuple[set[int], set[int]]:
        subgrupos: set[int] = set()
        ingredientes: set[int] = set()

        for codigo in codigos:
            restriccion = RESTRICCIONES_ALIMENTARIAS.get(resolver_codigo_restriccion(codigo))
            if not restriccion:
                continue

            subgrupos.update(restriccion.subgrupos_ids)
            ingredientes.update(restriccion.ingredientes_ids)

            for patron in restriccion.patrones_subgrupo:
                cur.execute(
                    "select id from nutricion.subgrupo_alimentario where lower(nombre) like %s",
                    (f"%{patron.lower()}%",),
                )
                subgrupos.update(r[0] for r in cur.fetchall())

            for patron in restriccion.patrones_ingrediente:
                cur.execute(
                    "select id from nutricion.ingrediente where lower(nombre) like %s",
                    (f"%{patron.lower()}%",),
                )
                ingredientes.update(r[0] for r in cur.fetchall())

            if restriccion.etiquetas_bloqueadas:
                cur.execute(
                    """
                    select distinct ie.id_ingrediente
                    from nutricion.ingrediente_etiqueta ie
                    join nutricion.etiqueta_nutricional e on e.id = ie.id_etiqueta
                    where e.codigo = any(%s)
                    """,
                    (list(restriccion.etiquetas_bloqueadas),),
                )
                ingredientes.update(r[0] for r in cur.fetchall())

        return subgrupos, ingredientes

    def _filtrar_ingredientes_no_redundantes(self, cur, ingredientes: set[int], subgrupos_bloqueados: set[int]) -> set[int]:
        if not ingredientes:
            return set()
        cur.execute(
            """
            select id, id_subgrupo_alimentario
            from nutricion.ingrediente
            where id = any(%s)
            """,
            (list(ingredientes),),
        )
        salida: set[int] = set()
        for iid, sid in cur.fetchall():
            if sid is not None and sid in subgrupos_bloqueados:
                continue
            salida.add(iid)
        return salida

    def _guardar_restricciones_alimentarias(self, cur, id_paciente: str, codigos: set[str]) -> None:
        cur.execute("select to_regclass('clinico.restriccion_paciente')")
        if not cur.fetchone()[0]:
            return

        cur.execute("delete from clinico.restriccion_paciente where id_paciente = %s", (id_paciente,))
        for codigo in sorted(codigos):
            cur.execute(
                """
                insert into clinico.restriccion_paciente
                (id_paciente, codigo_restriccion, fecha_registro, activa)
                values (%s, %s, now(), true)
                """,
                (id_paciente, codigo),
                )

    def _construir_estado_control_mensual(self, historial: list[dict]) -> dict:
        hoy = date.today()
        ultima_fecha_control = None
        fecha_programada = None
        hubo_control_en_mes_actual = False

        for fila in historial:
            fecha_control_raw = fila.get("fecha_control")
            fecha_control = None
            if isinstance(fecha_control_raw, str) and fecha_control_raw:
                try:
                    fecha_control = date.fromisoformat(fecha_control_raw[:10])
                except Exception:
                    try:
                        fecha_control = datetime.strptime(fecha_control_raw[:10], "%Y-%m-%d").date()
                    except Exception:
                        fecha_control = None
            elif isinstance(fecha_control_raw, datetime):
                fecha_control = fecha_control_raw.date()
            elif isinstance(fecha_control_raw, date):
                fecha_control = fecha_control_raw

            if fecha_control is None:
                continue

            if ultima_fecha_control is None or fecha_control > ultima_fecha_control:
                ultima_fecha_control = fecha_control
                fecha_programada_raw = fila.get("fecha_proxima_cita")
                if isinstance(fecha_programada_raw, str) and fecha_programada_raw:
                    try:
                        fecha_programada = date.fromisoformat(fecha_programada_raw[:10])
                    except Exception:
                        try:
                            fecha_programada = datetime.strptime(fecha_programada_raw[:10], "%Y-%m-%d").date()
                        except Exception:
                            fecha_programada = None
                elif isinstance(fecha_programada_raw, datetime):
                    fecha_programada = fecha_programada_raw.date()
                elif isinstance(fecha_programada_raw, date):
                    fecha_programada = fecha_programada_raw

            if fecha_control.year == hoy.year and fecha_control.month == hoy.month:
                hubo_control_en_mes_actual = True

        referencia = fecha_programada or (ultima_fecha_control + timedelta(days=30) if ultima_fecha_control else None)
        if hubo_control_en_mes_actual:
            return {
                "ya_hecho": True,
                "habilitado": False,
                "fecha_ultima_control": ultima_fecha_control.isoformat() if ultima_fecha_control else None,
                "fecha_referencia": referencia.isoformat() if referencia else None,
                "mensaje": "Ya existe un control mensual registrado en este periodo. Si desea modificarlo, vaya al monitor de evolución.",
            }

        if referencia is None or hoy >= referencia:
            return {
                "ya_hecho": False,
                "habilitado": True,
                "fecha_ultima_control": ultima_fecha_control.isoformat() if ultima_fecha_control else None,
                "fecha_referencia": referencia.isoformat() if referencia else None,
                "mensaje": "Control mensual habilitado para registro.",
            }

        return {
            "ya_hecho": False,
            "habilitado": False,
            "fecha_ultima_control": ultima_fecha_control.isoformat() if ultima_fecha_control else None,
            "fecha_referencia": referencia.isoformat() if referencia else None,
            "mensaje": "Aún no corresponde el control mensual. La ventana se habilitará al llegar la fecha programada.",
        }

    def _obtener_codigos_catalogo_restricciones(self, cur) -> set[str]:
        cur.execute("select to_regclass('clinico.catalogo_restriccion_alimentaria')")
        if not cur.fetchone()[0]:
            return set()
        cur.execute(
            """
            select codigo
            from clinico.catalogo_restriccion_alimentaria
            where coalesce(activa, true) = true
            """
        )
        return {str(r[0]).strip().upper() for r in cur.fetchall() if r and r[0]}

    def _normalizar_codigos_restriccion_persistibles(self, cur, codigos: list[str] | set[str] | None) -> set[str]:
        raw = {str(c).strip().upper() for c in (codigos or []) if str(c).strip()}
        if not raw:
            return set()
        codigos_catalogo = self._obtener_codigos_catalogo_restricciones(cur)
        if codigos_catalogo:
            salida = set()
            for codigo in raw:
                if codigo in codigos_catalogo:
                    salida.add(codigo)
                    continue
                mapped = resolver_codigo_restriccion(codigo)
                if mapped in codigos_catalogo:
                    salida.add(mapped)
            return salida
        return normalizar_codigos_restriccion(raw)

    def _obtener_restricciones_registradas(self, cur, id_paciente: str) -> set[str]:
        cur.execute("select to_regclass('clinico.restriccion_paciente')")
        if not cur.fetchone()[0]:
            return set()

        cur.execute(
            """
            select codigo_restriccion
            from clinico.restriccion_paciente
            where id_paciente = %s and activa = true
            """,
            (id_paciente,),
        )
        return {
            str(r[0]).strip().upper()
            for r in cur.fetchall()
            if r and r[0]
        }

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
                cedula_paciente = str(paciente.get("cedula") or "").strip()
                if cedula_paciente:
                    cur.execute(
                        """
                        select id
                        from usuarios.paciente
                        where trim(cedula) = %s
                        limit 1
                        """,
                        (cedula_paciente,),
                    )
                    paciente_existente = cur.fetchone()
                    if paciente_existente:
                        raise ValueError(
                            f"__PACIENTE_CEDULA_DUP__La cédula {cedula_paciente} ya está registrada para otro paciente."
                        )
                cur.execute("""
                    insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_canton, id_parroquia, cedula, activo) 
                    values (%s, %s, %s, %s, %s, %s, true) returning id
                """, (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("id_canton", 1), paciente.get("id_parroquia"), cedula_paciente))
                paciente_id = cur.fetchone()[0]
                
                # 3. Relación Tutor-Paciente
                cur.execute("insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal, activo) values (%s, %s, %s, true, true)", (tutor_id, paciente_id, tutor.get("id_parentesco")))
                
                # 4. Evaluación OMS
                fecha_nac = date.fromisoformat(paciente["fecha_nacimiento"])
                peso = float(salud.get("peso_kg") or 0)
                talla_cm = float(salud.get("talla_cm") or 0)
                
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

                heuristico_id = ServicioOMS.mapear_oms_a_heuristico(evaluacion.get("id_condicion_nutricional_principal"), 110)
                heuristico_id_talla = ServicioOMS.mapear_oms_a_heuristico(evaluacion["talla_edad"].get("id_clasificacion"), 112)

                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado, 
                        id_condicion_nutricional_resultado, estado_nutricional, puntos_dolor, escala_inflamacion, 
                        nivel_fatiga, minutos_rigidez, articulaciones_inflamadas, 
                        articulaciones_dolorosas, en_brote, estado_enfermedad, nota_evolucion, id_medico, created_at, fecha_proxima_cita
                    ) values (%s, now(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), %s) returning id
                """, (
                    paciente_id, peso, talla_cm, edad_meses, evaluacion["imc"], heuristico_id, 
                    evaluacion["diagnostico_combinado"],
                    int(salud.get("puntos_dolor") or 0), int(salud.get("escala_inflamacion") or 0), 
                    int(salud.get("fatiga") or 10), int(salud.get("minutos_rigidez") or 0), 
                    int(salud.get("articulaciones_inflamadas") or 0), int(salud.get("articulaciones_dolorosas") or 0), 
                    bool(salud.get("en_brote", False)), salud.get("estado_enfermedad", "Estable"), 
                    salud.get("observaciones"), id_medico_interno, salud.get("fecha_proxima_cita")
                ))
                control_id = cur.fetchone()[0]
                
                # 6. Condiciones Activas
                for c_id in [heuristico_id, heuristico_id_talla]:
                    if c_id and c_id > 0:
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, esta_activa) values (%s, %s, now(), true)", (control_id, c_id))

                # 7. Diagnóstico Base
                if salud.get("id_patologia_base"):
                    cur.execute("insert into clinico.diagnostico_paciente (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo, observaciones) values (%s, %s, now(), true, true, %s)", (paciente_id, salud["id_patologia_base"], salud.get("observaciones")))
                
                # 8. Alergias y restricciones alimentarias
                restricciones = self._normalizar_codigos_restriccion_persistibles(cur, salud.get("restricciones_alimentarias", []))
                if salud.get("es_intolerante_lactosa") == True:
                    restricciones.add("INTOLERANCIA_LACTOSA")

                subs = set(salud.get("alergias_subgrupos", []))
                self._guardar_restricciones_alimentarias(cur, str(paciente_id), restricciones)
                
                for sid in subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (paciente_id, sid))
                
                ingredientes_finales = self._filtrar_ingredientes_no_redundantes(
                    cur,
                    set(salud.get("alergias_ingredientes", [])),
                    subs,
                )
                for iid in ingredientes_finales:
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (paciente_id, iid))

                # 9. Condiciones Temporales
                for ct in salud.get("condiciones_temporales", []):
                    f_ini = ct.get('fecha_inicio') or date.today().isoformat()
                    cur.execute("select dias_duracion_estandar from heuristico.condicion where id = %s", (ct['id'],))
                    d_row = cur.fetchone()
                    dias = d_row[0] if d_row and d_row[0] else 7
                    f_fin = (date.fromisoformat(f_ini) + timedelta(days=dias)).isoformat()
                    cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, fecha_fin, esta_activa) values (%s, %s, %s, %s, true)", (control_id, ct['id'], f_ini, f_fin))

                cur.execute("COMMIT")
                return {"id": str(paciente_id), "temp_password": temp_password}
            except Exception as e:
                cur.execute("ROLLBACK")
                if auth_user_id:
                    try: delete_auth_user(auth_user_id)
                    except: pass
                logging.error(f"Error en registrar_paciente_integral: {str(e)}", exc_info=True)
                raise Exception(f"Fallo en el registro integral: {str(e)}")

    def registrar_control_mensual(self, id_paciente: str, datos: dict, id_medico: str) -> int:
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (id_paciente,))
                p = cur.fetchone()
                if not p: raise Exception("Paciente no encontrado")
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(float(datos.get("peso_kg") or 0), float(datos.get("talla_cm") or 0), p[1], p[0], date.today())
                heur_bmi = ServicioOMS.mapear_oms_a_heuristico(evaluacion.get("id_condicion_nutricional_principal"), 110)
                heur_hfa = ServicioOMS.mapear_oms_a_heuristico(evaluacion["talla_edad"].get("id_clasificacion"), 112)

                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado,
                        id_condicion_nutricional_resultado, estado_nutricional, id_medico,
                        puntos_dolor, escala_inflamacion, nivel_fatiga,
                        articulaciones_inflamadas, articulaciones_dolorosas, minutos_rigidez,
                        en_brote, estado_enfermedad, nota_evolucion, fecha_proxima_cita, created_at
                    ) values (
                        %s, now(), %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now()
                    ) returning id
                """, (
                    id_paciente, float(datos.get("peso_kg") or 0), float(datos.get("talla_cm") or 0), evaluacion["edad_meses"],
                    evaluacion["imc"], heur_bmi, evaluacion["diagnostico_combinado"], id_medico,
                    int(datos.get("puntos_dolor") or 0), int(datos.get("escala_inflamacion") or 0),
                    int(datos.get("fatiga", datos.get("nivel_fatiga", 10)) or 10),
                    int(datos.get("articulaciones_inflamadas") or 0), int(datos.get("articulaciones_dolorosas") or 0),
                    datos.get("minutos_rigidez"), bool(datos.get("en_brote")),
                    datos.get("estado_enfermedad") or "Seguimiento", datos.get("nota_evolucion"), datos.get("fecha_proxima_cita")
                ))
                cid = cur.fetchone()[0]
                
                for c_id in [heur_bmi, heur_hfa]:
                    if c_id and c_id > 0:
                        cur.execute("insert into clinico.control_condicion_activa (id_control, id_condicion, fecha_inicio, esta_activa) values (%s, %s, now(), true)", (cid, c_id))

                # 4. Actualizar Alergias y Restricciones (Registro Permanente del Paciente)
                if "restricciones_alimentarias" in datos:
                    # Limpiar existentes
                    cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                    cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                    
                    restricciones = self._normalizar_codigos_restriccion_persistibles(cur, datos.get("restricciones_alimentarias", []))
                    if datos.get("es_intolerante_lactosa") == True:
                        restricciones.add("INTOLERANCIA_LACTOSA")

                    subs = set(datos.get("alergias_subgrupos", []))
                    self._guardar_restricciones_alimentarias(cur, str(id_paciente), restricciones)
                    
                    for sid in subs:
                        cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sid))
                    
                    ingredientes_finales = self._filtrar_ingredientes_no_redundantes(
                        cur,
                        set(datos.get("alergias_ingredientes", [])),
                        subs,
                    )
                    for iid in ingredientes_finales:
                        cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (id_paciente, iid))

                cur.execute("COMMIT")
                return cid
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

    def actualizar_control_mensual_especifico(self, id_control: int, datos: dict) -> bool:
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("select id_paciente, id_medico from clinico.control_paciente where id = %s", (id_control,))
                control = cur.fetchone()
                if not control: raise Exception("Control mensual no encontrado")

                cur.execute("select fecha_nacimiento, id_sexo from usuarios.paciente where id = %s", (control[0],))
                paciente = cur.fetchone()
                evaluacion = ServicioOMS.evaluar_paciente_integral(float(datos.get("peso_kg") or 0), float(datos.get("talla_cm") or 0), paciente[1], paciente[0], date.today())
                
                cur.execute("""
                    update clinico.control_paciente set 
                        peso_kg = %s, talla_cm = %s, edad_meses = %s, imc_calculado = %s,
                        id_condicion_nutricional_resultado = %s, estado_nutricional = %s,
                        puntos_dolor = %s, escala_inflamacion = %s, nivel_fatiga = %s,
                        articulaciones_inflamadas = %s, articulaciones_dolorosas = %s, 
                        minutos_rigidez = %s, en_brote = %s, estado_enfermedad = %s, 
                        nota_evolucion = %s, fecha_proxima_cita = %s
                    where id = %s
                """, (
                    float(datos.get("peso_kg") or 0), float(datos.get("talla_cm") or 0), evaluacion["edad_meses"], evaluacion["imc"],
                    int(datos.get("id_condicion_nutricional_peso") or 110), evaluacion["diagnostico_combinado"],
                    int(datos.get("puntos_dolor") or 0), int(datos.get("escala_inflamacion") or 0),
                    int(datos.get("fatiga", datos.get("nivel_fatiga", 10)) or 10),
                    int(datos.get("articulaciones_inflamadas") or 0), int(datos.get("articulaciones_dolorosas") or 0),
                    datos.get("minutos_rigidez"), bool(datos.get("en_brote")),
                    datos.get("estado_enfermedad") or "Seguimiento", datos.get("nota_evolucion"), datos.get("fecha_proxima_cita"),
                    id_control
                ))
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

    def obtener_resumen_evolucion(self, id_paciente: str) -> List[dict]:
        with db_cursor() as cur:
            cur.execute("""
                select fecha_control::text, peso_kg, talla_cm, imc_calculado,
                       estado_nutricional::text, id_condicion_nutricional_resultado,
                       puntos_dolor, escala_inflamacion, nivel_fatiga,
                       articulaciones_inflamadas, articulaciones_dolorosas,
                       minutos_rigidez, en_brote, estado_enfermedad::text,
                       nota_evolucion::text, fecha_proxima_cita::text,
                       null::numeric as z_score_bmi
                from clinico.control_paciente 
                where id_paciente = %s 
                order by fecha_control asc
            """, (id_paciente,))
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]

    def buscar_pacientes(self, query: str, limite: int = 50) -> List[dict]:
        with db_cursor() as cur:
            sql = """
                select
                    v.*,
                    p.id_sexo,
                    exists (
                        select 1
                        from interaccion.plan_nutricional pn
                        where pn.id_paciente = v.id
                          and coalesce(pn.vigente, false) = true
                    ) as plan_activo,
                    (
                        select pn.id
                        from interaccion.plan_nutricional pn
                        where pn.id_paciente = v.id
                          and coalesce(pn.vigente, false) = true
                        order by pn.created_at desc nulls last, pn.id desc
                        limit 1
                    ) as plan_activo_id,
                    (
                        select pn.fecha_inicio::text
                        from interaccion.plan_nutricional pn
                        where pn.id_paciente = v.id
                          and coalesce(pn.vigente, false) = true
                        order by pn.created_at desc nulls last, pn.id desc
                        limit 1
                    ) as plan_activo_inicio,
                    (
                        select pn.fecha_fin::text
                        from interaccion.plan_nutricional pn
                        where pn.id_paciente = v.id
                          and coalesce(pn.vigente, false) = true
                        order by pn.created_at desc nulls last, pn.id desc
                        limit 1
                    ) as plan_activo_fin,
                    coalesce((
                        select vc.confirmado
                        from clinico.control_paciente cp
                        left join clinico.validacion_control_nutricional_mensual vc
                          on vc.id_control = cp.id
                         and vc.anio = extract(year from current_date)::int
                         and vc.mes = extract(month from current_date)::int
                        where cp.id_paciente = v.id
                        order by cp.fecha_control desc, cp.id desc
                        limit 1
                    ), false) as validacion_confirmada
                from usuarios.vista_gestion_pacientes v
                join usuarios.paciente p on p.id = v.id
                where v.nombre_completo ilike %s or v.cedula ilike %s
                order by v.nombre_completo
                limit %s
            """
            cur.execute(sql, (f"%{query}%", f"%{query}%", limite))
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def actualizar_paciente_integral(self, id_paciente: str, payload: dict) -> bool:
        tutor = payload.get("tutor", {}); paciente = payload.get("paciente", {}); salud = payload.get("salud", {})
        
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                
                # 1. Actualizar Paciente
                cur.execute("""
                    update usuarios.paciente set 
                        nombre_completo = %s, fecha_nacimiento = %s, id_sexo = %s, 
                        id_canton = %s, id_parroquia = %s, cedula = %s
                    where id = %s
                """, (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], 
                      paciente.get("id_canton", 1), paciente.get("id_parroquia"), paciente.get("cedula"), id_paciente))

                # 2. Actualizar Tutor (Relacionado)
                cur.execute("select id_usuario_tutor from usuarios.tutor_paciente where id_paciente = %s and es_principal = true", (id_paciente,))
                t_row = cur.fetchone()
                if t_row:
                    tutor_id = t_row[0]
                    cur.execute("""
                        update usuarios.usuario set 
                            nombre_completo = %s, email = %s, cedula = %s, 
                            telefono = %s, direccion = %s 
                        where id = %s
                    """, (tutor["nombre"], tutor["email"], tutor["cedula"], tutor.get("telefono"), tutor.get("direccion"), tutor_id))

                # 3. Diagnóstico Base
                if salud.get("id_patologia_base"):
                    cur.execute("update clinico.diagnostico_paciente set esta_activo = false where id_paciente = %s", (id_paciente,))
                    cur.execute("""
                        insert into clinico.diagnostico_paciente 
                        (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo, observaciones) 
                        values (%s, %s, now(), true, true, %s)
                    """, (id_paciente, salud["id_patologia_base"], salud.get("observaciones")))

                # 4. Alergias y restricciones
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                
                restricciones = self._normalizar_codigos_restriccion_persistibles(cur, salud.get("restricciones_alimentarias", []))
                if salud.get("es_intolerante_lactosa") == True:
                    restricciones.add("INTOLERANCIA_LACTOSA")

                subs = set(salud.get("alergias_subgrupos", []))
                self._guardar_restricciones_alimentarias(cur, str(id_paciente), restricciones)
                
                for sid in subs:
                    cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sid))
                
                ingredientes_finales = self._filtrar_ingredientes_no_redundantes(
                    cur,
                    set(salud.get("alergias_ingredientes", [])),
                    subs,
                )
                for iid in ingredientes_finales:
                    cur.execute("insert into clinico.alergia_paciente_ingrediente (id_paciente, id_ingrediente, fecha_registro, activa) values (%s, %s, now(), true) on conflict do nothing", (id_paciente, iid))

                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                logging.error(f"Error en actualizar_paciente_integral: {str(e)}", exc_info=True)
                raise Exception(f"Fallo en la actualización integral: {str(e)}")

    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        from app.core.auth_onboarding import delete_auth_user
        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")
                cur.execute("delete from clinico.control_condicion_activa where id_control in (select id from clinico.control_paciente where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from clinico.control_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.diagnostico_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.restriccion_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.tutor_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.paciente where id = %s", (id_paciente,))
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

    def obtener_expediente_completo(self, id_paciente: str) -> dict:
        with db_cursor() as cur:
            # Cast all fields to text to avoid binary decode issues during JSON serialization
            cur.execute("""
                select p.id::text, p.nombre_completo::text, p.fecha_nacimiento::text, p.cedula::text, p.id_sexo, 
                       p.id_canton, p.id_parroquia, s.descripcion::text as sexo_nombre 
                from usuarios.paciente p 
                left join usuarios.catalogo_sexo s on s.id = p.id_sexo 
                where p.id = %s
            """, (id_paciente,))
            pac_row = cur.fetchone()
            if not pac_row: return {"error": "No existe"}
            paciente = dict(zip([d[0] for d in cur.description], pac_row))
            
            cur.execute("""
                select u.id::text, u.nombre_completo::text, u.email::text, u.cedula::text, 
                       u.telefono::text, u.direccion::text, tp.id_parentesco 
                from usuarios.tutor_paciente tp 
                join usuarios.usuario u on u.id = tp.id_usuario_tutor 
                where tp.id_paciente = %s and tp.es_principal = true 
                limit 1
            """, (id_paciente,))
            tutor_row = cur.fetchone()
            tutor = dict(zip([d[0] for d in cur.description], tutor_row)) if tutor_row else {}
            
            cur.execute("""
                select dp.id::text, dp.id_condicion, dp.fecha_diagnostico::text, dp.es_cronico, 
                       c.nombre::text as condicion_nombre 
                from clinico.diagnostico_paciente dp 
                join heuristico.condicion c on c.id = dp.id_condicion 
                where dp.id_paciente = %s and dp.esta_activo = true 
                limit 1
            """, (id_paciente,))
            diag_row = cur.fetchone()
            diagnostico = dict(zip([d[0] for d in cur.description], diag_row)) if diag_row else {}
            
            cur.execute("""
                select id::text, id_paciente::text, fecha_control::text, peso_kg, talla_cm, imc_calculado, 
                       estado_nutricional::text, id_condicion_nutricional_resultado,
                       puntos_dolor, escala_inflamacion, nivel_fatiga, articulaciones_inflamadas, 
                       articulaciones_dolorosas, minutos_rigidez, en_brote, estado_enfermedad::text, 
                       nota_evolucion::text, fecha_proxima_cita::text, null::numeric as z_score_bmi
                from clinico.control_paciente 
                where id_paciente = %s 
                order by fecha_control asc
            """, (id_paciente,))
            historial_cols = [d[0] for d in cur.description]
            historial_controles = [dict(zip(historial_cols, r)) for r in cur.fetchall()]
            ultimo_control = historial_controles[-1] if historial_controles else {}
            estado_control_mensual = self._construir_estado_control_mensual(historial_controles)
            
            # También traer alergias para el expediente mensual
            cur.execute("""
                select s.id, s.nombre::text
                from clinico.alergia_paciente_subgrupo ap
                join nutricion.subgrupo_alimentario s on s.id = ap.id_subgrupo_alimentario
                where ap.id_paciente = %s and ap.activa = true
            """, (id_paciente,))
            alergias_subs = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            cur.execute("""
                select i.id, i.nombre::text
                from clinico.alergia_paciente_ingrediente ai
                join nutricion.ingrediente i on i.id = ai.id_ingrediente
                where ai.id_paciente = %s and ai.activa = true
            """, (id_paciente,))
            alergias_ings = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            cur.execute("""
                select codigo_restriccion::text
                from clinico.restriccion_paciente
                where id_paciente = %s and activa = true
            """, (id_paciente,))
            restricciones = [r[0] for r in cur.fetchall()]

            cur.execute("select to_regclass('clinico.catalogo_restriccion_alimentaria')")
            has_catalogo_restricciones = bool(cur.fetchone()[0])
            if has_catalogo_restricciones:
                cur.execute(
                    """
                    select rp.codigo_restriccion::text as codigo,
                           coalesce(cra.nombre, rp.codigo_restriccion)::text as nombre,
                           coalesce(cra.descripcion, '')::text as descripcion,
                           coalesce(cra.etiqueta_bloqueante_codigo, '')::text as etiqueta_bloqueante_codigo
                    from clinico.restriccion_paciente rp
                    left join clinico.catalogo_restriccion_alimentaria cra
                      on cra.codigo = rp.codigo_restriccion
                    where rp.id_paciente = %s and rp.activa = true
                    order by rp.codigo_restriccion
                    """,
                    (id_paciente,),
                )
            else:
                cur.execute(
                    """
                    select rp.codigo_restriccion::text as codigo,
                           rp.codigo_restriccion::text as nombre,
                           ''::text as descripcion,
                           ''::text as etiqueta_bloqueante_codigo
                    from clinico.restriccion_paciente rp
                    where rp.id_paciente = %s and rp.activa = true
                    order by rp.codigo_restriccion
                    """,
                    (id_paciente,),
                )
            restricciones_detalle = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            es_intolerante_lactosa = any(r == "INTOLERANCIA_LACTOSA" for r in restricciones)
            
            return {
                "paciente": paciente, 
                "tutor": tutor, 
                "diagnostico": diagnostico, 
                "ultimo_control": ultimo_control,
                "historial_controles": historial_controles,
                "estado_control_mensual": estado_control_mensual,
                "alergias": {
                    "subgrupos": alergias_subs,
                    "ingredientes": alergias_ings,
                    "restricciones_codigos": restricciones
                },
                "restricciones_alimentarias": restricciones,
                "restricciones_alimentarias_detalle": restricciones_detalle,
                "es_intolerante_lactosa": es_intolerante_lactosa,
            }
