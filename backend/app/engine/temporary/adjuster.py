from datetime import date
from app.core.db import db_cursor

def get_temporary_adjustments(id_paciente: str, target_date: date) -> list[dict]:
    """
    Fetches active temporary restrictions from the clinico.restriccion_temporal_paciente table.
    """
    sql = """
        select 
            accion_codigo,
            id_ingrediente,
            id_subgrupo_alimentario,
            id_grupo_alimentario,
            id_etiqueta,
            id_receta,
            motivo
        from clinico.restriccion_temporal_paciente
        where id_paciente = %s
          and activa = true
          and %s between fecha_inicio and fecha_fin
    """
    
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente, target_date))
        rows = cur.fetchall()
        
    results = []
    for row in rows:
        results.append({
            "accion_codigo": row[0],
            "id_ingrediente": row[1],
            "id_subgrupo_alimentario": row[2],
            "id_grupo_alimentario": row[3],
            "id_etiqueta": row[4],
            "id_receta": row[5],
            "motivo": row[6],
            # We map target based on what is not null
            "objetivo_codigo": "INGREDIENTE" if row[1] else 
                               "SUBGRUPO" if row[2] else 
                               "GRUPO" if row[3] else 
                               "ETIQUETA" if row[4] else 
                               "RECETA" if row[5] else "DESCONOCIDO"
        })
    return results
