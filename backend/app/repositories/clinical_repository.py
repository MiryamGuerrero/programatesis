from datetime import date
from app.core.db import db_cursor


def get_oms_reference(indicador_codigo: str, id_sexo: int, edad_meses: int) -> tuple[float | None, float | None, float | None] | None:
    sql = """
                select p.l, p.m, p.s
                from referencia.oms_curva pcurve
                inner join referencia.indicador_antropometrico i on i.id = pcurve.id_indicador
                inner join referencia.oms_curva_punto p on p.id_curva = pcurve.id
        where i.codigo = %s
                    and pcurve.id_sexo = %s
                    and pcurve.tipo_curva = 'ZSCORE'
                    and p.edad_valor = %s
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(sql, (indicador_codigo, id_sexo, edad_meses))
        row = cur.fetchone()

    if not row:
        return None
    return row[0], row[1], row[2]


def get_patient_active_condition_ids(id_paciente: str, target_date: date | None = None) -> list[int]:
    if target_date is None:
        target_date = date.today()
        
    sql = """
        -- 1. Condiciones permanentes o diagnósticos
        SELECT id_condicion
        FROM clinico.diagnostico_paciente
        WHERE id_paciente = %s AND activa = true
        
        UNION
        
        -- 2. Condiciones temporales vigentes
        SELECT id_condicion
        FROM clinico.restriccion_temporal_paciente
        WHERE id_paciente = %s AND activa = true 
          AND %s BETWEEN fecha_inicio AND fecha_fin
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente, id_paciente, target_date))
        rows = cur.fetchall()

    return [row[0] for row in rows]
