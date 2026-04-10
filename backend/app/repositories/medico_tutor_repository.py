from datetime import date

from app.core.db import db_cursor


def _rows_to_dicts(cur, rows):
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]


def _calculate_age_in_months(fecha_nacimiento: date, reference: date | None = None) -> int:
    base = reference or date.today()
    months = (base.year - fecha_nacimiento.year) * 12 + (base.month - fecha_nacimiento.month)
    if base.day < fecha_nacimiento.day:
        months -= 1
    return max(0, months)


def _fetch_patient_birthdate(cur, id_paciente: str) -> date:
    query = """
        select fecha_nacimiento
        from usuarios.paciente
        where id = %s
          and activo = true
        limit 1
    """
    cur.execute(query, (id_paciente,))
    row = cur.fetchone()
    if not row or row[0] is None:
        raise ValueError("No fue posible obtener la fecha de nacimiento del paciente.")
    return row[0]


def _crear_control_clinico_inicial(
    cur,
    id_paciente: str,
    fecha_nacimiento: date,
    control_clinico_inicial: dict | None,
) -> None:
    if not control_clinico_inicial:
        return

    edad_meses = control_clinico_inicial.get("edad_meses")
    if edad_meses is None:
        edad_meses = _calculate_age_in_months(fecha_nacimiento)

    id_condiciones_activas = [
        int(condicion_id)
        for condicion_id in (control_clinico_inicial.get("id_condiciones_activas") or [])
        if condicion_id is not None
    ]
    id_condiciones_activas = sorted(set(id_condiciones_activas))

    query_control = """
        insert into clinico.control_paciente (
            id_paciente,
            peso_kg,
            talla_cm,
            edad_meses,
            imc_calculado,
            id_condicion_nutricional_resultado,
            diagnostico_oms_texto,
            nivel_dolor_eva,
            nivel_inflamacion,
            nivel_fatiga,
            minutos_rigidez_matutina,
            inflamacion_pcr,
            hay_brote_activo,
            nota_evolucion
        )
        values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        returning id
    """

    cur.execute(
        query_control,
        (
            id_paciente,
            control_clinico_inicial["peso_kg"],
            control_clinico_inicial["talla_cm"],
            edad_meses,
            control_clinico_inicial.get("imc_calculado"),
            control_clinico_inicial.get("id_condicion_nutricional_resultado"),
            control_clinico_inicial.get("diagnostico_oms_texto"),
            control_clinico_inicial.get("nivel_dolor_eva"),
            control_clinico_inicial.get("nivel_inflamacion"),
            control_clinico_inicial.get("nivel_fatiga"),
            control_clinico_inicial.get("minutos_rigidez_matutina"),
            control_clinico_inicial.get("inflamacion_pcr"),
            control_clinico_inicial.get("hay_brote_activo"),
            control_clinico_inicial.get("nota_evolucion"),
        ),
    )
    row_control = cur.fetchone()
    if not row_control:
        raise RuntimeError("No fue posible crear el control clinico inicial del paciente.")

    id_control = int(row_control[0])
    if id_condiciones_activas:
        query_condiciones = """
            insert into clinico.control_condicion_activa (id_control, id_condicion)
            values (%s, %s)
            on conflict (id_control, id_condicion) do nothing
        """
        for id_condicion in id_condiciones_activas:
            cur.execute(query_condiciones, (id_control, id_condicion))


def buscar_tutores(query: str, limit: int = 10) -> list[dict]:
    q = query.strip()
    if not q:
        return []

    safe_limit = max(1, min(limit, 50))
    sql = """
        select
            u.id::text as id,
            u.nombre_completo,
            u.cedula
        from usuarios.usuario u
        inner join usuarios.rol r on r.id = u.id_rol
        where u.activo = true
          and lower(r.codigo) = 'tutor'
          and (
            u.nombre_completo ilike %s
            or coalesce(u.cedula, '') ilike %s
          )
        order by u.nombre_completo asc
        limit %s
    """
    needle = f"%{q}%"

    with db_cursor() as cur:
        cur.execute(sql, (needle, needle, safe_limit))
        return _rows_to_dicts(cur, cur.fetchall())


