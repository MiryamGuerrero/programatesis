from app.core.db import db_cursor
from app.schemas.domain import (
    IngredienteCreate, IngredienteUpdate, IngredienteResponse
)


def create_ingrediente(ingrediente: IngredienteCreate) -> IngredienteResponse:
    sql = """
        INSERT INTO dom_nutricion_ingredientes.ingrediente (
            nombre, id_grupo_alimentario, energia_kcal, proteinas_g,
            carbohidratos_g, lipidos_g, fibra_g, calcio_mg, hierro_mg,
            potasio_mg, descripcion, activo
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id, nombre, id_grupo_alimentario, energia_kcal, proteinas_g,
                  carbohidratos_g, lipidos_g, fibra_g, calcio_mg, hierro_mg,
                  potasio_mg, descripcion, activo
    """
    with db_cursor() as cur:
        cur.execute(sql, (
            ingrediente.nombre,
            ingrediente.id_grupo_alimentario,
            ingrediente.energia_kcal,
            ingrediente.proteinas_g,
            ingrediente.carbohidratos_g,
            ingrediente.lipidos_g,
            ingrediente.fibra_g,
            ingrediente.calcio_mg,
            ingrediente.hierro_mg,
            ingrediente.potasio_mg,
            ingrediente.descripcion,
            ingrediente.activo,
        ))
        row = cur.fetchone()

    return IngredienteResponse(
        id=row[0],
        nombre=row[1],
        id_grupo_alimentario=row[2],
        energia_kcal=row[3],
        proteinas_g=row[4],
        carbohidratos_g=row[5],
        lipidos_g=row[6],
        fibra_g=row[7],
        calcio_mg=row[8],
        hierro_mg=row[9],
        potasio_mg=row[10],
        descripcion=row[11],
        activo=row[12],
    )


def get_ingrediente(ingrediente_id: int) -> IngredienteResponse | None:
    sql = """
        SELECT id, nombre, id_grupo_alimentario, energia_kcal, proteinas_g,
               carbohidratos_g, lipidos_g, fibra_g, calcio_mg, hierro_mg,
               potasio_mg, descripcion, activo
        FROM dom_nutricion_ingredientes.ingrediente
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id,))
        row = cur.fetchone()

    if not row:
        return None

    return IngredienteResponse(
        id=row[0],
        nombre=row[1],
        id_grupo_alimentario=row[2],
        energia_kcal=row[3],
        proteinas_g=row[4],
        carbohidratos_g=row[5],
        lipidos_g=row[6],
        fibra_g=row[7],
        calcio_mg=row[8],
        hierro_mg=row[9],
        potasio_mg=row[10],
        descripcion=row[11],
        activo=row[12],
    )


def list_ingredientes(skip: int = 0, limit: int = 100, activos_solo: bool = True) -> tuple[list[IngredienteResponse], int]:
    where_clause = "WHERE activo = true" if activos_solo else ""
    sql_count = f"""
        SELECT COUNT(*) FROM dom_nutricion_ingredientes.ingrediente {where_clause}
    """
    sql = f"""
        SELECT id, nombre, id_grupo_alimentario, energia_kcal, proteinas_g,
               carbohidratos_g, lipidos_g, fibra_g, calcio_mg, hierro_mg,
               potasio_mg, descripcion, activo
        FROM dom_nutricion_ingredientes.ingrediente
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
        IngredienteResponse(
            id=row[0],
            nombre=row[1],
            id_grupo_alimentario=row[2],
            energia_kcal=row[3],
            proteinas_g=row[4],
            carbohidratos_g=row[5],
            lipidos_g=row[6],
            fibra_g=row[7],
            calcio_mg=row[8],
            hierro_mg=row[9],
            potasio_mg=row[10],
            descripcion=row[11],
            activo=row[12],
        )
        for row in rows
    ]
    
    return items, total


