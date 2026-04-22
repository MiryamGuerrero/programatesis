from app.core.db import db_cursor

def list_etiquetas_catalogo():
    """Lista todas las etiquetas nutricionales disponibles."""
    sql = """
        SELECT id, codigo, nombre_visible
        FROM nutricion.etiqueta_nutricional
        ORDER BY nombre_visible ASC
    """
    with db_cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()
        return [
            {
                "id": r[0],
                "nombre": r[1],  # El frontend suele buscar "nombre" para el código interno
                "nombre_visible": r[2]
            }
            for r in rows
        ]

def update_etiqueta_nombre(id_etiqueta: int, nuevo_nombre: str):
    """Actualiza el nombre visible de una etiqueta."""
    sql = """
        UPDATE nutricion.etiqueta_nutricional
        SET nombre_visible = %s
        WHERE id = %s
    """
    with db_cursor() as cur:
        cur.execute(sql, (nuevo_nombre, id_etiqueta))
        return cur.rowcount > 0

def delete_etiqueta_full(id_etiqueta: int):
    """
    Elimina una etiqueta del catálogo. 
    Al estar vinculada en nutricion.ingrediente_etiqueta y heuristico.regla, 
    primero eliminamos las asociaciones y reglas relacionadas.
    """
    with db_cursor() as cur:
        # 1. Eliminar asociaciones con ingredientes
        cur.execute("DELETE FROM nutricion.ingrediente_etiqueta WHERE id_etiqueta = %s", (id_etiqueta,))
        # 2. Eliminar reglas que dependen de esta etiqueta
        cur.execute("DELETE FROM heuristico.regla WHERE id_etiqueta = %s", (id_etiqueta,))
        # 3. Eliminar del catálogo principal
        cur.execute("DELETE FROM nutricion.etiqueta_nutricional WHERE id = %s", (id_etiqueta,))
        return cur.rowcount > 0
