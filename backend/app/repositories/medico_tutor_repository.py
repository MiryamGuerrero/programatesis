from datetime import date

from app.core.db import db_cursor


def _rows_to_dicts(cur, rows):
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]


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

        return str(row_paciente[0])


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
    id_usuario_tutor: str,
    id_parentesco: int | None,
    es_principal: bool,
) -> str:
    id_paciente = registrar_paciente(
        nombre_completo=nombre_completo,
        fecha_nacimiento=fecha_nacimiento,
        id_sexo=id_sexo,
        id_provincia=id_provincia,
    )
    vincular_tutor_paciente(
        id_usuario_tutor=id_usuario_tutor,
        id_paciente=id_paciente,
        id_parentesco=id_parentesco,
        es_principal=es_principal,
    )
    return str(id_paciente)