def update_ingrediente(ingrediente_id: int, update_data: IngredienteUpdate) -> IngredienteResponse | None:
    # Obtener ingrediente actual
    ingrediente_actual = get_ingrediente(ingrediente_id)
    if not ingrediente_actual:
        return None

    # Preparar datos a actualizar
    campos = []
    valores = []
    
    if update_data.nombre is not None:
        campos.append("nombre = %s")
        valores.append(update_data.nombre)
    if update_data.id_grupo_alimentario is not None:
        campos.append("id_grupo_alimentario = %s")
        valores.append(update_data.id_grupo_alimentario)
    if update_data.energia_kcal is not None:
        campos.append("energia_kcal = %s")
        valores.append(update_data.energia_kcal)
    if update_data.proteinas_g is not None:
        campos.append("proteinas_g = %s")
        valores.append(update_data.proteinas_g)
    if update_data.carbohidratos_g is not None:
        campos.append("carbohidratos_g = %s")
        valores.append(update_data.carbohidratos_g)
    if update_data.lipidos_g is not None:
        campos.append("lipidos_g = %s")
        valores.append(update_data.lipidos_g)
    if update_data.fibra_g is not None:
        campos.append("fibra_g = %s")
        valores.append(update_data.fibra_g)
    if update_data.calcio_mg is not None:
        campos.append("calcio_mg = %s")
        valores.append(update_data.calcio_mg)
    if update_data.hierro_mg is not None:
        campos.append("hierro_mg = %s")
        valores.append(update_data.hierro_mg)
    if update_data.potasio_mg is not None:
        campos.append("potasio_mg = %s")
        valores.append(update_data.potasio_mg)
    if update_data.descripcion is not None:
        campos.append("descripcion = %s")
        valores.append(update_data.descripcion)
    if update_data.activo is not None:
        campos.append("activo = %s")
        valores.append(update_data.activo)

    if not campos:
        return ingrediente_actual

    valores.append(ingrediente_id)
    
    sql = f"""
        UPDATE dom_nutricion_ingredientes.ingrediente
        SET {', '.join(campos)}
        WHERE id = %s
        RETURNING id, nombre, id_grupo_alimentario, energia_kcal, proteinas_g,
                  carbohidratos_g, lipidos_g, fibra_g, calcio_mg, hierro_mg,
                  potasio_mg, descripcion, activo
    """

    with db_cursor() as cur:
        cur.execute(sql, valores)
        row = cur.fetchone()

    if not row:
        return None

    return IngredienteResponse(
        id=row[0],
        nombre=row[1],
        id_grupo_alimentario=row[2],
        energia_kcal=row[3],
        proteinas_g=row[4],
        carbohidratos_g=row[5],
        lipidos_g=row[6],
        fibra_g=row[7],
        calcio_mg=row[8],
        hierro_mg=row[9],
        potasio_mg=row[10],
        descripcion=row[11],
        activo=row[12],
    )


def delete_ingrediente(ingrediente_id: int) -> bool:
    # Usar soft delete (inactivar)
    sql = """
        UPDATE dom_nutricion_ingredientes.ingrediente
        SET activo = false
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (ingrediente_id,))
        return cur.rowcount > 0


def buscar_ingredientes(termino: str, limit: int = 50) -> list[IngredienteResponse]:
    sql = """
        SELECT id, nombre, id_grupo_alimentario, energia_kcal, proteinas_g,
               carbohidratos_g, lipidos_g, fibra_g, calcio_mg, hierro_mg,
               potasio_mg, descripcion, activo
        FROM dom_nutricion_ingredientes.ingrediente
        WHERE activo = true AND nombre ILIKE %s
        ORDER BY nombre
        LIMIT %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (f"%{termino}%", limit))
        rows = cur.fetchall()

    return [
        IngredienteResponse(
            id=row[0],
            nombre=row[1],
            id_grupo_alimentario=row[2],
            energia_kcal=row[3],
            proteinas_g=row[4],
            carbohidratos_g=row[5],
            lipidos_g=row[6],
            fibra_g=row[7],
            calcio_mg=row[8],
            hierro_mg=row[9],
            potasio_mg=row[10],
            descripcion=row[11],
            activo=row[12],
        )
        for row in rows
    ]
