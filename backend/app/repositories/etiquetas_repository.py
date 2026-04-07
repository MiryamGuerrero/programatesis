from app.core.db import db_cursor
from app.schemas.domain import (
    EtiquetaDefinicionCreate, EtiquetaDefinicionUpdate, EtiquetaDefinicionResponse,
    EtiquetaCondicionCreate, EtiquetaCondicionUpdate, EtiquetaCondicionResponse,
    EtiquetaConDetalleFull
)


# ============ ETIQUETA DEFINICION (CRUD) ============

def create_etiqueta(etiqueta: EtiquetaDefinicionCreate) -> EtiquetaDefinicionResponse:
    sql = """
        INSERT INTO dom_nutricion_catalogos.etiqueta_definicion (
            nombre, descripcion, id_tipo_nutriente, color_hex, icono, activa
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id, nombre, descripcion, id_tipo_nutriente, color_hex, icono, activa
    """
    with db_cursor() as cur:
        cur.execute(sql, (
            etiqueta.nombre,
            etiqueta.descripcion,
            etiqueta.id_tipo_nutriente,
            etiqueta.color_hex,
            etiqueta.icono,
            etiqueta.activa,
        ))
        row = cur.fetchone()

    return EtiquetaDefinicionResponse(
        id=row[0],
        nombre=row[1],
        descripcion=row[2],
        id_tipo_nutriente=row[3],
        color_hex=row[4],
        icono=row[5],
        activa=row[6],
    )


def get_etiqueta(etiqueta_id: int) -> EtiquetaDefinicionResponse | None:
    sql = """
        SELECT id, nombre, descripcion, id_tipo_nutriente, color_hex, icono, activa
        FROM dom_nutricion_catalogos.etiqueta_definicion
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (etiqueta_id,))
        row = cur.fetchone()

    if not row:
        return None

    return EtiquetaDefinicionResponse(
        id=row[0],
        nombre=row[1],
        descripcion=row[2],
        id_tipo_nutriente=row[3],
        color_hex=row[4],
        icono=row[5],
        activa=row[6],
    )


def get_etiqueta_full(etiqueta_id: int) -> EtiquetaConDetalleFull | None:
    sql = """
        SELECT id, nombre, descripcion, id_tipo_nutriente, color_hex, icono, activa
        FROM dom_nutricion_catalogos.etiqueta_definicion
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (etiqueta_id,))
        row = cur.fetchone()

    if not row:
        return None

    # Obtener condiciones
    condiciones = get_condiciones_por_etiqueta(etiqueta_id)

    return EtiquetaConDetalleFull(
        id=row[0],
        nombre=row[1],
        descripcion=row[2],
        id_tipo_nutriente=row[3],
        color_hex=row[4],
        icono=row[5],
        activa=row[6],
        condiciones=condiciones,
    )


def list_etiquetas(skip: int = 0, limit: int = 100, activas_solo: bool = True) -> tuple[list[EtiquetaDefinicionResponse], int]:
    where_clause = "WHERE activa = true" if activas_solo else ""
    sql_count = f"""
        SELECT COUNT(*) FROM dom_nutricion_catalogos.etiqueta_definicion {where_clause}
    """
    sql = f"""
        SELECT id, nombre, descripcion, id_tipo_nutriente, color_hex, icono, activa
        FROM dom_nutricion_catalogos.etiqueta_definicion
        {where_clause}
        ORDER BY nombre
        OFFSET %s LIMIT %s
    """
    
    with db_cursor() as cur:
        cur.execute(sql_count)
        total = cur.fetchone()[0]
        
        cur.execute(sql, (skip, limit))
        rows = cur.fetchall()

    items = [
        EtiquetaDefinicionResponse(
            id=row[0],
            nombre=row[1],
            descripcion=row[2],
            id_tipo_nutriente=row[3],
            color_hex=row[4],
            icono=row[5],
            activa=row[6],
        )
        for row in rows
    ]
    
    return items, total


def update_etiqueta(etiqueta_id: int, update_data: EtiquetaDefinicionUpdate) -> EtiquetaDefinicionResponse | None:
    etiqueta_actual = get_etiqueta(etiqueta_id)
    if not etiqueta_actual:
        return None

    campos = []
    valores = []
    
    if update_data.nombre is not None:
        campos.append("nombre = %s")
        valores.append(update_data.nombre)
    if update_data.descripcion is not None:
        campos.append("descripcion = %s")
        valores.append(update_data.descripcion)
    if update_data.id_tipo_nutriente is not None:
        campos.append("id_tipo_nutriente = %s")
        valores.append(update_data.id_tipo_nutriente)
    if update_data.color_hex is not None:
        campos.append("color_hex = %s")
        valores.append(update_data.color_hex)
    if update_data.icono is not None:
        campos.append("icono = %s")
        valores.append(update_data.icono)
    if update_data.activa is not None:
        campos.append("activa = %s")
        valores.append(update_data.activa)

    if not campos:
        return etiqueta_actual

    valores.append(etiqueta_id)
    
    sql = f"""
        UPDATE dom_nutricion_catalogos.etiqueta_definicion
        SET {', '.join(campos)}
        WHERE id = %s
        RETURNING id, nombre, descripcion, id_tipo_nutriente, color_hex, icono, activa
    """

    with db_cursor() as cur:
        cur.execute(sql, valores)
        row = cur.fetchone()

    if not row:
        return None

    return EtiquetaDefinicionResponse(
        id=row[0],
        nombre=row[1],
        descripcion=row[2],
        id_tipo_nutriente=row[3],
        color_hex=row[4],
        icono=row[5],
        activa=row[6],
    )