def buscar_pacientes(query: str, limit: int = 10) -> list[dict]:
    q = query.strip()
    if not q:
        return []

    safe_limit = max(1, min(limit, 50))
    sql = """
        select
            p.id::text as id,
            p.nombre_completo
        from usuarios.paciente p
        where p.activo = true
          and p.nombre_completo ilike %s
        order by p.nombre_completo asc
        limit %s
    """
    needle = f"%{q}%"

    with db_cursor() as cur:
        cur.execute(sql, (needle, safe_limit))
        return _rows_to_dicts(cur, cur.fetchall())


def registrar_tutor(
    email: str,
    nombre_completo: str,
) -> str:
    with db_cursor() as cur:
        cur.execute("select id from usuarios.rol where lower(codigo) = 'tutor' limit 1")
        row_rol = cur.fetchone()
        if not row_rol:
            raise ValueError("El rol 'tutor' no se encuentra configurado en la base de datos.")
        id_rol_tutor = row_rol[0]

        query_user = """
            insert into usuarios.usuario (email, nombre_completo, id_rol)
            values (%s, %s, %s)
            returning id
        """
        cur.execute(query_user, (email.strip(), nombre_completo.strip(), id_rol_tutor))
        row_user = cur.fetchone()
        if not row_user:
            raise RuntimeError("No fue posible crear el usuario tutor.")

        return str(row_user[0])


def registrar_paciente(
    nombre_completo: str,
    fecha_nacimiento: date,
    id_sexo: int,
    id_provincia: int | None,
    control_clinico_inicial: dict | None = None,
) -> str:
    with db_cursor() as cur:
        query_paciente = """
            insert into usuarios.paciente (nombre_completo, fecha_nacimiento, id_sexo, id_provincia)
            values (%s, %s, %s, %s)
            returning id
        """
        cur.execute(query_paciente, (nombre_completo.strip(), fecha_nacimiento, id_sexo, id_provincia))
        row_paciente = cur.fetchone()
        if not row_paciente:
            raise RuntimeError("No fue posible crear el paciente.")

        id_paciente = str(row_paciente[0])

        _crear_control_clinico_inicial(
            cur=cur,
            id_paciente=id_paciente,
            fecha_nacimiento=fecha_nacimiento,
            control_clinico_inicial=control_clinico_inicial,
        )

    return id_paciente


def vincular_tutor_paciente(
    id_usuario_tutor: str,
    id_paciente: str,
    id_parentesco: int | None,
    es_principal: bool,
) -> int:
    with db_cursor() as cur:
        query_link = """
            insert into usuarios.tutor_paciente (id_usuario_tutor, id_paciente, id_parentesco, es_principal)
            values (%s, %s, %s, %s)
            returning id
        """
        cur.execute(query_link, (id_usuario_tutor, id_paciente, id_parentesco, es_principal))
        row_link = cur.fetchone()
        if not row_link:
            raise RuntimeError("No fue posible vincular tutor y paciente.")

        return int(row_link[0])


def listar_vinculos_tutor_paciente() -> list[dict]:
    query = """
        select
            tp.id,
            tp.id_usuario_tutor::text as id_usuario_tutor,
            u.nombre_completo as tutor_nombre,
            u.cedula as tutor_cedula,
            tp.id_paciente::text as id_paciente,
            p.nombre_completo as paciente_nombre,
            tp.id_parentesco,
            pr.nombre as parentesco_nombre,
            tp.es_principal,
            tp.activo,
            tp.created_at
        from usuarios.tutor_paciente tp
        inner join usuarios.usuario u on u.id = tp.id_usuario_tutor
        inner join usuarios.paciente p on p.id = tp.id_paciente
        left join usuarios.parentesco pr on pr.id = tp.id_parentesco
        where tp.activo = true
        order by tp.created_at desc, tp.id desc
    """

    with db_cursor() as cur:
        cur.execute(query)
        return _rows_to_dicts(cur, cur.fetchall())


