import sys
import os
import logging
from typing import Optional, List, Dict, Any, Tuple, Set
from datetime import date, datetime, timedelta

from app.infraestructura.database.db import db_cursor
from app.domain.modelos.paciente import PerfilPaciente
from app.domain.repositorios.interfaces import IRepositorioPaciente
from app.infraestructura.servicios.servicio_oms import ServicioOMS
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

    def _guardar_recomendaciones_ingredientes(
        self,
        cur,
        id_paciente: str,
        ingredientes_ids: list[int] | set[int] | None,
        id_profesional: Any = None,
        reemplazar_previas_medico: bool = False,
    ) -> None:
        ids = {
            int(i)
            for i in (ingredientes_ids or [])
            if str(i).strip()
        }

        cur.execute("select id from usuarios.rol where lower(nombre) in ('medico', 'mÃ©dico') limit 1")
        rol_row = cur.fetchone()
        id_rol_medico = rol_row[0] if rol_row else 2

        if reemplazar_previas_medico:
            cur.execute(
                """
                update clinico.recomendacion_ingrediente
                set activa = false, updated_at = now()
                where id_paciente = %s
                  and id_rol_recomienda = %s
                """,
                (id_paciente, id_rol_medico),
            )

        motivo = "Recomendado por mÃ©dico en registro integral"
        for id_ingrediente in sorted(ids):
            cur.execute(
                """
                update clinico.recomendacion_ingrediente
                set activa = true,
                    motivo = %s,
                    prioridad = %s,
                    id_rol_recomienda = %s,
                    updated_at = now()
                where id_paciente = %s
                  and id_ingrediente = %s
                  and id_profesional is not distinct from %s
                """,
                (motivo, 1, id_rol_medico, id_paciente, id_ingrediente, id_profesional),
            )
            if cur.rowcount:
                continue

            cur.execute(
                """
                insert into clinico.recomendacion_ingrediente
                (id_paciente, id_ingrediente, id_profesional, id_rol_recomienda, motivo, prioridad, activa)
                values (%s, %s, %s, %s, %s, %s, true)
                """,
                (id_paciente, id_ingrediente, id_profesional, id_rol_medico, motivo, 1),
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
        
        referencia_real = fecha_programada or (ultima_fecha_control + timedelta(days=30) if ultima_fecha_control else None)
        fecha_formateada = referencia_real.strftime("%d/%m/%Y") if referencia_real else hoy.strftime("%d/%m/%Y")
        
        # Para pruebas, asumimos que la fecha de monitoreo es hoy
        referencia = hoy
        habilitado = not hubo_control_en_mes_actual

        if hubo_control_en_mes_actual:
            return {
                "ya_hecho": True,
                "habilitado": False,
                "fecha_ultima_control": ultima_fecha_control.isoformat() if ultima_fecha_control else None,
                "fecha_referencia": referencia.isoformat(),
                "mensaje": f"El control del paciente es el {fecha_formateada}",
            }

        return {
            "ya_hecho": False,
            "habilitado": True,
            "fecha_ultima_control": ultima_fecha_control.isoformat() if ultima_fecha_control else None,
            "fecha_referencia": referencia.isoformat(),
            "mensaje": "Control mensual habilitado para registro.",
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
            
            # 1. DiagnÃ³sticos permanentes (PatologÃ­as)
            cur.execute("select id_condicion from clinico.diagnostico_paciente where id_paciente = %s and esta_activo = true", (id_paciente,))
            condiciones = [r[0] for r in cur.fetchall()]
            
            # 2. Condiciones de controles clÃ­nicos (Nutricionales, Talla, Temporales)
            # Buscamos el Ãºltimo control y sus condiciones activas
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

    def listar_pacientes_paginado(self, q: str = None, limit: int = 10, offset: int = 0, include_total: bool = False) -> dict:
        where_clauses = ["v.id is not null"]
        params = []

        if q:
            where_clauses.append("(v.nombre_completo ilike %s or v.cedula ilike %s)")
            params.extend([f"%{q}%", f"%{q}%"])

        where_str = f"where {' and '.join(where_clauses)}"

        total = 0
        with db_cursor() as cur:
            if include_total:
                cur.execute(f"select count(*) from usuarios.vista_gestion_pacientes v {where_str}", tuple(params))
                total = cur.fetchone()[0]

            sql = f"""
                with validacion_actual as (
                    select distinct on (id_paciente) id_paciente, confirmado
                    from clinico.validacion_control_nutricional_mensual
                    where anio = extract(year from current_date)::int
                      and mes = extract(month from current_date)::int
                    order by id_paciente, id desc
                ),
                plan_activo as (
                    select distinct on (id_paciente) id_paciente, id, fecha_inicio, fecha_fin
                    from interaccion.plan_nutricional
                    where coalesce(vigente, false) = true
                    order by id_paciente, created_at desc nulls last, id desc
                )
                select
                    v.*,
                    p.id_sexo,
                    (pa.id is not null) as plan_activo,
                    pa.id as plan_activo_id,
                    pa.fecha_inicio as plan_activo_inicio,
                    pa.fecha_fin as plan_activo_fin,
                    coalesce(va.confirmado, false) as validacion_confirmada,
                    exists(select 1 from usuarios.tutor_paciente tp where tp.id_paciente = v.id) as tiene_tutor
                from usuarios.vista_gestion_pacientes v
                join usuarios.paciente p on p.id = v.id
                left join plan_activo pa on pa.id_paciente = v.id
                left join validacion_actual va on va.id_paciente = v.id
                {where_str}
                order by v.nombre_completo
                limit %s offset %s
            """
            cur.execute(sql, tuple(params + [limit, offset]))
            cols = [desc[0] for desc in cur.description]
            items = [dict(zip(cols, row)) for row in cur.fetchall()]

            return {"items": items, "total": total}

    def listar_todos_pacientes(self) -> List[dict]:
        with db_cursor() as cur:
            sql = "select v.*, p.id_sexo, exists(select 1 from usuarios.tutor_paciente tp where tp.id_paciente = v.id) as tiene_tutor from usuarios.vista_gestion_pacientes v join usuarios.paciente p on p.id = v.id order by v.nombre_completo"
            cur.execute(sql)
            cols = [desc[0] for desc in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]

    def listar_pacientes_por_tutor(self, auth_id_tutor: str) -> List[dict]:
        with db_cursor() as cur:
            # 1. Obtener el ID interno del tutor
            cur.execute("select id from usuarios.usuario where auth_user_id::text = %s limit 1", (auth_id_tutor,))
            row = cur.fetchone()
            if not row: return []
            tutor_id = row[0]

            # 2. Listar pacientes vinculados
            sql = """
                select p.id, p.nombre_completo, p.fecha_nacimiento, p.cedula,
                       par.nombre as parentesco,
                       (
                           select c.nombre 
                           from clinico.diagnostico_paciente dp
                           join heuristico.condicion c on c.id = dp.id_condicion
                           where dp.id_paciente = p.id and dp.esta_activo = true
                           limit 1
                       ) as diagnostico
                from usuarios.paciente p
                join usuarios.tutor_paciente tp on tp.id_paciente = p.id
                join usuarios.parentesco par on par.id = tp.id_parentesco
                where tp.id_usuario_tutor = %s and tp.activo = true
                order by p.nombre_completo
            """
            cur.execute(sql, (tutor_id,))
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
                id_medico_interno = None
                if id_usuario_creador:
                    cur.execute("select id from usuarios.usuario where auth_user_id::text = %s or id::text = %s limit 1", (id_usuario_creador, id_usuario_creador))
                    m_row = cur.fetchone()
                    if m_row:
                        id_medico_interno = m_row[0]

                # 1. Gestionar Tutor
                cur.execute("select id, auth_user_id from usuarios.usuario where cedula = %s or email = %s limit 1", (tutor.get("cedula"), tutor.get("email")))
                t_row = cur.fetchone()
                tutor_id = t_row[0] if t_row else None
                if not tutor_id:
                    try:
                        auth_user_id, temp_password = provision_auth_user_with_password_setup(
                            email=tutor["email"], nombre_completo=tutor["nombre"], role_code="tutor", password=tutor.get("password")
                        )
                        cur.execute("insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion, created_by) values (%s, %s, %s, 4, true, %s, %s, %s, %s) returning id", (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion"), id_medico_interno))
                        tutor_id = cur.fetchone()[0]
                    except Exception as auth_err:
                        if "already been registered" in str(auth_err) or "already exists" in str(auth_err):
                            from app.core.supabase_client import get_supabase_admin_client
                            admin_client = get_supabase_admin_client()
                            res = admin_client.auth.admin.list_users()
                            users_list = res if isinstance(res, list) else getattr(res, "users", [])
                            auth_user_id = None
                            for u in users_list:
                                if u.email.strip().lower() == tutor["email"].strip().lower():
                                    auth_user_id = u.id
                                    break
                            if not auth_user_id:
                                raise auth_err
                            cur.execute("insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion, created_by) values (%s, %s, %s, 4, true, %s, %s, %s, %s) returning id", (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion"), id_medico_interno))
                            tutor_id = cur.fetchone()[0]
                        else:
                            raise auth_err
                else:
                    cur.execute("update usuarios.usuario set nombre_completo = %s, telefono = %s, direccion = %s, updated_by = %s, updated_at = now() where id = %s", (tutor["nombre"], tutor.get("telefono"), tutor.get("direccion"), id_medico_interno, tutor_id))
                
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
                            f"__PACIENTE_CEDULA_DUP__La cÃ©dula {cedula_paciente} ya estÃ¡ registrada para otro paciente."
                        )
                cur.execute("""
                    insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_canton, id_parroquia, cedula, activo) 
                    values (%s, %s, %s, %s, %s, %s, true) returning id
                """, (paciente["nombre_completo"], paciente["fecha_nacimiento"], paciente["id_sexo"], paciente.get("id_canton", 1), paciente.get("id_parroquia"), cedula_paciente))
                paciente_id = cur.fetchone()[0]
                
                # 3. RelaciÃ³n Tutor-Paciente
                cur.execute("insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal, activo) values (%s, %s, %s, true, true)", (tutor_id, paciente_id, tutor.get("id_parentesco")))
                
                # 4. EvaluaciÃ³n OMS
                fecha_nac = date.fromisoformat(paciente["fecha_nacimiento"])
                peso = float(salud.get("peso_kg") or 0)
                talla_cm = float(salud.get("talla_cm") or 0)
                
                evaluacion = ServicioOMS.evaluar_paciente_integral(
                    peso, talla_cm, int(paciente["id_sexo"]), fecha_nac, date.today()
                )
                edad_meses = evaluacion["edad_meses"]
                
                # 5. Insertar Control Inicial
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

                # 7. DiagnÃ³stico Base
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

                # 10. Recomendaciones de ingredientes del medico
                self._guardar_recomendaciones_ingredientes(
                    cur,
                    str(paciente_id),
                    salud.get("recomendaciones_ingredientes", []),
                    id_medico_interno,
                )

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
                
                from datetime import date
                fecha_control_val = datos.get("fecha_control")
                if isinstance(fecha_control_val, str):
                    fecha_control_dt = date.fromisoformat(fecha_control_val)
                elif isinstance(fecha_control_val, date):
                    fecha_control_dt = fecha_control_val
                else:
                    fecha_control_dt = date.today()

                def safe_int(val, default=0):
                    try:
                        if val is None: return default
                        s = str(val).strip()
                        if not s: return default
                        return int(s)
                    except:
                        return default

                def safe_float(val, default=0.0):
                    try:
                        if val is None: return default
                        s = str(val).strip()
                        if not s: return default
                        return float(s)
                    except:
                        return default

                peso_val = safe_float(datos.get("peso_kg"))
                talla_val = safe_float(datos.get("talla_cm"))
                if peso_val <= 0 or talla_val <= 0:
                    raise Exception("El peso y la talla son obligatorios y deben ser mayores a 0")

                evaluacion = ServicioOMS.evaluar_paciente_integral(peso_val, talla_val, p[1], p[0], fecha_control_dt)
                heur_bmi = ServicioOMS.mapear_oms_a_heuristico(evaluacion.get("id_condicion_nutricional_principal"), 110)
                heur_hfa = ServicioOMS.mapear_oms_a_heuristico(evaluacion["talla_edad"].get("id_clasificacion"), 112)

                cur.execute("""
                    insert into clinico.control_paciente (
                        id_paciente, fecha_control, peso_kg, talla_cm, edad_meses, imc_calculado,
                        id_condicion_nutricional_resultado, estado_nutricional, id_medico,
                        puntos_dolor, escala_inflamacion, nivel_fatiga,
                        articulaciones_inflamadas, articulaciones_dolorosas, minutos_rigidez,
                        en_brote, estado_enfermedad, valor_pcr, valor_vsg, nota_evolucion, fecha_proxima_cita, created_at
                    ) values (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now()
                    ) returning id
                """, (
                    id_paciente, fecha_control_dt, peso_val, talla_val, evaluacion["edad_meses"],
                    evaluacion["imc"], heur_bmi, evaluacion["diagnostico_combinado"], id_medico,
                    safe_int(datos.get("puntos_dolor")), safe_int(datos.get("escala_inflamacion")),
                    safe_int(datos.get("fatiga", datos.get("nivel_fatiga", 10)), 10),
                    safe_int(datos.get("articulaciones_inflamadas")), safe_int(datos.get("articulaciones_dolorosas")),
                    safe_int(datos.get("minutos_rigidez")) if datos.get("minutos_rigidez") else None, bool(datos.get("en_brote")),
                    datos.get("estado_enfermedad") or "Seguimiento",
                    safe_float(datos.get("valor_pcr")), safe_float(datos.get("valor_vsg")),
                    datos.get("nota_evolucion"), datos.get("fecha_proxima_cita")
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

                    subs = set()
                    for x in (datos.get("alergias_subgrupos") or []):
                        try:
                            if x is not None:
                                subs.add(int(x))
                        except:
                            pass
                    self._guardar_restricciones_alimentarias(cur, str(id_paciente), restricciones)
                    
                    for sid in subs:
                        cur.execute("insert into clinico.alergia_paciente_subgrupo (id_paciente, id_subgrupo_alimentario, fecha_registro, activa) values (%s, %s, now(), true)", (id_paciente, sid))
                    
                    ingredientes_raw = set()
                    for x in (datos.get("alergias_ingredientes") or []):
                        try:
                            if x is not None:
                                ingredientes_raw.add(int(x))
                        except:
                            pass
                    ingredientes_finales = self._filtrar_ingredientes_no_redundantes(
                        cur,
                        ingredientes_raw,
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

                from datetime import date
                fecha_control_val = datos.get("fecha_control")
                if isinstance(fecha_control_val, str):
                    fecha_control_dt = date.fromisoformat(fecha_control_val)
                elif isinstance(fecha_control_val, date):
                    fecha_control_dt = fecha_control_val
                else:
                    fecha_control_dt = date.today()

                def safe_int(val, default=0):
                    try:
                        if val is None: return default
                        s = str(val).strip()
                        if not s: return default
                        return int(s)
                    except:
                        return default

                def safe_float(val, default=0.0):
                    try:
                        if val is None: return default
                        s = str(val).strip()
                        if not s: return default
                        return float(s)
                    except:
                        return default

                peso_val = safe_float(datos.get("peso_kg"))
                talla_val = safe_float(datos.get("talla_cm"))
                if peso_val <= 0 or talla_val <= 0:
                    raise Exception("El peso y la talla son obligatorios y deben ser mayores a 0")

                evaluacion = ServicioOMS.evaluar_paciente_integral(peso_val, talla_val, paciente[1], paciente[0], fecha_control_dt)
                
                cur.execute("""
                    update clinico.control_paciente set 
                        peso_kg = %s, talla_cm = %s, edad_meses = %s, imc_calculado = %s,
                        id_condicion_nutricional_resultado = %s, estado_nutricional = %s,
                        puntos_dolor = %s, escala_inflamacion = %s, nivel_fatiga = %s,
                        articulaciones_inflamadas = %s, articulaciones_dolorosas = %s, 
                        minutos_rigidez = %s, en_brote = %s, estado_enfermedad = %s, 
                        nota_evolucion = %s, fecha_proxima_cita = %s,
                        fecha_control = coalesce(%s, fecha_control)
                    where id = %s
                """, (
                    peso_val, talla_val, evaluacion["edad_meses"], evaluacion["imc"],
                    int(datos.get("id_condicion_nutricional_peso") or 110), evaluacion["diagnostico_combinado"],
                    safe_int(datos.get("puntos_dolor")), safe_int(datos.get("escala_inflamacion")),
                    safe_int(datos.get("fatiga", datos.get("nivel_fatiga", 10)), 10),
                    safe_int(datos.get("articulaciones_inflamadas")), safe_int(datos.get("articulaciones_dolorosas")),
                    safe_int(datos.get("minutos_rigidez")) if datos.get("minutos_rigidez") else None, bool(datos.get("en_brote")),
                    datos.get("estado_enfermedad") or "Seguimiento", datos.get("nota_evolucion"), datos.get("fecha_proxima_cita"),
                    fecha_control_dt if datos.get("fecha_control") is not None else None,
                    id_control
                ))
                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

    def obtener_evolucion_mensual(
        self,
        id_paciente: str,
        fecha_inicio: str | None = None,
        fecha_fin: str | None = None,
        estado_enfermedad: str | None = None,
        en_brote: bool | None = None,
        estado_nutricional: str | None = None,
        solo_alterados: bool = False,
    ) -> dict:
        def _parse_date(value: str | None) -> date | None:
            if not value:
                return None
            try:
                return date.fromisoformat(value[:10])
            except Exception:
                return None

        def _parse_bool(value) -> bool:
            if isinstance(value, bool):
                return value
            if value is None:
                return False
            return str(value).strip().lower() in {"true", "1", "t", "yes", "si", "sÃ­"}

        fecha_inicio_dt = _parse_date(fecha_inicio)
        fecha_fin_dt = _parse_date(fecha_fin)

        with db_cursor() as cur:
            cur.execute(
                """
                select
                    p.id::text,
                    p.nombre_completo::text,
                    p.fecha_nacimiento::text,
                    p.id_sexo,
                    coalesce(dp.condicion_nombre, 'Sin diagnÃ³stico')::text as diagnostico_principal
                from usuarios.paciente p
                left join lateral (
                    select c.nombre::text as condicion_nombre
                    from clinico.diagnostico_paciente dp
                    join heuristico.condicion c on c.id = dp.id_condicion
                    where dp.id_paciente = p.id
                      and dp.esta_activo = true
                    order by dp.fecha_diagnostico desc, dp.id desc
                    limit 1
                ) dp on true
                where p.id = %s
                limit 1
                """,
                (id_paciente,),
            )
            row_paciente = cur.fetchone()
            if not row_paciente:
                return {"error": "No existe"}

            paciente = {
                "id_paciente": row_paciente[0],
                "nombre": row_paciente[1],
                "fecha_nacimiento": row_paciente[2],
                "id_sexo": row_paciente[3],
                "diagnostico_principal": row_paciente[4],
            }
            try:
                fecha_nac = date.fromisoformat(str(row_paciente[2])[:10])
            except Exception:
                fecha_nac = date.today()

            cur.execute(
                """
                select
                    cp.id::text,
                    cp.fecha_control::text,
                    cp.peso_kg,
                    cp.talla_cm,
                    cp.imc_calculado,
                    cp.estado_nutricional::text,
                    cp.id_condicion_nutricional_resultado,
                    cp.puntos_dolor,
                    cp.escala_inflamacion,
                    cp.nivel_fatiga,
                    cp.articulaciones_inflamadas,
                    cp.articulaciones_dolorosas,
                    cp.minutos_rigidez,
                    cp.en_brote,
                    cp.estado_enfermedad::text,
                    cp.nota_evolucion::text,
                    cp.fecha_proxima_cita::text,
                    cp.created_at::text,
                    vc.confirmado as validacion_confirmada,
                    vc.fecha_confirmacion::text as fecha_confirmacion,
                    coalesce(cca.condiciones_activas, '')::text as condiciones_activas
                from clinico.control_paciente cp
                left join clinico.validacion_control_nutricional_mensual vc
                  on vc.id_control = cp.id
                 and vc.anio = extract(year from cp.fecha_control)::int
                 and vc.mes = extract(month from cp.fecha_control)::int
                left join lateral (
                    select string_agg(c.nombre::text, ', ' order by c.nombre) as condiciones_activas
                    from clinico.control_condicion_activa cca
                    join heuristico.condicion c on c.id = cca.id_condicion
                    where cca.id_control = cp.id
                      and cca.esta_activa = true
                ) cca on true
                where cp.id_paciente = %s
                order by cp.fecha_control asc, cp.id asc
                """,
                (id_paciente,),
            )
            cols = [d[0] for d in cur.description]
            controles_raw = [dict(zip(cols, row)) for row in cur.fetchall()]

        controles = []
        for raw in controles_raw:
            fecha_texto = raw.get("fecha_control")
            try:
                fecha_control = date.fromisoformat(str(fecha_texto)[:10])
            except Exception:
                fecha_control = None

            if fecha_inicio_dt and fecha_control and fecha_control < fecha_inicio_dt:
                continue
            if fecha_fin_dt and fecha_control and fecha_control > fecha_fin_dt:
                continue

            if estado_enfermedad and (raw.get("estado_enfermedad") or "").strip().lower() != estado_enfermedad.strip().lower():
                continue
            if en_brote is not None and _parse_bool(raw.get("en_brote")) != en_brote:
                continue
            if estado_nutricional and (raw.get("estado_nutricional") or "").strip().lower() != estado_nutricional.strip().lower():
                continue

            try:
                evaluacion = ServicioOMS.evaluar_paciente_integral(
                    float(raw.get("peso_kg") or 0),
                    float(raw.get("talla_cm") or 0),
                    int(paciente["id_sexo"]),
                    fecha_nac,
                    fecha_control or date.today(),
                )
            except Exception:
                evaluacion = {}

            def _to_list_text(value):
                if value is None:
                    return []
                if isinstance(value, list):
                    return [str(v) for v in value if str(v).strip()]
                if isinstance(value, tuple):
                    return [str(v) for v in value if str(v).strip()]
                text = str(value).strip()
                return [text] if text else []

            prediagnostico = {
                "imc": evaluacion.get("imc", raw.get("imc_calculado")),
                "z_score_bmi": evaluacion.get("z_score_principal", raw.get("z_score_bmi")),
                "diagnostico_nutri_texto": evaluacion.get("diagnostico_nutri_texto"),
                "diagnostico_talla_texto": evaluacion.get("diagnostico_talla_texto"),
                "diagnostico_combinado": evaluacion.get("diagnostico_combinado") or raw.get("estado_nutricional"),
                "peso_ideal": evaluacion.get("peso_ideal_estimado"),
                "talla_ideal": evaluacion.get("talla_ideal"),
                "ganancia_peso_necesaria": evaluacion.get("ganancia_peso_necesaria"),
                "ganancia_talla_necesaria": evaluacion.get("ganancia_talla_necesaria"),
                "estado_peso": evaluacion.get("estado_peso"),
                "resumen_clinico": _to_list_text(evaluacion.get("resumen_clinico")),
                "advertencias": _to_list_text(evaluacion.get("advertencias")),
            }

            if solo_alterados:
                z = float(prediagnostico.get("z_score_bmi") or 0)
                dolor = int(raw.get("puntos_dolor") or 0)
                fatiga = int(raw.get("nivel_fatiga") or 0)
                inflamacion = int(raw.get("escala_inflamacion") or 0)
                inflamadas = int(raw.get("articulaciones_inflamadas") or 0)
                dolorosas = int(raw.get("articulaciones_dolorosas") or 0)
                rigidez = int(raw.get("minutos_rigidez") or 0)
                estado_nut = (raw.get("estado_nutricional") or "").lower()
                if not (
                    dolor >= 5
                    or fatiga <= 4
                    or inflamacion >= 2
                    or inflamadas > 0
                    or dolorosas > 0
                    or rigidez >= 30
                    or _parse_bool(raw.get("en_brote"))
                    or estado_nut not in {"normal", "eutrofico"}
                    or abs(z) > 2
                ):
                    continue

            raw["prediagnostico"] = prediagnostico
            raw["mes"] = fecha_control.strftime("%b %Y") if fecha_control else "-"
            raw["fecha_control"] = fecha_control.isoformat() if fecha_control else raw.get("fecha_control")
            raw["condiciones_activas"] = [
                c.strip()
                for c in (raw.get("condiciones_activas") or "").split(",")
                if c.strip()
            ]
            controles.append(raw)

        ultimo = controles[-1] if controles else {}
        def _num(v, default=0.0):
            try:
                return float(v if v is not None else default)
            except Exception:
                return float(default)

        resumen_actual = {
            "dolor_actual": int(ultimo.get("puntos_dolor") or 0),
            "energia_actual": int(ultimo.get("nivel_fatiga") or 10),
            "inflamacion_actual": int(ultimo.get("escala_inflamacion") or 0),
            "articulaciones_inflamadas": int(ultimo.get("articulaciones_inflamadas") or 0),
            "articulaciones_dolorosas": int(ultimo.get("articulaciones_dolorosas") or 0),
            "rigidez_minutos": int(ultimo.get("minutos_rigidez") or 0),
            "estado_enfermedad": ultimo.get("estado_enfermedad"),
            "estado_nutricional": ultimo.get("estado_nutricional"),
            "z_score_bmi": _num((ultimo.get("prediagnostico") or {}).get("z_score_bmi", ultimo.get("z_score_bmi"))),
            "en_brote": bool(ultimo.get("en_brote")),
        }

        dolor = [_num(c.get("puntos_dolor")) for c in controles]
        energia = [_num(c.get("nivel_fatiga"), 10) for c in controles]
        inflamacion = [_num(c.get("escala_inflamacion")) for c in controles]
        brotes = sum(1 for c in controles if c.get("en_brote") is True)

        resumen = {
            "promedio_dolor": round(sum(dolor) / len(dolor), 2) if dolor else None,
            "promedio_energia": round(sum(energia) / len(energia), 2) if energia else None,
            "dolor_maximo": max(dolor) if dolor else None,
            "energia_minima": min(energia) if energia else None,
            "cantidad_controles": len(controles),
            "cantidad_controles_con_brote": brotes,
            "inflamacion_maxima": max(inflamacion) if inflamacion else None,
        }

        if controles:
            resumen["ultimo_control"] = controles[-1]["fecha_control"]
        else:
            resumen["ultimo_control"] = None

        if controles:
            ult = controles[-1]
            prev = controles[-2] if len(controles) > 1 else None
            note_parts = []
            if bool(ult.get("en_brote")):
                note_parts.append("El Ãºltimo control muestra brote activo.")
            elif int(ult.get("puntos_dolor") or 0) <= 2 and int(ult.get("nivel_fatiga") or 10) >= 7:
                note_parts.append("El Ãºltimo control muestra remisiÃ³n clÃ­nica.")
            else:
                note_parts.append("El Ãºltimo control requiere seguimiento clÃ­nico.")

            if prev:
                if (int(ult.get("puntos_dolor") or 0) > int(prev.get("puntos_dolor") or 0)) or (int(ult.get("escala_inflamacion") or 0) > int(prev.get("escala_inflamacion") or 0)):
                    note_parts.append("Hay aumento de actividad clÃ­nica frente al control anterior.")
                if float((ult.get("prediagnostico") or {}).get("z_score_bmi") or 0) and abs(float((ult.get("prediagnostico") or {}).get("z_score_bmi") or 0)) > 2:
                    note_parts.append("Existe alerta nutricional por z-score fuera de rango.")

            insight = " ".join(note_parts)
        else:
            insight = "No hay controles suficientes para generar una interpretaciÃ³n clÃ­nica."

        return {
            "paciente": {
                "id_paciente": paciente["id_paciente"],
                "nombre": paciente["nombre"],
                "edad": ServicioOMS.calcular_edad_meses(fecha_nac, date.today()) // 12,
                "diagnostico_principal": paciente["diagnostico_principal"],
                "ultimo_control": ultimo.get("fecha_control"),
            },
            "resumen_actual": resumen_actual,
            "resumen": resumen,
            "controles": controles,
            "insight_automatico": insight,
        }

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
                with validacion_actual as (
                    select distinct on (id_paciente) id_paciente, confirmado
                    from clinico.validacion_control_nutricional_mensual
                    where anio = extract(year from current_date)::int
                      and mes = extract(month from current_date)::int
                    order by id_paciente, id desc
                ),
                plan_activo as (
                    select distinct on (id_paciente) id_paciente, id, fecha_inicio, fecha_fin
                    from interaccion.plan_nutricional
                    where coalesce(vigente, false) = true
                    order by id_paciente, created_at desc nulls last, id desc
                )
                select
                    v.*,
                    p.id_sexo,
                    (pa.id is not null) as plan_activo,
                    pa.id as plan_activo_id,
                    pa.fecha_inicio as plan_activo_inicio,
                    pa.fecha_fin as plan_activo_fin,
                    coalesce(va.confirmado, false) as validacion_confirmada
                from usuarios.vista_gestion_pacientes v
                join usuarios.paciente p on p.id = v.id
                left join plan_activo pa on pa.id_paciente = v.id
                left join validacion_actual va on va.id_paciente = v.id
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
                cur.execute("""
                    select u.id, u.email, u.cedula 
                    from usuarios.tutor_paciente tp
                    join usuarios.usuario u on u.id = tp.id_usuario_tutor
                    where tp.id_paciente = %s and tp.es_principal = true
                """, (id_paciente,))
                t_row = cur.fetchone()
                
                if t_row:
                    current_tutor_id = t_row[0]
                    current_email = t_row[1]
                    current_cedula = t_row[2]
                    
                    email_changed = (tutor.get("email") and tutor["email"].strip().lower() != (current_email or "").strip().lower())
                    cedula_changed = (tutor.get("cedula") and tutor["cedula"].strip() != (current_cedula or "").strip())
                    
                    if email_changed or cedula_changed:
                        cur.execute("""
                            select id from usuarios.usuario 
                            where (cedula = %s or email = %s) and id_rol = 4 
                            limit 1
                        """, (tutor.get("cedula"), tutor.get("email")))
                        t_existente = cur.fetchone()
                        
                        if t_existente:
                            new_tutor_id = t_existente[0]
                            cur.execute("""
                                update usuarios.usuario set 
                                    nombre_completo = %s, email = %s, cedula = %s, 
                                    telefono = %s, direccion = %s 
                                where id = %s
                            """, (tutor["nombre"], tutor["email"], tutor["cedula"], tutor.get("telefono"), tutor.get("direccion"), new_tutor_id))
                        else:
                            try:
                                from app.core.auth_onboarding import provision_auth_user_with_password_setup
                                auth_user_id, _ = provision_auth_user_with_password_setup(
                                    email=tutor["email"], nombre_completo=tutor["nombre"], role_code="tutor", password=tutor.get("password")
                                )
                                cur.execute("""
                                    insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion) 
                                    values (%s, %s, %s, 4, true, %s, %s, %s) returning id
                                """, (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion")))
                                new_tutor_id = cur.fetchone()[0]
                            except Exception as auth_err:
                                if "already been registered" in str(auth_err) or "already exists" in str(auth_err):
                                    from app.core.supabase_client import get_supabase_admin_client
                                    admin_client = get_supabase_admin_client()
                                    res = admin_client.auth.admin.list_users()
                                    users_list = res if isinstance(res, list) else getattr(res, "users", [])
                                    auth_user_id = None
                                    for u in users_list:
                                        if u.email.strip().lower() == tutor["email"].strip().lower():
                                            auth_user_id = u.id
                                            break
                                    if not auth_user_id:
                                        raise auth_err
                                    cur.execute("""
                                        insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion) 
                                        values (%s, %s, %s, 4, true, %s, %s, %s) returning id
                                    """, (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion")))
                                    new_tutor_id = cur.fetchone()[0]
                                else:
                                    raise auth_err
                                    
                        cur.execute("""
                            update usuarios.tutor_paciente 
                            set id_usuario_tutor = %s, id_parentesco = %s
                            where id_paciente = %s and es_principal = true
                        """, (new_tutor_id, tutor.get("id_parentesco"), id_paciente))
                    else:
                        cur.execute("""
                            update usuarios.usuario set 
                                nombre_completo = %s, email = %s, cedula = %s, 
                                telefono = %s, direccion = %s 
                            where id = %s
                        """, (tutor["nombre"], tutor["email"], tutor["cedula"], tutor.get("telefono"), tutor.get("direccion"), current_tutor_id))
                        if tutor.get("id_parentesco"):
                            cur.execute("""
                                update usuarios.tutor_paciente set 
                                    id_parentesco = %s
                                where id_paciente = %s and id_usuario_tutor = %s and es_principal = true
                            """, (tutor["id_parentesco"], id_paciente, current_tutor_id))
                else:
                    if tutor and tutor.get("email") and tutor.get("nombre"):
                        from app.core.auth_onboarding import provision_auth_user_with_password_setup
                        
                        cur.execute("""
                            select id from usuarios.usuario 
                            where (cedula = %s or email = %s) and id_rol = 4 
                            limit 1
                        """, (tutor.get("cedula"), tutor.get("email")))
                        t_existente = cur.fetchone()
                        
                        if t_existente:
                            tutor_id = t_existente[0]
                            cur.execute("""
                                update usuarios.usuario set 
                                    nombre_completo = %s, email = %s, cedula = %s, 
                                    telefono = %s, direccion = %s 
                                where id = %s
                            """, (tutor["nombre"], tutor["email"], tutor["cedula"], tutor.get("telefono"), tutor.get("direccion"), tutor_id))
                        else:
                            try:
                                auth_user_id, _ = provision_auth_user_with_password_setup(
                                    email=tutor["email"], nombre_completo=tutor["nombre"], role_code="tutor", password=tutor.get("password")
                                )
                                cur.execute("""
                                    insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion) 
                                    values (%s, %s, %s, 4, true, %s, %s, %s) returning id
                                """, (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion")))
                                tutor_id = cur.fetchone()[0]
                            except Exception as auth_err:
                                if "already been registered" in str(auth_err) or "already exists" in str(auth_err):
                                    from app.core.supabase_client import get_supabase_admin_client
                                    admin_client = get_supabase_admin_client()
                                    res = admin_client.auth.admin.list_users()
                                    users_list = res if isinstance(res, list) else getattr(res, "users", [])
                                    auth_user_id = None
                                    for u in users_list:
                                        if u.email.strip().lower() == tutor["email"].strip().lower():
                                            auth_user_id = u.id
                                            break
                                    if not auth_user_id:
                                        raise auth_err
                                    cur.execute("""
                                        insert into usuarios.usuario (nombre_completo, email, cedula, id_rol, activo, auth_user_id, telefono, direccion) 
                                        values (%s, %s, %s, 4, true, %s, %s, %s) returning id
                                    """, (tutor["nombre"], tutor["email"], tutor["cedula"], auth_user_id, tutor.get("telefono"), tutor.get("direccion")))
                                    tutor_id = cur.fetchone()[0]
                                else:
                                    raise auth_err
                            
                        cur.execute("""
                            insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal, activo) 
                            values (%s, %s, %s, true, true)
                        """, (tutor_id, id_paciente, tutor.get("id_parentesco")))

                # 3. DiagnÃ³stico Base
                if salud.get("id_patologia_base"):
                    cur.execute("update clinico.diagnostico_paciente set esta_activo = false where id_paciente = %s", (id_paciente,))
                    cur.execute("""
                        insert into clinico.diagnostico_paciente 
                        (id_paciente, id_condicion, fecha_diagnostico, es_cronico, esta_activo, observaciones) 
                        values (%s, %s, now(), true, true, %s)
                        on conflict (id_paciente, id_condicion) do update set
                            esta_activo = true,
                            observaciones = excluded.observaciones
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

                # 5. Recomendaciones de ingredientes del medico
                self._guardar_recomendaciones_ingredientes(
                    cur,
                    str(id_paciente),
                    salud.get("recomendaciones_ingredientes", []),
                    None,
                    reemplazar_previas_medico=True,
                )

                cur.execute("COMMIT")
                return True
            except Exception as e:
                cur.execute("ROLLBACK")
                logging.error(f"Error en actualizar_paciente_integral: {str(e)}", exc_info=True)
                raise Exception(f"Fallo en la actualizaciÃ³n integral: {str(e)}")

    def eliminar_paciente_integral(self, id_paciente: str) -> bool:
        from app.core.auth_onboarding import delete_auth_user
        auth_users_tutores_a_eliminar = []

        with db_cursor() as cur:
            try:
                cur.execute("BEGIN")

                cur.execute(
                    "select id from usuarios.paciente where id = %s",
                    (id_paciente,),
                )
                if not cur.fetchone():
                    cur.execute("ROLLBACK")
                    return False

                cur.execute(
                    """
                    select distinct u.id, u.auth_user_id
                    from usuarios.tutor_paciente tp
                    join usuarios.usuario u on u.id = tp.id_usuario_tutor
                    where tp.id_paciente = %s
                    """,
                    (id_paciente,),
                )
                tutores_vinculados = cur.fetchall()
                ids_tutores_vinculados = [row[0] for row in tutores_vinculados]

                cur.execute(
                    """
                    delete from interaccion.seguimiento_plan_item
                    where id_plan_item in (
                        select pi.id
                        from interaccion.plan_item pi
                        join interaccion.plan_nutricional pn on pn.id = pi.id_plan
                        where pn.id_paciente = %s
                    )
                    """,
                    (id_paciente,),
                )
                cur.execute(
                    """
                    delete from interaccion.plan_item
                    where id_plan in (
                        select id
                        from interaccion.plan_nutricional
                        where id_paciente = %s
                    )
                    """,
                    (id_paciente,),
                )
                cur.execute("delete from interaccion.plan_nutricional where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.evaluacion_receta where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.preferencia_receta where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.recomendacion_puntual where id_paciente = %s", (id_paciente,))
                cur.execute("delete from interaccion.preferencia_paciente where id_paciente = %s", (id_paciente,))

                cur.execute("delete from clinico.recomendacion_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.validacion_control_nutricional_mensual where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.control_condicion_activa where id_control in (select id from clinico.control_paciente where id_paciente = %s)", (id_paciente,))
                cur.execute("delete from clinico.control_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.diagnostico_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_subgrupo where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.alergia_paciente_ingrediente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from clinico.restriccion_paciente where id_paciente = %s", (id_paciente,))

                cur.execute("delete from usuarios.tutor_paciente where id_paciente = %s", (id_paciente,))
                cur.execute("delete from usuarios.paciente where id = %s", (id_paciente,))

                if ids_tutores_vinculados:
                    cur.execute(
                        """
                        delete from usuarios.usuario u
                        where u.id = any(%s)
                          and not exists (
                              select 1
                              from usuarios.tutor_paciente tp
                              where tp.id_usuario_tutor = u.id
                          )
                        returning auth_user_id
                        """,
                        (ids_tutores_vinculados,),
                    )
                    auth_users_tutores_a_eliminar = [
                        row[0] for row in cur.fetchall() if row and row[0]
                    ]

                cur.execute("COMMIT")
            except Exception as e:
                cur.execute("ROLLBACK"); raise e

        for auth_user_id in auth_users_tutores_a_eliminar:
            try:
                delete_auth_user(auth_user_id)
            except Exception:
                logging.warning(
                    "No se pudo eliminar el usuario Auth del tutor %s",
                    auth_user_id,
                    exc_info=True,
                )

        return True

    def obtener_perfil_reducido_planificacion(self, id_paciente: str) -> dict:
        """
        VersiÃ³n optimizada de consulta de perfil para el sidebar de planificaciÃ³n.
        Evita historial de controles masivo y otros datos no crÃ­ticos.
        """
        with db_cursor() as cur:
            # 1. Datos del Paciente y Tutor
            cur.execute("""
                select p.id::text, p.nombre_completo::text, p.fecha_nacimiento::text, p.cedula::text, p.id_sexo,
                       s.descripcion::text as sexo_nombre,
                       u.nombre_completo::text as tutor_nombre, u.email::text as tutor_email
                from usuarios.paciente p
                left join usuarios.catalogo_sexo s on s.id = p.id_sexo
                left join usuarios.tutor_paciente tp on tp.id_paciente = p.id and tp.es_principal = true
                left join usuarios.usuario u on u.id = tp.id_usuario_tutor
                where p.id = %s
            """, (id_paciente,))
            pac_row = cur.fetchone()
            if not pac_row: return {"error": "No existe"}
            
            cols = [d[0] for d in cur.description]
            data = dict(zip(cols, pac_row))
            paciente = {
                "id": data["id"],
                "nombre_completo": data["nombre_completo"],
                "fecha_nacimiento": data["fecha_nacimiento"],
                "cedula": data["cedula"],
                "id_sexo": data["id_sexo"],
                "sexo_nombre": data["sexo_nombre"]
            }
            tutor = {
                "nombre_completo": data["tutor_nombre"],
                "email": data["tutor_email"]
            }

            # 2. DiagnÃ³stico Principal
            cur.execute("""
                select c.nombre::text as condicion_nombre 
                from clinico.diagnostico_paciente dp 
                join heuristico.condicion c on c.id = dp.id_condicion 
                where dp.id_paciente = %s and dp.esta_activo = true 
                order by dp.fecha_diagnostico desc
                limit 1
            """, (id_paciente,))
            diag_row = cur.fetchone()
            diagnostico = {"condicion_nombre": diag_row[0]} if diag_row else {}

            # 3. Ãšltimo Control (Resumen)
            cur.execute("""
                select id::text, fecha_control::text, peso_kg, talla_cm, estado_nutricional::text, 
                       id_condicion_nutricional_resultado, escala_inflamacion, en_brote, fecha_proxima_cita::text
                from clinico.control_paciente 
                where id_paciente = %s 
                order by fecha_control desc, id desc
                limit 1
            """, (id_paciente,))
            ctrl_row = cur.fetchone()
            ultimo_control = dict(zip([d[0] for d in cur.description], ctrl_row)) if ctrl_row else {}

            # 4. Resumen de Alergias y Restricciones
            cur.execute("""
                select s.nombre::text
                from clinico.alergia_paciente_subgrupo ap
                join nutricion.subgrupo_alimentario s on s.id = ap.id_subgrupo_alimentario
                where ap.id_paciente = %s and ap.activa = true
            """, (id_paciente,))
            al_subs = [{"nombre": r[0]} for r in cur.fetchall()]

            cur.execute("""
                select i.nombre::text
                from clinico.alergia_paciente_ingrediente ai
                join nutricion.ingrediente i on i.id = ai.id_ingrediente
                where ai.id_paciente = %s and ai.activa = true
            """, (id_paciente,))
            al_ings = [{"nombre": r[0]} for r in cur.fetchall()]

            cur.execute("""
                select rp.codigo_restriccion::text as codigo, cra.nombre::text as nombre
                from clinico.restriccion_paciente rp
                left join clinico.catalogo_restriccion_alimentaria cra on cra.codigo = rp.codigo_restriccion
                where rp.id_paciente = %s and rp.activa = true
            """, (id_paciente,))
            restricciones_detalle = [dict(zip([d[0] for d in cur.description], r)) for r in cur.fetchall()]
            
            return {
                "paciente": paciente,
                "tutor": tutor,
                "diagnostico": diagnostico,
                "ultimo_control": ultimo_control,
                "alergias": {
                    "subgrupos": al_subs,
                    "ingredientes": al_ings
                },
                "restricciones_alimentarias_detalle": restricciones_detalle,
                "es_intolerante_lactosa": any(r["codigo"] == "INTOLERANCIA_LACTOSA" for r in restricciones_detalle)
            }

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
                       valor_pcr, valor_vsg,
                       nota_evolucion::text, fecha_proxima_cita::text, null::numeric as z_score_bmi
                from clinico.control_paciente 
                where id_paciente = %s 
                order by fecha_control asc
            """, (id_paciente,))
            historial_cols = [d[0] for d in cur.description]
            historial_controles = [dict(zip(historial_cols, r)) for r in cur.fetchall()]
            ultimo_control = historial_controles[-1] if historial_controles else {}
            estado_control_mensual = self._construir_estado_control_mensual(historial_controles)
            
            # TambiÃ©n traer alergias para el expediente mensual
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

            cur.execute(
                """
                select i.id, i.nombre::text, ri.id::text as recomendacion_id,
                       ri.motivo::text, ri.prioridad
                from clinico.recomendacion_ingrediente ri
                join nutricion.ingrediente i on i.id = ri.id_ingrediente
                where ri.id_paciente = %s
                  and ri.activa = true
                order by i.nombre
                """,
                (id_paciente,),
            )
            recomendaciones_ingredientes = [
                dict(zip([d[0] for d in cur.description], r))
                for r in cur.fetchall()
            ]
            
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
                "recomendaciones": {
                    "ingredientes": recomendaciones_ingredientes,
                },
            }


