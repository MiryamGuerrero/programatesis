from typing import Any

from app.core.db import db_cursor


def _rows_to_dicts(cur: Any, rows: list[tuple[Any, ...]]) -> list[dict[str, Any]]:
    columns = [description[0] for description in cur.description]
    return [dict(zip(columns, row, strict=False)) for row in rows]


def fetch_my_profile(user_id: str, email: str | None) -> dict[str, Any] | None:
    query = """
        select
            u.id::text as id,
            u.auth_user_id::text as auth_user_id,
            u.email,
            u.nombre_completo,
            u.cedula,
            u.telefono,
            u.direccion,
            lower(r.codigo::text) as role,
            u.activo,
            u.created_at,
            u.updated_at
        from usuarios.usuario u
        inner join usuarios.rol r on r.id = u.id_rol
        where u.id::text = %s
           or u.auth_user_id::text = %s
        {email_filter}
        order by case when u.auth_user_id::text = %s then 0 else 1 end
        limit 1
    """

    email_filter = ""
    params: list[Any] = [user_id, user_id]
    if email and email.strip():
        email_filter = "or lower(u.email) = lower(%s)"
        params.append(email.strip())

    final_query = query.format(email_filter=email_filter)
    params.append(user_id)

    with db_cursor() as cur:
        cur.execute(final_query, tuple(params))
        rows = cur.fetchall()
        mapped = _rows_to_dicts(cur, rows)
        return mapped[0] if mapped else None


def update_my_profile(
    user_id: str,
    email: str | None,
    nombre_completo: str | None,
    cedula: str | None,
    telefono: str | None,
    direccion: str | None,
    nuevo_email: str | None,
) -> bool:
    def _required_trimmed(value: str | None, field_name: str) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            raise ValueError(f"{field_name} no puede estar vacio")
        return cleaned

    def _optional_trimmed(value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned if cleaned else None

    updates: list[str] = []
    params: list[Any] = []

    if nombre_completo is not None:
        updates.append("nombre_completo = %s")
        params.append(_required_trimmed(nombre_completo, "Nombre completo"))
    if cedula is not None:
        updates.append("cedula = %s")
        params.append(_optional_trimmed(cedula))
    if telefono is not None:
        updates.append("telefono = %s")
        params.append(_optional_trimmed(telefono))
    if direccion is not None:
        updates.append("direccion = %s")
        params.append(_optional_trimmed(direccion))
    if nuevo_email is not None:
        updates.append("email = %s")
        params.append(_required_trimmed(nuevo_email, "Email"))

    if not updates:
        return False

    where_clause = """
        where id::text = %s
           or auth_user_id::text = %s
    """
    params.extend([user_id, user_id])

    if email:
        where_clause += " or lower(email) = lower(%s)"
        params.append(email)

    statement = f"""
        update usuarios.usuario
        set {', '.join(updates)}, updated_at = now()
        {where_clause}
    """

    with db_cursor() as cur:
        cur.execute(statement, params)
        return cur.rowcount > 0