def actualizar_vinculo_tutor_paciente(
    id_vinculo: int,
    id_parentesco: int | None,
    es_principal: bool,
) -> bool:
    query = """
        update usuarios.tutor_paciente
        set
            id_parentesco = %s,
            es_principal = %s
        where id = %s
          and activo = true
    """

    with db_cursor() as cur:
        cur.execute(query, (id_parentesco, es_principal, id_vinculo))
        return cur.rowcount > 0


def desvincular_tutor_paciente(id_vinculo: int) -> bool:
    query = """
        update usuarios.tutor_paciente
        set activo = false
        where id = %s
          and activo = true
    """

    with db_cursor() as cur:
        cur.execute(query, (id_vinculo,))
        return cur.rowcount > 0


def registrar_tutor_paciente(
    email: str,
    nombre_completo: str,
    id_paciente: str,
    id_parentesco: int | None,
    es_principal: bool,
) -> str:
    id_usuario_tutor = registrar_tutor(
        email=email,
        nombre_completo=nombre_completo,
    )
    vincular_tutor_paciente(
        id_usuario_tutor=id_usuario_tutor,
        id_paciente=id_paciente,
        id_parentesco=id_parentesco,
        es_principal=es_principal,
    )
    return str(id_usuario_tutor)


def registrar_paciente_y_vincular(
    nombre_completo: str,
    fecha_nacimiento: date,
    id_sexo: int,
    id_provincia: int | None,
    control_clinico_inicial: dict | None,
    id_usuario_tutor: str,
    id_parentesco: int | None,
    es_principal: bool,
) -> str:
    id_paciente = registrar_paciente(
        nombre_completo=nombre_completo,
        fecha_nacimiento=fecha_nacimiento,
        id_sexo=id_sexo,
        id_provincia=id_provincia,
        control_clinico_inicial=control_clinico_inicial,
    )
    vincular_tutor_paciente(
        id_usuario_tutor=id_usuario_tutor,
        id_paciente=id_paciente,
        id_parentesco=id_parentesco,
        es_principal=es_principal,
    )
    return str(id_paciente)


def obtener_control_clinico_actual(id_paciente: str) -> dict | None:
    query = """
        select
            cp.id as id_control,
            cp.id_paciente::text as id_paciente,
            cp.fecha_control,
            cp.peso_kg,
            cp.talla_cm,
            cp.edad_meses,
            cp.imc_calculado,
            cp.id_condicion_nutricional_resultado,
            cp.diagnostico_oms_texto,
            cp.nivel_dolor_eva,
            cp.nivel_inflamacion,
            cp.nivel_fatiga,
            cp.minutos_rigidez_matutina,
            cp.inflamacion_pcr,
            cp.hay_brote_activo,
            cp.nota_evolucion,
            coalesce(
                array_agg(cca.id_condicion) filter (where cca.id_condicion is not null),
                array[]::integer[]
            ) as id_condiciones_activas
        from clinico.control_paciente cp
        left join clinico.control_condicion_activa cca on cca.id_control = cp.id
        where cp.id_paciente = %s
        group by cp.id
        order by cp.fecha_control desc, cp.created_at desc, cp.id desc
        limit 1
    """

    with db_cursor() as cur:
        cur.execute(query, (id_paciente,))
        row = cur.fetchone()
        if not row:
            return None
        return _rows_to_dicts(cur, [row])[0]


