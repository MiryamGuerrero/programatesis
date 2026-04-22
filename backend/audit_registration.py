from app.core.db import db_cursor

def audit_registration_system():
    with db_cursor() as cur:
        # 1. Buscar tablas de la OMS
        print("--- TABLAS DE REFERENCIA OMS ---")
        cur.execute("""
            select table_schema, table_name 
            from information_schema.tables 
            where table_name ilike '%oms%' or table_name ilike '%referencia%'
        """)
        for row in cur.fetchall(): print(row)

        # 2. Estructura de la tabla paciente
        print("\n--- ESTRUCTURA TABLA PACIENTE ---")
        cur.execute("""
            select column_name, data_type 
            from information_schema.columns 
            where table_schema = 'usuarios' and table_name = 'paciente'
            order by ordinal_position
        """)
        for row in cur.fetchall(): print(row)

        # 3. Estructura de la tabla de controles (donde se suele guardar el peso/talla)
        print("\n--- ESTRUCTURA TABLA CONTROL PACIENTE ---")
        cur.execute("""
            select column_name, data_type 
            from information_schema.columns 
            where table_schema = 'clinico' and table_name = 'control_paciente'
            order by ordinal_position
        """)
        for row in cur.fetchall(): print(row)

if __name__ == "__main__":
    audit_registration_system()