def delete_etiqueta(etiqueta_id: int) -> bool:
    sql = """
        UPDATE dom_nutricion_catalogos.etiqueta_definicion
        SET activa = false
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (etiqueta_id,))
        return cur.rowcount > 0


# ============ ETIQUETA CONDICION (CRUD) ============

def create_condicion(condicion: EtiquetaCondicionCreate) -> EtiquetaCondicionResponse:
    sql = """
        INSERT INTO dom_nutricion_catalogos.etiqueta_condicion (
            id_etiqueta, orden, operador, valor_umbral, texto_resultado
        )
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id, id_etiqueta, orden, operador, valor_umbral, texto_resultado
    """
    with db_cursor() as cur:
        cur.execute(sql, (
            condicion.id_etiqueta,
            condicion.orden,
            condicion.operador,
            condicion.valor_umbral,
            condicion.texto_resultado,
        ))
        row = cur.fetchone()

    return EtiquetaCondicionResponse(
        id=row[0],
        id_etiqueta=row[1],
        orden=row[2],
        operador=row[3],
        valor_umbral=row[4],
        texto_resultado=row[5],
    )


def get_condicion(condicion_id: int) -> EtiquetaCondicionResponse | None:
    sql = """
        SELECT id, id_etiqueta, orden, operador, valor_umbral, texto_resultado
        FROM dom_nutricion_catalogos.etiqueta_condicion
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (condicion_id,))
        row = cur.fetchone()

    if not row:
        return None

    return EtiquetaCondicionResponse(
        id=row[0],
        id_etiqueta=row[1],
        orden=row[2],
        operador=row[3],
        valor_umbral=row[4],
        texto_resultado=row[5],
    )


def get_condiciones_por_etiqueta(etiqueta_id: int) -> list[EtiquetaCondicionResponse]:
    sql = """
        SELECT id, id_etiqueta, orden, operador, valor_umbral, texto_resultado
        FROM dom_nutricion_catalogos.etiqueta_condicion
        WHERE id_etiqueta = %s
        ORDER BY orden
    """
    with db_cursor() as cur:
        cur.execute(sql, (etiqueta_id,))
        rows = cur.fetchall()

    return [
        EtiquetaCondicionResponse(
            id=row[0],
            id_etiqueta=row[1],
            orden=row[2],
            operador=row[3],
            valor_umbral=row[4],
            texto_resultado=row[5],
        )
        for row in rows
    ]


def update_condicion(condicion_id: int, update_data: EtiquetaCondicionUpdate) -> EtiquetaCondicionResponse | None:
    condicion_actual = get_condicion(condicion_id)
    if not condicion_actual:
        return None

    campos = []
    valores = []
    
    if update_data.operador is not None:
        campos.append("operador = %s")
        valores.append(update_data.operador)
    if update_data.valor_umbral is not None:
        campos.append("valor_umbral = %s")
        valores.append(update_data.valor_umbral)
    if update_data.texto_resultado is not None:
        campos.append("texto_resultado = %s")
        valores.append(update_data.texto_resultado)
    if update_data.orden is not None:
        campos.append("orden = %s")
        valores.append(update_data.orden)

    if not campos:
        return condicion_actual

    valores.append(condicion_id)
    
    sql = f"""
        UPDATE dom_nutricion_catalogos.etiqueta_condicion
        SET {', '.join(campos)}
        WHERE id = %s
        RETURNING id, id_etiqueta, orden, operador, valor_umbral, texto_resultado
    """

    with db_cursor() as cur:
        cur.execute(sql, valores)
        row = cur.fetchone()

    if not row:
        return None

    return EtiquetaCondicionResponse(
        id=row[0],
        id_etiqueta=row[1],
        orden=row[2],
        operador=row[3],
        valor_umbral=row[4],
        texto_resultado=row[5],
    )


def delete_condicion(condicion_id: int) -> bool:
    sql = """
        DELETE FROM dom_nutricion_catalogos.etiqueta_condicion
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (condicion_id,))
        return cur.rowcount > 0