def actualizar_control_clinico_actual(id_paciente: str, control_clinico: dict) -> int:
    id_condiciones_activas = [
        int(condicion_id)
        for condicion_id in (control_clinico.get("id_condiciones_activas") or [])
        if condicion_id is not None
    ]
    id_condiciones_activas = sorted(set(id_condiciones_activas))

    with db_cursor() as cur:
        fecha_nacimiento = _fetch_patient_birthdate(cur, id_paciente)

        edad_meses = control_clinico.get("edad_meses")
        if edad_meses is None:
            edad_meses = _calculate_age_in_months(fecha_nacimiento)

        cur.execute(
            """
            select id
            from clinico.control_paciente
            where id_paciente = %s
            order by fecha_control desc, created_at desc, id desc
            limit 1
            """,
            (id_paciente,),
        )
        row_control = cur.fetchone()

        if row_control:
            id_control = int(row_control[0])
            cur.execute(
                """
                update clinico.control_paciente
                set
                    peso_kg = %s,
                    talla_cm = %s,
                    edad_meses = %s,
                    imc_calculado = %s,
                    id_condicion_nutricional_resultado = %s,
                    diagnostico_oms_texto = %s,
                    nivel_dolor_eva = %s,
                    nivel_inflamacion = %s,
                    nivel_fatiga = %s,
                    minutos_rigidez_matutina = %s,
                    inflamacion_pcr = %s,
                    hay_brote_activo = %s,
                    nota_evolucion = %s
                where id = %s
                """,
                (
                    control_clinico["peso_kg"],
                    control_clinico["talla_cm"],
                    edad_meses,
                    control_clinico.get("imc_calculado"),
                    control_clinico.get("id_condicion_nutricional_resultado"),
                    control_clinico.get("diagnostico_oms_texto"),
                    control_clinico.get("nivel_dolor_eva"),
                    control_clinico.get("nivel_inflamacion"),
                    control_clinico.get("nivel_fatiga"),
                    control_clinico.get("minutos_rigidez_matutina"),
                    control_clinico.get("inflamacion_pcr"),
                    control_clinico.get("hay_brote_activo"),
                    control_clinico.get("nota_evolucion"),
                    id_control,
                ),
            )
        else:
            cur.execute(
                """
                insert into clinico.control_paciente (
                    id_paciente,
                    peso_kg,
                    talla_cm,
                    edad_meses,
                    imc_calculado,
                    id_condicion_nutricional_resultado,
                    diagnostico_oms_texto,
                    nivel_dolor_eva,
                    nivel_inflamacion,
                    nivel_fatiga,
                    minutos_rigidez_matutina,
                    inflamacion_pcr,
                    hay_brote_activo,
                    nota_evolucion
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                returning id
                """,
                (
                    id_paciente,
                    control_clinico["peso_kg"],
                    control_clinico["talla_cm"],
                    edad_meses,
                    control_clinico.get("imc_calculado"),
                    control_clinico.get("id_condicion_nutricional_resultado"),
                    control_clinico.get("diagnostico_oms_texto"),
                    control_clinico.get("nivel_dolor_eva"),
                    control_clinico.get("nivel_inflamacion"),
                    control_clinico.get("nivel_fatiga"),
                    control_clinico.get("minutos_rigidez_matutina"),
                    control_clinico.get("inflamacion_pcr"),
                    control_clinico.get("hay_brote_activo"),
                    control_clinico.get("nota_evolucion"),
                ),
            )
            row_new = cur.fetchone()
            if not row_new:
                raise RuntimeError("No fue posible crear el control clínico del paciente.")
            id_control = int(row_new[0])

        cur.execute("delete from clinico.control_condicion_activa where id_control = %s", (id_control,))
        if id_condiciones_activas:
            query_condiciones = """
                insert into clinico.control_condicion_activa (id_control, id_condicion)
                values (%s, %s)
                on conflict (id_control, id_condicion) do nothing
            """
            for id_condicion in id_condiciones_activas:
                cur.execute(query_condiciones, (id_control, id_condicion))

        return id_control