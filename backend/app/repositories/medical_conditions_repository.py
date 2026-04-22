from app.core.db import db_cursor
from app.schemas.domain import MedicalConditionCreate, MedicalConditionUpdate, MedicalConditionResponse

# Tipos de condición Médica
ID_TIPO_CLINICA = 1
ID_TIPO_TEMPORAL = 2

def list_medical_conditions() -> list[MedicalConditionResponse]:
    """Lista condiciones de tipo clínica y temporal."""
    sql = """
        SELECT c.id, c.nombre, c.descripcion, c.activa, c.id_tipo_condicion, t.nombre as tipo_nombre
        FROM heuristico.condicion c
        JOIN heuristico.catalogo_tipo_condicion t ON t.id = c.id_tipo_condicion
        WHERE c.id_tipo_condicion IN (%s, %s)
        ORDER BY t.nombre ASC, c.nombre ASC
    """
    with db_cursor() as cur:
        cur.execute(sql, (ID_TIPO_CLINICA, ID_TIPO_TEMPORAL))
        rows = cur.fetchall()
        return [
            MedicalConditionResponse(
                id=r[0], nombre=r[1], descripcion=r[2], activa=r[3], 
                id_tipo_condicion=r[4], tipo_nombre=r[5]
            )
            for r in rows
        ]

def create_medical_condition(data: MedicalConditionCreate) -> int:
    """Crea una nueva condición clínica o temporal."""
    sql = "INSERT INTO heuristico.condicion (nombre, descripcion, id_tipo_condicion, activa) VALUES (%s, %s, %s, true) RETURNING id"
    with db_cursor() as cur:
        cur.execute(sql, (data.nombre, data.descripcion, data.id_tipo_condicion))
        return cur.fetchone()[0]

def update_medical_condition(id: int, data: MedicalConditionUpdate) -> bool:
    """Actualiza una condición médica."""
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
        if data.id_tipo_condicion is not None:
            fields.append("id_tipo_condicion = %s")
            params.append(data.id_tipo_condicion)
            
        if not fields:
            return False
            
        params.append(id)
        sql = f"UPDATE heuristico.condicion SET {', '.join(fields)} WHERE id = %s AND id_tipo_condicion IN (1, 2)"
        cur.execute(sql, tuple(params))
        return cur.rowcount > 0

def delete_medical_condition_safe(id: int) -> bool:
    """Eliminación segura para el médico (mismo criterio que nutricionista)."""
    with db_cursor() as cur:
        # Verificar uso
        cur.execute("SELECT COUNT(*) FROM clinico.control_condicion_activa WHERE id_condicion = %s", (id,))
        en_uso = cur.fetchone()[0] > 0
        
        if en_uso:
            cur.execute("UPDATE heuristico.condicion SET activa = false WHERE id = %s", (id,))
            return True
        else:
            cur.execute("DELETE FROM heuristico.condicion_regla WHERE id_condicion = %s", (id,))
            cur.execute("DELETE FROM heuristico.condicion WHERE id = %s AND id_tipo_condicion IN (1, 2)", (id,))
            return cur.rowcount > 0
