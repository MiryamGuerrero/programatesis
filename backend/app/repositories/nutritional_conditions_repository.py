from app.core.db import db_cursor
from app.schemas.domain import NutritionalConditionCreate, NutritionalConditionUpdate, NutritionalConditionResponse

ID_TIPO_NUTRICIONAL = 3

def list_nutritional_conditions() -> list[NutritionalConditionResponse]:
    """Lista solo las condiciones de tipo nutricional."""
    sql = "SELECT id, nombre, descripcion, activa FROM heuristico.condicion WHERE id_tipo_condicion = %s ORDER BY nombre ASC"
    with db_cursor() as cur:
        cur.execute(sql, (ID_TIPO_NUTRICIONAL,))
        rows = cur.fetchall()
        return [
            NutritionalConditionResponse(id=r[0], nombre=r[1], descripcion=r[2], activa=r[3])
            for r in rows
        ]

def create_nutritional_condition(data: NutritionalConditionCreate) -> int:
    """Crea una nueva condición nutricional."""
    sql = "INSERT INTO heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa) VALUES (%s, %s, %s, true) RETURNING id"
    with db_cursor() as cur:
        cur.execute(sql, (data.nombre, data.descripcion, ID_TIPO_NUTRICIONAL))
        return cur.fetchone()[0]

def update_nutritional_condition(id: int, data: NutritionalConditionUpdate) -> bool:
    """Actualiza una condición nutricional."""
    with db_cursor() as cur:
        fields = []
        params = []
        if data.nombre is not None:
            fields.append("nombre = %s")
            params.append(data.nombre)
        if data.descripcion is not None:
            fields.append("descripcion = %s")
            params.append(data.descripcion)
        if data.activa is not None:
            fields.append("activa = %s")
            params.append(data.activa)
            
        if not fields:
            return False
            
        params.append(id)
        params.append(ID_TIPO_NUTRICIONAL)
        sql = f"UPDATE heuristico.condicion SET {', '.join(fields)} WHERE id = %s AND id_tipo_condicion = %s"
        cur.execute(sql, tuple(params))
        return cur.rowcount > 0

def delete_nutritional_condition_safe(id: int) -> bool:
    """
    Elimina físicamente si no tiene historial médico. 
    Si tiene historial, solo la desactiva.
    """
    with db_cursor() as cur:
        # 1. Verificar si está en uso en controles médicos
        cur.execute("SELECT COUNT(*) FROM clinico.control_condicion_activa WHERE id_condicion = %s", (id,))
        en_uso = cur.fetchone()[0] > 0
        
        if en_uso:
            # Solo desactivar
            cur.execute("UPDATE heuristico.condicion SET activa = false WHERE id = %s", (id,))
            return True
        else:
            # Eliminar vínculos con reglas primero
            cur.execute("DELETE FROM heuristico.condicion_regla WHERE id_condicion = %s", (id,))
            # Eliminar físicamente
            cur.execute("DELETE FROM heuristico.condicion WHERE id = %s AND id_tipo_condicion = %s", (id, ID_TIPO_NUTRICIONAL))
            return cur.rowcount > 0
