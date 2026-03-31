from app.core.db import db_cursor


def get_oms_reference(indicador_codigo: str, id_sexo: int, edad_meses: int) -> tuple[float | None, float | None, float | None] | None:
    sql = """
        select r.l, r.m, r.s
                from dom_referencia_oms.oms_referencia_zscore r
                inner join dom_referencia_oms.indicador_antropometrico i on i.id = r.id_indicador
        where i.codigo = %s
          and r.id_sexo = %s
          and r.meses = %s
        limit 1
    """
    with db_cursor() as cur:
        cur.execute(sql, (indicador_codigo, id_sexo, edad_meses))
        row = cur.fetchone()

    if not row:
        return None
    return row[0], row[1], row[2]


def get_patient_active_condition_ids(id_paciente: str) -> list[int]:
    sql = """
        select id_condicion
                from dom_clinica_diagnosticos.diagnostico_paciente
        where id_paciente = %s
          and activa = true
    """
    with db_cursor() as cur:
        cur.execute(sql, (id_paciente,))
        rows = cur.fetchall()

    return [row[0] for row in rows]
