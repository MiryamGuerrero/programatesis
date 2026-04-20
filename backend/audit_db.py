from app.core.db import db_cursor

def audit_schema():
    schemas = ['nutricion', 'clinico', 'heuristico', 'usuarios']
    with db_cursor() as cur:
        for schema in schemas:
            print(f"\n--- Esquema: {schema} ---")
            cur.execute(f"""
                select table_name, column_name, data_type 
                from information_schema.columns 
                where table_schema = '{schema}'
                order by table_name, ordinal_position
            """)
            for row in cur.fetchall():
                print(row)

if __name__ == "__main__":
    audit_schema()
