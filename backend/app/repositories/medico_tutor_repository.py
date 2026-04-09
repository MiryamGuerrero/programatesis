from datetime import date

from app.core.db import db_cursor


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