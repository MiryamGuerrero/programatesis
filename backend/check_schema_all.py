from app.core.db import db_cursor

def full_schema_check():
    tables = [
        ('usuarios', 'usuario'),
        ('usuarios', 'paciente'),
        ('usuarios', 'tutor_paciente'),
        ('clinico', 'diagnostico_paciente'),
        ('clinico', 'control_paciente'),
        ('clinico', 'paciente_condicion_vigente'),
        ('clinico', 'alergia_paciente_subgrupo'),
        ('clinico', 'alergia_paciente_ingrediente'),
    ]
    with db_cursor() as cur:
        for schema, table in tables:
            cur.execute(f"SELECT column_name FROM information_schema.columns WHERE table_schema = '{schema}' AND table_name = '{table}'")
            cols = [r[0] for r in cur.fetchall()]
            print(f"--- {schema}.{table} ---")
            print(cols)

if __name__ == "__main__":
    full_schema_check()
